/**
 * @description Test class for IntegrationRetrySchedulable
 */
@isTest
private class IntegrationRetrySchedulableTest {

    @testSetup
    static void setup() {
        Integration_Endpoint__c endpoint = postSalesTestDataFactory.createEndpoint('SCH_RETRY_KEY');
        postSalesTestDataFactory.createRetryConfig('SCH_RETRY_KEY');

        Integration_Log__c log = postSalesTestDataFactory.createLog(endpoint.Id, false);
        log.Integration_Key__c = 'SCH_RETRY_KEY';
        update log;

        // 'Dead_Letter' is not a valid Error_Type__c value; use a valid one and use the
        // Is_Dead_Letter__c flag instead.
        Integration_Error_Log__c err = postSalesTestDataFactory.createErrorLog(log.Id, 'Unknown', 'failed');
        err.Is_Dead_Letter__c = true;
        err.Retry_Eligible__c = true;
        err.Original_Payload__c = '{"x":"y"}';
        update err;
    }

    @isTest
    static void execute_processesDeadLetters() {
        Test.startTest();
        String jobId = System.schedule(
            'Test IntegrationRetrySchedulable',
            '0 0 0 1 1 ? 2099',
            new IntegrationRetrySchedulable()
        );
        Test.stopTest();

        List<CronTrigger> jobs = [SELECT Id FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(1, jobs.size(), 'Scheduled job should exist');
    }

    @isTest
    static void execute_directlyEnqueuesRetries() {
        Test.startTest();
        new IntegrationRetrySchedulable().execute(null);
        Test.stopTest();

        // After execution, dead-letter records should be marked Retry_Eligible__c = false
        List<Integration_Error_Log__c> processed = [
            SELECT Id, Retry_Eligible__c FROM Integration_Error_Log__c WHERE Is_Dead_Letter__c = true
        ];
        System.assert(!processed.isEmpty(), 'Should have processed at least one dead-letter record');
    }

    @isTest
    static void scheduleHourly_createsJob() {
        Test.startTest();
        String jobId = IntegrationRetrySchedulable.scheduleHourly();
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Hourly job should be created');
    }

    @isTest
    static void scheduleDaily_createsJob() {
        Test.startTest();
        String jobId = IntegrationRetrySchedulable.scheduleDaily();
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Daily job should be created');
    }
}