/**
 * @description Utility class for creating test data for the Integration Orchestration Platform.
 *              All methods insert records and return the persisted instances.
 *              This is NOT a test class -- it is a helper used by @IsTest classes.
 * @author Integration Platform
 */
public class TestDataFactory {

    /**
     * @description Creates and inserts a fully populated Integration_Endpoint__c record.
     * @param key The unique Integration_Key__c value
     * @return The inserted Integration_Endpoint__c record
     */
    public static Integration_Endpoint__c createEndpoint(String key) {
        Integration_Endpoint__c endpoint = new Integration_Endpoint__c(
            Integration_Key__c = key,
            Base_URL__c = 'https://api.example.com',
            Path__c = '/v1/resource',
            HTTP_Method__c = 'POST',
            Content_Type__c = 'application/json',
            Timeout__c = 30000,
            Active__c = true,
            Custom_Headers__c = '{"X-Custom-Header":"TestValue"}',
            Query_Parameters__c = '{"param1":"value1"}',
            Execution_Mode__c = 'Synchronous',
            Category__c = 'Test',
            Owner_Team__c = 'Integration Team',
            Description__c = 'Test endpoint for ' + key
        );
        insert endpoint;
        return endpoint;
    }

    /**
     * @description Creates and inserts an Integration_Auth_Profile__c record.
     * @param name The unique Profile_Name__c value
     * @param authType The Auth_Type__c picklist value (API_Key, Basic_Auth, OAuth_2_0, HMAC, None)
     * @return The inserted Integration_Auth_Profile__c record
     */
    public static Integration_Auth_Profile__c createAuthProfile(String name, String authType) {
        Integration_Auth_Profile__c profile = new Integration_Auth_Profile__c(
            Profile_Name__c = name,
            Auth_Type__c = authType,
            Active__c = true,
            Description__c = 'Test auth profile'
        );

        if (authType == 'API_Key') {
            profile.Auth_Header_Name__c = 'x-api-key';
            profile.API_Key__c = 'test-api-key-12345';
        } else if (authType == 'Basic_Auth') {
            profile.Username__c = 'testuser';
            profile.Password__c = 'testpass';
        } else if (authType == 'OAuth_2_0') {
            profile.OAuth_Token_Endpoint__c = 'https://auth.example.com/token';
            profile.OAuth_Client_Id__c = 'client_id_123';
            profile.OAuth_Client_Secret__c = 'client_secret_456';
            profile.OAuth_Scope__c = 'read write';
            profile.OAuth_Grant_Type__c = 'client_credentials';
            profile.Token_Cache_Duration__c = 3600;
        } else if (authType == 'HMAC') {
            profile.HMAC_Secret__c = 'hmac-test-secret-key';
            profile.HMAC_Algorithm__c = 'HmacSHA256';
            profile.HMAC_Header_Name__c = 'X-HMAC-Signature';
        }

        insert profile;
        return profile;
    }

    /**
     * @description Creates and inserts an Integration_Retry_Config__c record.
     * @param name The unique Config_Name__c value
     * @return The inserted Integration_Retry_Config__c record
     */
    public static Integration_Retry_Config__c createRetryConfig(String name) {
        Integration_Retry_Config__c config = new Integration_Retry_Config__c(
            Config_Name__c = name,
            Max_Retries__c = 3,
            Retry_Interval__c = 60,
            Backoff_Multiplier__c = 2.0,
            Max_Retry_Interval__c = 3600,
            Retry_On_Status_Codes__c = '408,429,500,502,503,504',
            Dead_Letter_Enabled__c = true,
            Active__c = true
        );
        insert config;
        return config;
    }

    /**
     * @description Creates and inserts an Integration_Request_Template__c record.
     * @param endpointId The parent Integration_Endpoint__c Id
     * @param body The Body_Template__c content
     * @return The inserted Integration_Request_Template__c record
     */
    public static Integration_Request_Template__c createRequestTemplate(Id endpointId, String body) {
        Integration_Request_Template__c template = new Integration_Request_Template__c(
            Integration_Endpoint__c = endpointId,
            Template_Name__c = 'Test Template',
            Body_Template__c = body,
            Source_Object__c = 'Account',
            Source_Fields__c = 'Id, Name',
            Active__c = true
        );
        insert template;
        return template;
    }

    /**
     * @description Creates and inserts an Integration_Response_Mapping__c record.
     * @param endpointId The parent Integration_Endpoint__c Id
     * @param path The Response_JSON_Path__c value
     * @param targetField The Target_Field__c value
     * @return The inserted Integration_Response_Mapping__c record
     */
    public static Integration_Response_Mapping__c createResponseMapping(Id endpointId, String path, String targetField) {
        Integration_Response_Mapping__c mapping = new Integration_Response_Mapping__c(
            Integration_Endpoint__c = endpointId,
            Mapping_Name__c = 'Map ' + targetField,
            Response_JSON_Path__c = path,
            Target_Object__c = 'Account',
            Target_Field__c = targetField,
            Data_Type__c = 'String',
            Active__c = true,
            Order__c = 1
        );
        insert mapping;
        return mapping;
    }

    /**
     * @description Creates and inserts an Integration_Field_Mapping__c record.
     * @param endpointId The parent Integration_Endpoint__c Id
     * @param source The Source_Field__c value
     * @param target The Target_Field__c value
     * @param direction The Direction__c value (Inbound, Outbound, Both)
     * @return The inserted Integration_Field_Mapping__c record
     */
    public static Integration_Field_Mapping__c createFieldMapping(Id endpointId, String source, String target, String direction) {
        Integration_Field_Mapping__c mapping = new Integration_Field_Mapping__c(
            Integration_Endpoint__c = endpointId,
            Mapping_Name__c = source + ' to ' + target,
            Direction__c = direction,
            Source_Field__c = source,
            Target_Field__c = target,
            Target_Object__c = 'Account',
            Data_Type__c = 'String',
            Is_Required__c = false,
            Order__c = 1,
            Active__c = true
        );
        insert mapping;
        return mapping;
    }

    /**
     * @description Creates and inserts an Integration_Log__c record.
     * @param endpointId The lookup Integration_Endpoint__c Id (can be null)
     * @param success Whether the log represents a successful execution
     * @return The inserted Integration_Log__c record
     */
    public static Integration_Log__c createLog(Id endpointId, Boolean success) {
        Integration_Log__c log = new Integration_Log__c(
            Integration_Endpoint__c = endpointId,
            Integration_Key__c = 'TEST_KEY',
            Correlation_Id__c = 'test-corr-' + String.valueOf(Math.random()).substring(2, 10),
            Direction__c = 'Outbound',
            HTTP_Method__c = 'POST',
            Request_URL__c = 'https://api.example.com/v1/resource',
            Request_Body__c = '{"test":"data"}',
            Response_Status_Code__c = success ? 200 : 500,
            Response_Body__c = success ? '{"status":"ok"}' : '{"error":"fail"}',
            Is_Success__c = success,
            Execution_Time_ms__c = 150,
            Execution_Start__c = Datetime.now().addSeconds(-1),
            Execution_End__c = Datetime.now(),
            Execution_Mode__c = 'Synchronous',
            Triggered_By__c = UserInfo.getUserId()
        );
        insert log;
        return log;
    }

    /**
     * @description Creates and inserts an Integration_Error_Log__c record.
     * @param logId The parent Integration_Log__c Id
     * @param errorType The Error_Type__c picklist value
     * @param message The Error_Message__c value
     * @return The inserted Integration_Error_Log__c record
     */
    public static Integration_Error_Log__c createErrorLog(Id logId, String errorType, String message) {
        Integration_Error_Log__c errorLog = new Integration_Error_Log__c(
            Integration_Log__c = logId,
            Error_Type__c = errorType,
            Error_Message__c = message,
            Stack_Trace__c = 'Test stack trace line 1\nTest stack trace line 2',
            Severity__c = 'High',
            Is_Resolved__c = false,
            Is_Dead_Letter__c = false,
            Retry_Eligible__c = true,
            Original_Payload__c = '{"original":"payload"}'
        );
        insert errorLog;
        return errorLog;
    }
}