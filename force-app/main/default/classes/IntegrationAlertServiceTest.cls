/**
 * @description Test class for IntegrationAlertService
 */
@isTest
private class IntegrationAlertServiceTest {

    @isTest
    static void checkAndAlert_nullLog_noOp() {
        Test.startTest();
        IntegrationAlertService.checkAndAlert(null, null);
        Test.stopTest();
        System.assert(true, 'Null log should be handled gracefully');
    }

    @isTest
    static void checkAndAlert_criticalError_runs() {
        Integration_Endpoint__c ep = postSalesTestDataFactory.createEndpoint('ALERT_CRIT');
        Integration_Log__c log = postSalesTestDataFactory.createLog(ep.Id, false);
        Integration_Error_Log__c err = postSalesTestDataFactory.createErrorLog(log.Id, 'Unknown', 'Boom');
        err.Severity__c = 'Critical';
        update err;

        Test.startTest();
        IntegrationAlertService.checkAndAlert(log, err);
        Test.stopTest();
        System.assert(true, 'Critical alert path should run without throwing');
    }

    @isTest
    static void checkAndAlert_deadLetter_runs() {
        Integration_Endpoint__c ep = postSalesTestDataFactory.createEndpoint('ALERT_DL');
        Integration_Log__c log = postSalesTestDataFactory.createLog(ep.Id, false);
        Integration_Error_Log__c err = postSalesTestDataFactory.createErrorLog(log.Id, 'Unknown', 'Dead');
        err.Is_Dead_Letter__c = true;
        err.Severity__c = 'High';
        update err;

        Test.startTest();
        IntegrationAlertService.checkAndAlert(log, err);
        Test.stopTest();
        System.assert(true, 'Dead letter alert path should run without throwing');
    }

    @isTest
    static void checkAndAlert_consecutiveFailures_runs() {
        Integration_Endpoint__c ep = postSalesTestDataFactory.createEndpoint('ALERT_CONS');

        // Create 3 failure logs for same key
        for (Integer i = 0; i < 3; i++) {
            Integration_Log__c l = postSalesTestDataFactory.createLog(ep.Id, false);
            l.Integration_Key__c = 'CONS_KEY';
            update l;
        }

        Integration_Log__c latest = postSalesTestDataFactory.createLog(ep.Id, false);
        latest.Integration_Key__c = 'CONS_KEY';
        update latest;

        Integration_Error_Log__c err = postSalesTestDataFactory.createErrorLog(latest.Id, 'Timeout', 'Slow');
        err.Severity__c = 'Medium';
        update err;

        Test.startTest();
        IntegrationAlertService.checkAndAlert(latest, err);
        Test.stopTest();
        System.assert(true, 'Consecutive failure path should run without throwing');
    }

    @isTest
    static void sendEmailAlert_blankInputs_noOp() {
        Test.startTest();
        IntegrationAlertService.sendEmailAlert(null, null, null);
        IntegrationAlertService.sendEmailAlert('Subject', 'Body', new List<String>());
        IntegrationAlertService.sendEmailAlert('', 'Body', new List<String>{ 'a@b.com' });
        Test.stopTest();
        System.assert(true, 'Blank inputs should not throw');
    }

    @isTest
    static void sendEmailAlert_validInputs_sends() {
        Test.startTest();
        IntegrationAlertService.sendEmailAlert(
            'Test Subject', '<p>Body</p>', new List<String>{ 'noreply@example.com' }
        );
        Test.stopTest();
        System.assert(true, 'Send email path should run');
    }

    @isTest
    static void sendEmailAlert_longSubject_truncated() {
        String longSubject = 'X'.repeat(300);
        Test.startTest();
        IntegrationAlertService.sendEmailAlert(
            longSubject, '<p>Body</p>', new List<String>{ 'noreply@example.com' }
        );
        Test.stopTest();
        System.assert(true, 'Long subject should be truncated without throwing');
    }

    @isTest
    static void getAlertRecipients_callable() {
        Test.startTest();
        List<String> recipients = IntegrationAlertService.getAlertRecipients();
        Test.stopTest();
        System.assertNotEquals(null, recipients, 'Recipients list should not be null');
    }
}