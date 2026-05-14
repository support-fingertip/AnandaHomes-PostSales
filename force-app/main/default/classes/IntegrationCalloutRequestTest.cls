/**
 * @description Test class for IntegrationCalloutRequest
 */
@isTest
private class IntegrationCalloutRequestTest {

    @isTest
    static void defaultConstructor_setsSafeDefaults() {
        IntegrationCalloutRequest req = new IntegrationCalloutRequest();
        System.assertEquals('GET', req.method);
        System.assertEquals('application/json', req.contentType);
        System.assertEquals(120000, req.timeout);
        System.assertEquals(false, req.compressRequest);
        System.assertNotEquals(null, req.headers);
        System.assertNotEquals(null, req.queryParams);
    }

    @isTest
    static void essentialConstructor_storesArgs() {
        IntegrationCalloutRequest req = new IntegrationCalloutRequest('https://x.test', 'POST', '{"a":1}');
        System.assertEquals('https://x.test', req.endpoint);
        System.assertEquals('POST', req.method);
        System.assertEquals('{"a":1}', req.body);
    }

    @isTest
    static void addHeader_ignoresBlankOrNull() {
        IntegrationCalloutRequest req = new IntegrationCalloutRequest();
        req.addHeader('X-A', 'v').addHeader(null, 'v').addHeader('  ', 'v').addHeader('X-B', null);
        System.assertEquals(1, req.headers.size());
        System.assertEquals('v', req.headers.get('X-A'));
    }

    @isTest
    static void addQueryParam_ignoresBlankOrNull() {
        IntegrationCalloutRequest req = new IntegrationCalloutRequest();
        req.addQueryParam('p', '1').addQueryParam('', 'x').addQueryParam('q', null);
        System.assertEquals(1, req.queryParams.size());
    }

    @isTest
    static void getFullEndpoint_appendsQueryStringWithCorrectSeparator() {
        IntegrationCalloutRequest req = new IntegrationCalloutRequest('https://x.test/api', 'GET', null);
        req.addQueryParam('a', '1').addQueryParam('b', 'two');
        String url = req.getFullEndpoint();
        System.assert(url.startsWith('https://x.test/api?'));
        System.assert(url.contains('a=1'));
        System.assert(url.contains('b=two'));
    }

    @isTest
    static void getFullEndpoint_preservesExistingQuestionMark() {
        IntegrationCalloutRequest req = new IntegrationCalloutRequest('https://x.test/api?z=9', 'GET', null);
        req.addQueryParam('a', '1');
        String url = req.getFullEndpoint();
        System.assert(url.contains('?z=9&a=1'));
    }

    @isTest
    static void getFullEndpoint_prefixesNamedCredential() {
        IntegrationCalloutRequest req = new IntegrationCalloutRequest();
        req.namedCredential = 'My_NC';
        req.endpoint = '/v1/things';
        String url = req.getFullEndpoint();
        System.assertEquals('callout:My_NC/v1/things', url);
    }

    @isTest
    static void getFullEndpoint_namedCredentialOnlyWhenEndpointBlank() {
        IntegrationCalloutRequest req = new IntegrationCalloutRequest();
        req.namedCredential = 'My_NC';
        String url = req.getFullEndpoint();
        System.assertEquals('callout:My_NC', url);
    }

    @isTest
    static void isValid_requiresEndpointOrNamedCredentialAndMethod() {
        IntegrationCalloutRequest req = new IntegrationCalloutRequest();
        System.assertEquals(false, req.isValid(), 'no endpoint and no NC');
        req.endpoint = 'https://x.test';
        System.assertEquals(true, req.isValid());
        req.endpoint = null;
        req.namedCredential = 'NC';
        System.assertEquals(true, req.isValid());
        req.method = '';
        System.assertEquals(false, req.isValid());
    }
}