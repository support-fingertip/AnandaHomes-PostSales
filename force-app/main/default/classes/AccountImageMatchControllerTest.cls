/**
 * @description Test class for AccountImageMatchController
 */
@isTest
private class AccountImageMatchControllerTest {

    @testSetup
    static void setup() {
        postSalesTestDataFactory.createAccount('Image Match Test Account');
    }

    @isTest
    static void saveMasterImage_happyPath() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        String base64 = EncodingUtil.base64Encode(Blob.valueOf('fake-image-bytes'));

        Test.startTest();
        String contentDocId = AccountImageMatchController.saveMasterImage(
            acc.Id, base64, '[0.1,0.2,0.3]'
        );
        Test.stopTest();

        System.assertNotEquals(null, contentDocId, 'Should return ContentDocumentId');
    }

    @isTest
    static void saveMasterImage_missingParams_throws() {
        Boolean threw = false;
        try {
            AccountImageMatchController.saveMasterImage(null, null, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Should throw on missing params');
    }

    @isTest
    static void getMasterImage_returnsData() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        String base64 = EncodingUtil.base64Encode(Blob.valueOf('img'));
        AccountImageMatchController.saveMasterImage(acc.Id, base64, '[1,2,3]');

        Test.startTest();
        AccountImageMatchController.MasterData data =
            AccountImageMatchController.getMasterImage(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, data, 'Should return MasterData');
        System.assertEquals('[1,2,3]', data.featureVector, 'Vector should round-trip');
    }
}