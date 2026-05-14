/**
 * @description Test class for IntegrationResult
 */
@isTest
private class IntegrationResultTest {

    @isTest
    static void defaultConstructor_initialisesSafeDefaults() {
        IntegrationResult r = new IntegrationResult();
        System.assertEquals(false, r.success);
        System.assertEquals(0, r.statusCode);
        System.assertEquals('', r.responseBody);
        System.assertEquals(0L, r.executionTimeMs);
        System.assertEquals(0, r.retryCount);
        System.assertNotEquals(null, r.mappedValues);
        System.assertNotEquals(null, r.responseHeaders);
        System.assertNotEquals(null, r.correlationId);
    }

    @isTest
    static void successFactory_setsFlagsAndBody() {
        IntegrationResult r = IntegrationResult.success(201, '{"ok":true}');
        System.assertEquals(true, r.success);
        System.assertEquals(201, r.statusCode);
        System.assertEquals('{"ok":true}', r.responseBody);
    }

    @isTest
    static void failureFactory_messageOnly() {
        IntegrationResult r = IntegrationResult.failure('boom');
        System.assertEquals(false, r.success);
        System.assertEquals('boom', r.errorMessage);
    }

    @isTest
    static void failureFactory_statusBodyMessage() {
        IntegrationResult r = IntegrationResult.failure(500, 'body', 'boom');
        System.assertEquals(false, r.success);
        System.assertEquals(500, r.statusCode);
        System.assertEquals('body', r.responseBody);
        System.assertEquals('boom', r.errorMessage);
    }

    @isTest
    static void mutableFields_settable() {
        IntegrationResult r = new IntegrationResult();
        r.executionTimeMs = 250L;
        r.retryCount = 2;
        r.mappedValues.put('k', 'v');
        r.responseHeaders.put('h', '1');
        System.assertEquals(250L, r.executionTimeMs);
        System.assertEquals(2, r.retryCount);
        System.assertEquals('v', r.mappedValues.get('k'));
        System.assertEquals('1', r.responseHeaders.get('h'));
    }
}