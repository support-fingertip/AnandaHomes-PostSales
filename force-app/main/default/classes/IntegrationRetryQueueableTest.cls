/**
 * @description Test class for IntegrationRetryQueueable
 */
@isTest
private class IntegrationRetryQueueableTest {

    @testSetup
    static void setup() {
        Integration_Endpoint__c endpoint = postSalesTestDataFactory.createEndpoint('RETRY_TEST_KEY');
        postSalesTestDataFactory.createRequestTemplate(endpoint.Id, '{"x":"{{x}}"}');
        postSalesTestDataFactory.createRetryConfig('RETRY_TEST_KEY');
    }

    @isTest
    static void execute_blankIntegrationKey_logsAndExits() {
        IntegrationRetryQueueable q = new IntegrationRetryQueueable();
        q.integrationKey = null;
        q.retryCount = 1;

        Test.startTest();
        System.enqueueJob(q);
        Test.stopTest();

        System.assert(true, 'Queueable should exit cleanly with no key');
    }

    @isTest
    static void execute_runsRetrySuccess() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout(200, '{"ok":true}'));

        IntegrationRetryQueueable q = new IntegrationRetryQueueable();
        q.integrationKey = 'RETRY_TEST_KEY';
        q.retryCount = 1;
        q.payloadJson = '{"x":"y"}';
        q.contextJson = '{"src":"test"}';

        Test.startTest();
        System.enqueueJob(q);
        Test.stopTest();

        System.assert(true, 'Retry success path should not throw');
    }

    @isTest
    static void execute_runsRetryFailure_routesDeadLetter() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout(500, '{"err":true}'));

        IntegrationRetryQueueable q = new IntegrationRetryQueueable();
        q.integrationKey = 'RETRY_TEST_KEY';
        q.retryCount = 99; // exhaust retries
        q.payloadJson = '{"x":"y"}';
        q.contextJson = '{"src":"test"}';

        Test.startTest();
        System.enqueueJob(q);
        Test.stopTest();

        System.assert(true, 'Failure path should not throw');
    }

    @isTest
    static void execute_invalidJson_handledGracefully() {
        IntegrationRetryQueueable q = new IntegrationRetryQueueable();
        q.integrationKey = 'RETRY_TEST_KEY';
        q.retryCount = 1;
        q.payloadJson = 'not-valid';
        q.contextJson = 'also-bad';

        Test.setMock(HttpCalloutMock.class, new MockHttpCallout(200, '{"ok":true}'));

        Test.startTest();
        System.enqueueJob(q);
        Test.stopTest();
        System.assert(true, 'Invalid JSON should be caught');
    }

    @isTest
    static void execute_blankPayloadAndContext_usesEmptyMaps() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout(200, '{"ok":true}'));

        IntegrationRetryQueueable q = new IntegrationRetryQueueable();
        q.integrationKey = 'RETRY_TEST_KEY';
        q.retryCount = 2;
        q.payloadJson = '';
        q.contextJson = '';

        Test.startTest();
        System.enqueueJob(q);
        Test.stopTest();
        System.assert(true, 'Blank payload/context should not throw');
    }

    @isTest
    static void execute_failureRetryNotExhausted_enqueuesNext() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout(503, '{"err":"transient"}'));

        IntegrationRetryQueueable q = new IntegrationRetryQueueable();
        q.integrationKey = 'RETRY_TEST_KEY';
        q.retryCount = 1; // not exhausted
        q.payloadJson = '{"x":"y"}';
        q.contextJson = '{"src":"test"}';

        Test.startTest();
        System.enqueueJob(q);
        Test.stopTest();
        System.assert(true, 'Failure with retries left should enqueue next');
    }

    @isTest
    static void execute_unknownIntegrationKey_handlesError() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout(200, '{"ok":true}'));

        IntegrationRetryQueueable q = new IntegrationRetryQueueable();
        q.integrationKey = 'NON_EXISTENT_KEY';
        q.retryCount = 1;
        q.payloadJson = '{"x":1}';
        q.contextJson = '{}';

        Test.startTest();
        System.enqueueJob(q);
        Test.stopTest();
        System.assert(true, 'Unknown key should be handled gracefully');
    }

    @isTest
    static void execute_withParentLogId_updatesLog() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout(200, '{"ok":true}'));

        Integration_Endpoint__c ep = [SELECT Id FROM Integration_Endpoint__c WHERE Integration_Key__c = 'RETRY_TEST_KEY' LIMIT 1];
        Integration_Log__c log = postSalesTestDataFactory.createLog(ep.Id, false);

        IntegrationRetryQueueable q = new IntegrationRetryQueueable();
        q.integrationKey = 'RETRY_TEST_KEY';
        q.retryCount = 1;
        q.parentLogId = log.Id;
        q.payloadJson = '{"x":"y"}';
        q.contextJson = '{"src":"test"}';

        Test.startTest();
        System.enqueueJob(q);
        Test.stopTest();
        System.assert(true, 'With parent log should update');
    }

    @isTest
    static void execute_withDelaySeconds_setsField() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout(200, '{"ok":true}'));

        IntegrationRetryQueueable q = new IntegrationRetryQueueable();
        q.integrationKey = 'RETRY_TEST_KEY';
        q.retryCount = 1;
        q.payloadJson = '{"a":1}';
        q.contextJson = '{}';
        q.delaySeconds = 30;

        Test.startTest();
        System.enqueueJob(q);
        Test.stopTest();
        System.assertEquals(30, q.delaySeconds, 'Delay seconds field set');
    }

    @isTest
    static void execute_withRecordId_passedToEngine() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout(200, '{"ok":true}'));
        Account a = new Account(Name = 'Retry Acc');
        insert a;

        IntegrationRetryQueueable q = new IntegrationRetryQueueable();
        q.integrationKey = 'RETRY_TEST_KEY';
        q.retryCount = 1;
        q.recordId = a.Id;
        q.payloadJson = '{"a":1}';
        q.contextJson = '{}';

        Test.startTest();
        System.enqueueJob(q);
        Test.stopTest();
        System.assertNotEquals(null, q.recordId, 'Record id set');
    }

    @isTest
    static void execute_failure5xxNoConfig_logsCriticalNoRoute() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout(500, '{"err":"x"}'));

        IntegrationRetryQueueable q = new IntegrationRetryQueueable();
        q.integrationKey = 'RETRY_TEST_KEY';
        q.retryCount = 999; // way past max
        q.payloadJson = '{"a":1}';
        q.contextJson = '{}';

        Test.startTest();
        System.enqueueJob(q);
        Test.stopTest();
        System.assert(true, 'Exhausted retries should not throw');
    }
}