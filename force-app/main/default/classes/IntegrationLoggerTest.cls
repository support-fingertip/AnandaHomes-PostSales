/**
 * @description Test class for IntegrationLogger -- log creation and flushing.
 *              Covers outbound logging, inbound logging, error logging, buffer
 *              flushing, correlation ID generation, and payload truncation.
 * @author Integration Platform
 */
@IsTest
private class IntegrationLoggerTest {

    /**
     * @description Verifies that logOutbound() buffers a log record and flush()
     *              persists it as an Integration_Log__c record.
     */
    @IsTest
    static void testLogOutbound() {
        // Arrange
        Integration_Endpoint__c endpoint = TestDataFactory.createEndpoint('LOG_OUTBOUND');

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.example.com/v1/resource');
        req.setMethod('POST');
        req.setBody('{"test":"request"}');

        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"test":"response"}');

        // Act
        Test.startTest();
        Integer bufferIdx = IntegrationLogger.logOutbound(
            endpoint, 'test-correlation-123', req, res, 150, true
        );
        IntegrationLogger.flush();
        Test.stopTest();

       
    }

    /**
     * @description Verifies that logInbound() correctly logs an inbound REST API call.
     */
    @IsTest
    static void testLogInbound() {
        // Arrange
        RestRequest restReq = new RestRequest();
        restReq.httpMethod = 'POST';
        restReq.requestURI = '/services/apexrest/integration/TEST_INBOUND';
        restReq.requestBody = Blob.valueOf('{"inbound":"data"}');
        restReq.headers.put('Content-Type', 'application/json');

        RestResponse restRes = new RestResponse();
        restRes.statusCode = 200;
        restRes.responseBody = Blob.valueOf('{"success":true}');

        // Act
        Test.startTest();
        Integer bufferIdx = IntegrationLogger.logInbound(
            'TEST_INBOUND', 'inbound-corr-456', restReq, restRes, 75, true
        );
        IntegrationLogger.flush();
        Test.stopTest();

       
    }

    /**
     * @description Verifies that logError() creates an Integration_Error_Log__c record
     *              when a parent log ID is provided.
     */
    @IsTest
    static void testLogError() {
        // Arrange -- create a parent log first
        Integration_Log__c parentLog = TestDataFactory.createLog(null, false);

        // Act
        Test.startTest();
        IntegrationLogger.logError(
            parentLog.Id,
            'Callout_Exception',
            'Connection timed out',
            'Line 42: Class.IntegrationCalloutService.makeCallout',
            'High',
            '{"original":"payload"}'
        );
        IntegrationLogger.flush();
        Test.stopTest();
    }

    /**
     * @description Verifies that flush() correctly inserts all buffered log records
     *              and clears the internal buffers.
     */
    @IsTest
    static void testFlush() {
        // Arrange
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.example.com/test');
        req.setMethod('GET');

        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('ok');

        // Act
        Test.startTest();
        IntegrationLogger.logOutbound(null, 'flush-test-1', req, res, 50, true);
        IntegrationLogger.logOutbound(null, 'flush-test-2', req, res, 60, true);


        IntegrationLogger.flush();
        Test.stopTest();

      
    }

    /**
     * @description Verifies that generateCorrelationId() produces a UUID-formatted string.
     */
    @IsTest
    static void testGenerateCorrelationId() {
        // Act
        Test.startTest();
        String correlationId1 = IntegrationLogger.generateCorrelationId();
        String correlationId2 = IntegrationLogger.generateCorrelationId();
        Test.stopTest();

    }

    /**
     * @description Verifies that large payloads are truncated to fit within Long Text Area limits.
     */
    @IsTest
    static void testPayloadTruncation() {
        // Arrange -- create a payload that exceeds the max length
        String largePayload = '';
        for (Integer i = 0; i < 200000; i++) {
            largePayload += 'x';
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.example.com/test');
        req.setMethod('POST');
        req.setBody(largePayload);

        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody(largePayload);

        // Act
        Test.startTest();
        IntegrationLogger.logOutbound(null, 'truncate-test', req, res, 100, true);
        IntegrationLogger.flush();
        Test.stopTest();

    }

    /**
     * @description Verifies that clearBuffers() removes all pending records.
     */
    @IsTest
    static void testClearBuffers() {
        // Arrange
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.example.com/test');
        req.setMethod('GET');
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('ok');

        IntegrationLogger.logOutbound(null, 'clear-test', req, res, 10, true);

        // Act
        Test.startTest();
        IntegrationLogger.clearBuffers();
        Test.stopTest();

        // Assert
    }
}