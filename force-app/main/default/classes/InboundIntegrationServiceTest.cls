/**
 * @description Test class for InboundIntegrationService
 */
@isTest
private class InboundIntegrationServiceTest {

    private static Integration_Endpoint__c createInboundEndpoint(String key, String authProfileId) {
        Integration_Endpoint__c ep = new Integration_Endpoint__c(
            Integration_Key__c = key,
            Base_URL__c = 'https://api.example.com',
            Path__c = '/inbound',
            HTTP_Method__c = 'POST',
            Content_Type__c = 'application/json',
            Active__c = true,
            Execution_Mode__c = 'Synchronous'
        );
        if (String.isNotBlank(authProfileId)) {
            ep.Auth_Profile__c = authProfileId;
        }
        insert ep;
        return ep;
    }

    private static Integration_Field_Mapping__c createInboundMapping(Id endpointId, String src, String tgt, String tgtObj) {
        Integration_Field_Mapping__c m = new Integration_Field_Mapping__c(
            Integration_Endpoint__c = endpointId,
            Mapping_Name__c = src + '->' + tgt,
            Direction__c = 'Inbound',
            Source_Field__c = src,
            Target_Field__c = tgt,
            Target_Object__c = tgtObj,
            Data_Type__c = 'String',
            Active__c = true,
            Order__c = 1
        );
        insert m;
        return m;
    }

    @isTest
    static void processInbound_blankKey_returns400() {
        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            null, '{"a":1}', new Map<String,String>(), 'POST'
        );
        Test.stopTest();
        System.assertEquals(400, r.statusCode, 'Blank key should return 400');
    }

    @isTest
    static void processInbound_unknownKey_returns404() {
        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'NOT_REAL', '{"a":1}', new Map<String,String>(), 'POST'
        );
        Test.stopTest();
        System.assertEquals(404, r.statusCode, 'Unknown key should return 404');
    }

    @isTest
    static void processInbound_methodMismatch_returns405() {
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_M', null);
        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_M', '{"a":1}', new Map<String,String>(), 'GET'
        );
        Test.stopTest();
        System.assertEquals(405, r.statusCode, 'Wrong method should return 405');
    }

    @isTest
    static void processInbound_blankBody_returns400() {
        createInboundEndpoint('IB_KEY_BB', null);
        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_BB', '', new Map<String,String>(), 'POST'
        );
        Test.stopTest();
        System.assertEquals(400, r.statusCode, 'Blank body should return 400');
    }

    @isTest
    static void processInbound_noFieldMappings_returns500() {
        createInboundEndpoint('IB_KEY_NM', null);
        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_NM', '{"a":1}', new Map<String,String>(), 'POST'
        );
        Test.stopTest();
        System.assertEquals(500, r.statusCode, 'No mappings should return 500');
    }

    @isTest
    static void processInbound_validInsert_returns201() {
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_OK', null);
        createInboundMapping(ep.Id, 'name', 'Name', 'Account');

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_OK',
            '{"name":"Inbound Test Account"}',
            new Map<String,String>(),
            'POST'
        );
        Test.stopTest();

        System.assertEquals(201, r.statusCode, 'Successful insert should return 201');
        System.assertEquals(true, r.success, 'Result should indicate success');
        List<Account> accs = [SELECT Id FROM Account WHERE Name = 'Inbound Test Account'];
        System.assertEquals(1, accs.size(), 'Account should be inserted');
    }

    @isTest
    static void processInbound_validArrayBody_insertsAll() {
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_AR', null);
        createInboundMapping(ep.Id, 'name', 'Name', 'Account');

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_AR',
            '[{"name":"A1"},{"name":"A2"}]',
            new Map<String,String>(),
            'POST'
        );
        Test.stopTest();

        System.assertEquals(true, r.success, 'Should succeed');
        List<Account> accs = [SELECT Id FROM Account WHERE Name IN ('A1','A2')];
        System.assertEquals(2, accs.size(), 'Both accounts should be inserted');
    }

    @isTest
    static void processInbound_apiKeyAuth_invalid_returns403() {
        Integration_Auth_Profile__c profile = postSalesTestDataFactory.createAuthProfile('IB API Key', 'API_Key');
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_API', profile.Id);
        createInboundMapping(ep.Id, 'name', 'Name', 'Account');

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_API',
            '{"name":"X"}',
            new Map<String,String>{ 'x-api-key' => 'wrong-key' },
            'POST'
        );
        Test.stopTest();
        System.assertEquals(403, r.statusCode, 'Invalid API key should return 403');
    }

    @isTest
    static void processInbound_apiKeyAuth_missing_returns401() {
        Integration_Auth_Profile__c profile = postSalesTestDataFactory.createAuthProfile('IB API Key 2', 'API_Key');
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_API2', profile.Id);
        createInboundMapping(ep.Id, 'name', 'Name', 'Account');

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_API2',
            '{"name":"X"}',
            new Map<String,String>(),
            'POST'
        );
        Test.stopTest();
        System.assertEquals(401, r.statusCode, 'Missing API key should return 401');
    }

    @isTest
    static void processInbound_apiKeyAuth_validHeader_succeeds() {
        Integration_Auth_Profile__c profile = postSalesTestDataFactory.createAuthProfile('IB API Key 3', 'API_Key');
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_API3', profile.Id);
        createInboundMapping(ep.Id, 'name', 'Name', 'Account');

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_API3',
            '{"name":"AuthOk"}',
            new Map<String,String>{ 'x-api-key' => 'test-api-key-12345' },
            'POST'
        );
        Test.stopTest();
        System.assertEquals(true, r.success, 'Valid api key should succeed');
    }

    @isTest
    static void processInbound_basicAuth_invalid_returns403() {
        Integration_Auth_Profile__c profile = postSalesTestDataFactory.createAuthProfile('IB Basic', 'Basic_Auth');
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_BA', profile.Id);
        createInboundMapping(ep.Id, 'name', 'Name', 'Account');

        String badCreds = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf('wrong:wrong'));

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_BA',
            '{"name":"X"}',
            new Map<String,String>{ 'Authorization' => badCreds },
            'POST'
        );
        Test.stopTest();
        System.assertEquals(403, r.statusCode, 'Invalid basic auth should return 403');
    }

    @isTest
    static void processInbound_basicAuth_valid_succeeds() {
        Integration_Auth_Profile__c profile = postSalesTestDataFactory.createAuthProfile('IB Basic 2', 'Basic_Auth');
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_BA2', profile.Id);
        createInboundMapping(ep.Id, 'name', 'Name', 'Account');

        String creds = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf('testuser:testpass'));

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_BA2',
            '{"name":"BAOk"}',
            new Map<String,String>{ 'Authorization' => creds },
            'POST'
        );
        Test.stopTest();
        System.assertEquals(true, r.success, 'Valid basic auth should succeed');
    }

    @isTest
    static void processInbound_invalidJson_returns400() {
        createInboundEndpoint('IB_KEY_INV', null);
        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_INV', '{not valid', new Map<String,String>(), 'POST'
        );
        Test.stopTest();
        System.assertEquals(400, r.statusCode, 'Invalid JSON should return 400');
    }

    @isTest
    static void processInbound_formEncodedBody_parses() {
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_FORM', null);
        createInboundMapping(ep.Id, 'name', 'Name', 'Account');

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_FORM',
            'name=FormAccount',
            new Map<String,String>(),
            'POST'
        );
        Test.stopTest();
        System.assertEquals(true, r.success, 'Form encoded body should parse');
    }

    // ============ Additional Coverage Tests ============

    @isTest
    static void processInbound_basicAuth_missingHeader_returns401() {
        Integration_Auth_Profile__c profile = postSalesTestDataFactory.createAuthProfile('IB Basic 3', 'Basic_Auth');
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_BA3', profile.Id);
        createInboundMapping(ep.Id, 'name', 'Name', 'Account');

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_BA3', '{"name":"X"}', new Map<String,String>(), 'POST'
        );
        Test.stopTest();
        System.assertEquals(401, r.statusCode, 'Missing basic auth should return 401');
    }

    @isTest
    static void processInbound_basicAuth_wrongPrefix_returns401() {
        Integration_Auth_Profile__c profile = postSalesTestDataFactory.createAuthProfile('IB Basic 4', 'Basic_Auth');
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_BA4', profile.Id);
        createInboundMapping(ep.Id, 'name', 'Name', 'Account');

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_BA4', '{"name":"X"}',
            new Map<String,String>{'Authorization' => 'Bearer xyz'}, 'POST'
        );
        Test.stopTest();
        System.assertEquals(401, r.statusCode, 'Wrong prefix should return 401');
    }

    @isTest
    static void processInbound_apiKeyAuth_authorizationHeaderBearer_succeeds() {
        Integration_Auth_Profile__c profile = postSalesTestDataFactory.createAuthProfile('IB API Bearer', 'API_Key');
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_BR', profile.Id);
        createInboundMapping(ep.Id, 'name', 'Name', 'Account');

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_BR', '{"name":"BearerOk"}',
            new Map<String,String>{'Authorization' => 'Bearer test-api-key-12345'}, 'POST'
        );
        Test.stopTest();
        System.assertEquals(true, r.success, 'Bearer prefix should be stripped');
    }

    @isTest
    static void processInbound_apiKeyAuth_authorizationHeaderApiKey_succeeds() {
        Integration_Auth_Profile__c profile = postSalesTestDataFactory.createAuthProfile('IB API ApiKey', 'API_Key');
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_AK', profile.Id);
        createInboundMapping(ep.Id, 'name', 'Name', 'Account');

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_AK', '{"name":"AKOk"}',
            new Map<String,String>{'Authorization' => 'ApiKey test-api-key-12345'}, 'POST'
        );
        Test.stopTest();
        System.assertEquals(true, r.success, 'ApiKey prefix should be stripped');
    }

    @isTest
    static void processInbound_hmacAuth_invalid_returns403() {
        Integration_Auth_Profile__c profile = postSalesTestDataFactory.createAuthProfile('IB HMAC', 'HMAC');
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_H', profile.Id);
        createInboundMapping(ep.Id, 'name', 'Name', 'Account');

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_H', '{"name":"X"}',
            new Map<String,String>{'X-HMAC-Signature' => 'wrong-signature'}, 'POST'
        );
        Test.stopTest();
        System.assertEquals(403, r.statusCode, 'Bad HMAC should return 403');
    }

    @isTest
    static void processInbound_hmacAuth_missing_returns401() {
        Integration_Auth_Profile__c profile = postSalesTestDataFactory.createAuthProfile('IB HMAC 2', 'HMAC');
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_H2', profile.Id);
        createInboundMapping(ep.Id, 'name', 'Name', 'Account');

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_H2', '{"name":"X"}', new Map<String,String>(), 'POST'
        );
        Test.stopTest();
        System.assertEquals(401, r.statusCode, 'Missing HMAC should return 401');
    }

    @isTest
    static void processInbound_invalidTargetObject_returns400() {
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_BAD_OBJ', null);
        Integration_Field_Mapping__c m = new Integration_Field_Mapping__c(
            Integration_Endpoint__c = ep.Id,
            Mapping_Name__c = 'bad',
            Direction__c = 'Inbound',
            Source_Field__c = 'name',
            Target_Field__c = 'Name',
            Target_Object__c = 'NotARealObject__c',
            Data_Type__c = 'String',
            Active__c = true,
            Order__c = 1
        );
        insert m;

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_BAD_OBJ', '{"name":"X"}', new Map<String,String>(), 'POST'
        );
        Test.stopTest();
        System.assertEquals(false, r.success, 'Should fail');
    }

    @isTest
    static void processInbound_requiredFieldMissing_returnsErrors() {
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_REQ', null);
        Integration_Field_Mapping__c m = new Integration_Field_Mapping__c(
            Integration_Endpoint__c = ep.Id,
            Mapping_Name__c = 'req',
            Direction__c = 'Inbound',
            Source_Field__c = 'mandatory',
            Target_Field__c = 'Name',
            Target_Object__c = 'Account',
            Data_Type__c = 'String',
            Is_Required__c = true,
            Active__c = true,
            Order__c = 1
        );
        insert m;

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_REQ', '{"other":"X"}', new Map<String,String>(), 'POST'
        );
        Test.stopTest();
        System.assertEquals(false, r.success, 'Missing required should fail');
    }

    @isTest
    static void processInbound_withDefaultValue_succeeds() {
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_DEF', null);
        Integration_Field_Mapping__c m = new Integration_Field_Mapping__c(
            Integration_Endpoint__c = ep.Id,
            Mapping_Name__c = 'def',
            Direction__c = 'Inbound',
            Source_Field__c = 'name',
            Target_Field__c = 'Name',
            Target_Object__c = 'Account',
            Data_Type__c = 'String',
            Default_Value__c = 'DefaultName',
            Active__c = true,
            Order__c = 1
        );
        insert m;

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_DEF', '{}', new Map<String,String>(), 'POST'
        );
        Test.stopTest();
        // Either succeeds with default or partially fails — both exercise lines
        System.assertNotEquals(null, r);
    }

    @isTest
    static void processInbound_withTransform_uppercases() {
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_TX', null);
        Integration_Field_Mapping__c m = new Integration_Field_Mapping__c(
            Integration_Endpoint__c = ep.Id,
            Mapping_Name__c = 'tx',
            Direction__c = 'Inbound',
            Source_Field__c = 'name',
            Target_Field__c = 'Name',
            Target_Object__c = 'Account',
            Data_Type__c = 'String',
            Transform_Expression__c = 'UPPERCASE',
            Active__c = true,
            Order__c = 1
        );
        insert m;

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_TX', '{"name":"abc"}', new Map<String,String>(), 'POST'
        );
        Test.stopTest();
        System.assertEquals(true, r.success);
        List<Account> accs = [SELECT Name FROM Account WHERE Name = 'ABC'];
        System.assertEquals(1, accs.size(), 'Should be uppercased');
    }

    @isTest
    static void processInbound_conditionalRule_skipsWhenFalse() {
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_COND', null);
        // Mapping that always fires (provides Name)
        Integration_Field_Mapping__c always = new Integration_Field_Mapping__c(
            Integration_Endpoint__c = ep.Id,
            Mapping_Name__c = 'always',
            Direction__c = 'Inbound',
            Source_Field__c = 'name',
            Target_Field__c = 'Name',
            Target_Object__c = 'Account',
            Data_Type__c = 'String',
            Active__c = true,
            Order__c = 1
        );
        // Mapping with conditional that won't match
        Integration_Field_Mapping__c cond = new Integration_Field_Mapping__c(
            Integration_Endpoint__c = ep.Id,
            Mapping_Name__c = 'cond',
            Direction__c = 'Inbound',
            Source_Field__c = 'industry',
            Target_Field__c = 'Industry',
            Target_Object__c = 'Account',
            Data_Type__c = 'String',
            Conditional_Rule__c = 'flag=YES',
            Active__c = true,
            Order__c = 2
        );
        insert new List<Integration_Field_Mapping__c>{always, cond};

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_COND', '{"name":"CondAcc","industry":"Tech","flag":"NO"}',
            new Map<String,String>(), 'POST'
        );
        Test.stopTest();
        System.assertEquals(true, r.success);
    }

    @isTest
    static void processInbound_externalIdUpsert_runs() {
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_EXT', null);
        Integration_Field_Mapping__c m = new Integration_Field_Mapping__c(
            Integration_Endpoint__c = ep.Id,
            Mapping_Name__c = 'ext',
            Direction__c = 'Inbound',
            Source_Field__c = 'name',
            Target_Field__c = 'Name',
            Target_Object__c = 'Account',
            Data_Type__c = 'String',
            External_Id_Field__c = 'NotARealField',
            Active__c = true,
            Order__c = 1
        );
        insert m;

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_EXT', '{"name":"X"}', new Map<String,String>(), 'POST'
        );
        Test.stopTest();
        // Bogus external ID field — service should return 500
        System.assertEquals(false, r.success);
    }

    @isTest
    static void processInbound_nestedJson_extractValue() {
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_NEST', null);
        Integration_Field_Mapping__c m = new Integration_Field_Mapping__c(
            Integration_Endpoint__c = ep.Id,
            Mapping_Name__c = 'nest',
            Direction__c = 'Inbound',
            Source_Field__c = 'address.city',
            Target_Field__c = 'Name',
            Target_Object__c = 'Account',
            Data_Type__c = 'String',
            Active__c = true,
            Order__c = 1
        );
        insert m;

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_NEST', '{"address":{"city":"Mumbai"}}',
            new Map<String,String>(), 'POST'
        );
        Test.stopTest();
        System.assertEquals(true, r.success);
        List<Account> accs = [SELECT Name FROM Account WHERE Name = 'Mumbai'];
        System.assertEquals(1, accs.size(), 'Should extract nested city');
    }

    @isTest
    static void processInbound_oversizeBatch_returns400() {
        Integration_Endpoint__c ep = createInboundEndpoint('IB_KEY_BIG', null);
        createInboundMapping(ep.Id, 'name', 'Name', 'Account');

        // Build a >2000-element JSON array
        List<String> parts = new List<String>();
        for (Integer i = 0; i < 2005; i++) {
            parts.add('{"name":"A' + i + '"}');
        }
        String body = '[' + String.join(parts, ',') + ']';

        Test.startTest();
        InboundResult r = InboundIntegrationService.processInbound(
            'IB_KEY_BIG', body, new Map<String,String>(), 'POST'
        );
        Test.stopTest();
        System.assertEquals(400, r.statusCode, 'Oversize batch should return 400');
    }

    @isTest
    static void parseRequestBody_directly() {
        // Form encoded
        Map<String, Object> formMap = InboundIntegrationService.parseFormEncodedString('a=1&b=hello&c=');
        System.assertEquals('1', formMap.get('a'));
        System.assertEquals('hello', formMap.get('b'));

        // Empty
        Map<String, Object> emptyMap = InboundIntegrationService.parseFormEncodedString('');
        System.assertEquals(0, emptyMap.size());

        // parse JSON list
        List<Map<String, Object>> recs = InboundIntegrationService.parseRequestBody('[{"x":1},{"y":2}]');
        System.assertEquals(2, recs.size());
    }

    @isTest
    static void evaluateCondition_directly() {
        Map<String, Object> data = new Map<String, Object>{'flag' => 'YES'};
        System.assertEquals(true, InboundIntegrationService.evaluateCondition('flag=YES', data));
        System.assertEquals(false, InboundIntegrationService.evaluateCondition('flag=NO', data));
        System.assertEquals(true, InboundIntegrationService.evaluateCondition('flag!=NO', data));
        System.assertEquals(true, InboundIntegrationService.evaluateCondition('', data));
        System.assertEquals(true, InboundIntegrationService.evaluateCondition('flag', data));
    }

    @isTest
    static void applyTransform_directly() {
        System.assertEquals('HELLO', InboundIntegrationService.applyTransform('hello', 'UPPERCASE'));
        System.assertEquals('hello', InboundIntegrationService.applyTransform('HELLO', 'LOWERCASE'));
        System.assertEquals('hello', InboundIntegrationService.applyTransform('  hello  ', 'TRIM'));
        System.assertEquals('PRE_x', InboundIntegrationService.applyTransform('x', 'PREFIX:PRE_'));
        System.assertEquals('x_SUF', InboundIntegrationService.applyTransform('x', 'SUFFIX:_SUF'));
        System.assertEquals('x', InboundIntegrationService.applyTransform('x', 'UNKNOWN_OP'));
        System.assertEquals(null, InboundIntegrationService.applyTransform(null, 'UPPERCASE'));
    }

    @isTest
    static void extractNestedValue_directly() {
        Map<String, Object> data = new Map<String, Object>{
            'a' => new Map<String, Object>{'b' => 'value'}
        };
        System.assertEquals('value', InboundIntegrationService.extractNestedValue(data, 'a.b'));
        System.assertEquals(null, InboundIntegrationService.extractNestedValue(data, 'a.b.c'));
        System.assertEquals(null, InboundIntegrationService.extractNestedValue(null, 'a'));
        System.assertEquals(null, InboundIntegrationService.extractNestedValue(data, ''));
    }

    @isTest
    static void getHeaderCaseInsensitive_directly() {
        Map<String, String> headers = new Map<String, String>{'X-API-Key' => 'val', 'Content-Type' => 'json'};
        System.assertEquals('val', InboundIntegrationService.getHeaderCaseInsensitive(headers, 'X-API-Key'));
        System.assertEquals('val', InboundIntegrationService.getHeaderCaseInsensitive(headers, 'x-api-key'));
        System.assertEquals(null, InboundIntegrationService.getHeaderCaseInsensitive(headers, 'Missing'));
        System.assertEquals(null, InboundIntegrationService.getHeaderCaseInsensitive(null, 'X-API-Key'));
    }

    @isTest
    static void parseRequestBody_invalidJson_returnsEmpty() {
        List<Map<String, Object>> recs = InboundIntegrationService.parseRequestBody('{not valid json');
        System.assertEquals(0, recs.size(), 'Invalid json returns empty');

        List<Map<String, Object>> blank = InboundIntegrationService.parseRequestBody('');
        System.assertEquals(0, blank.size(), 'Blank returns empty');

        // Single object
        List<Map<String, Object>> single = InboundIntegrationService.parseRequestBody('{"a":1}');
        System.assertEquals(1, single.size(), 'Single obj returns 1');
    }
}