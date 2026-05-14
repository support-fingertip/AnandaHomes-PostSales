public with sharing class AccountImageMatchController {

    @AuraEnabled
    public static String saveMasterImage(Id accountId, String imageBase64, String featureVector) {
        if (accountId == null || String.isBlank(imageBase64) || String.isBlank(featureVector)) {
            throw new AuraHandledException('Missing required parameters.');
        }

        // Insert the image as a ContentVersion (Salesforce File)
        ContentVersion cv = new ContentVersion(
            Title = 'Master Image - ' + accountId,
            PathOnClient = 'master_' + accountId + '.jpg',
            VersionData = EncodingUtil.base64Decode(imageBase64),
            Origin = 'H'
        );
        insert cv;

        ContentVersion inserted = [
            SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1
        ];
        Id contentDocId = inserted.ContentDocumentId;

        // Delete old master image(s) linked to this account
        List<ContentDocumentLink> oldLinks = [
            SELECT Id, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :accountId
            AND ContentDocument.Title LIKE 'Master Image%'
        ];
        if (!oldLinks.isEmpty()) {
            Set<Id> oldDocIds = new Set<Id>();
            for (ContentDocumentLink l : oldLinks) oldDocIds.add(l.ContentDocumentId);
            delete [SELECT Id FROM ContentDocument WHERE Id IN :oldDocIds];
        }

        // Link the new file to the Account
        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId = accountId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert link;

        // Save vector + doc id on Account
        update new Account(
            Id = accountId,
            Master_Image_Vector__c = featureVector,
            Master_Image_Id__c = contentDocId
        );

        return contentDocId;
    }

    @AuraEnabled(cacheable=false)
    public static MasterData getMasterImage(Id accountId) {
        Account acc = [
            SELECT Master_Image_Vector__c, Master_Image_Id__c
            FROM Account WHERE Id = :accountId LIMIT 1
        ];
        MasterData data = new MasterData();
        data.featureVector = acc.Master_Image_Vector__c;
        if (String.isNotBlank(acc.Master_Image_Id__c)) {
            List<ContentVersion> cvs = [
                SELECT Id FROM ContentVersion
                WHERE ContentDocumentId = :acc.Master_Image_Id__c
                AND IsLatest = true LIMIT 1
            ];
            if (!cvs.isEmpty()) {
                data.imageUrl = '/sfc/servlet.shepherd/version/download/' + cvs[0].Id;
            }
        }
        return data;
    }

    public class MasterData {
        @AuraEnabled public String imageUrl;
        @AuraEnabled public String featureVector;
    }
}