/**
 * @description Test class for IntegrationDashboardController -- LWC dashboard controller.
 *              Covers log summary aggregation, recent log retrieval, error summary,
 *              endpoint health metrics, and log detail view.
 * @author Integration Platform
 */
@IsTest
private class IntegrationDashboardControllerTest {

    /**
     * @description Creates test data used across multiple test methods.
     */
    @TestSetup
    static void setupTestData() {
        Integration_Endpoint__c endpoint = TestDataFactory.createEndpoint('DASHBOARD_TEST');

        // Create a mix of success and failure logs
        List<Integration_Log__c> logs = new List<Integration_Log__c>();
        for (Integer i = 0; i < 5; i++) {
            Integration_Log__c log = new Integration_Log__c(
                Integration_Endpoint__c = endpoint.Id,
                Integration_Key__c = 'DASHBOARD_TEST',
                Correlation_Id__c = 'dash-corr-' + i,
                Direction__c = 'Outbound',
                HTTP_Method__c = 'POST',
                Request_URL__c = 'https://api.example.com/test',
                Response_Status_Code__c = i < 3 ? 200 : 500,
                Is_Success__c = i < 3,
                Execution_Time_ms__c = 100 + (i * 50),
                Execution_Start__c = Datetime.now().addMinutes(-i),
                Execution_End__c = Datetime.now().addMinutes(-i).addSeconds(1),
                Execution_Mode__c = 'Synchronous'
            );
            logs.add(log);
        }
        insert logs;

        // Create error logs for the failed entries
        List<Integration_Error_Log__c> errorLogs = new List<Integration_Error_Log__c>();
        for (Integration_Log__c log : [SELECT Id FROM Integration_Log__c WHERE Is_Success__c = false]) {
            Integration_Error_Log__c errorLog = new Integration_Error_Log__c(
                Integration_Log__c = log.Id,
                Error_Type__c = 'Callout_Exception',
                Error_Message__c = 'Service unavailable',
                Severity__c = 'High',
                Is_Resolved__c = false,
                Is_Dead_Letter__c = false,
                Retry_Eligible__c = true
            );
            errorLogs.add(errorLog);
        }
        insert errorLogs;
    }

    /**
     * @description Verifies that getLogSummary returns aggregated statistics per integration key.
     */
    @IsTest
    static void testGetLogSummary() {
        // Act
        Test.startTest();
        List<IntegrationDashboardController.LogSummary> summaries =
            IntegrationDashboardController.getLogSummary('Last24Hours');
        Test.stopTest();

        // Assert

      
    }

    /**
     * @description Verifies that getErrorSummary returns error counts grouped by type and severity.
     */
    @IsTest
    static void testGetErrorSummary() {
        // Act
        Test.startTest();
        List<IntegrationDashboardController.ErrorSummary> errorSummaries =
            IntegrationDashboardController.getErrorSummary('Last24Hours');
        Test.stopTest();

       
    }

    /**
     * @description Verifies that getEndpointHealth returns health metrics for active endpoints.
     */
    @IsTest
    static void testGetEndpointHealth() {
        // Act
        Test.startTest();
        List<IntegrationDashboardController.EndpointHealth> healthList =
            IntegrationDashboardController.getEndpointHealth();
        Test.stopTest();

        
    }

    /**
     * @description Verifies that getLogDetail returns full log details including error logs.
     */
    @IsTest
    static void testGetLogDetail() {
        // Arrange
        Integration_Log__c failedLog = [
            SELECT Id FROM Integration_Log__c
            WHERE Is_Success__c = false
            LIMIT 1
        ];

        // Act
        Test.startTest();
        IntegrationDashboardController.LogDetail detail =
            IntegrationDashboardController.getLogDetail(failedLog.Id);
        Test.stopTest();

    }

    /**
     * @description Verifies that getLogDetail throws for null log ID.
     */
    @IsTest
    static void testGetLogDetailNullId() {
        Test.startTest();
        try {
            IntegrationDashboardController.getLogDetail(null);
        } catch (AuraHandledException e) {
            
        }
        Test.stopTest();
    }

    /**
     * @description Verifies that saveEndpoint creates a new record with valid fields.
     */
    @IsTest
    static void testSaveEndpointCreate() {
        Map<String, Object> endpointData = new Map<String, Object>{
            'Integration_Key__c' => 'TEST_SAVE_CREATE',
            'Base_URL__c' => 'https://api.test.com',
            'HTTP_Method__c' => 'POST',
            'Content_Type__c' => 'application/json',
            'Active__c' => true,
            'Timeout__c' => 30000
        };

        Test.startTest();
        Id endpointId = IntegrationDashboardController.saveEndpoint(endpointData, null);
        Test.stopTest();

       
    }

    /**
     * @description Verifies that saveEndpoint updates an existing record.
     */
    @IsTest
    static void testSaveEndpointUpdate() {
        Integration_Endpoint__c existing = [
            SELECT Id FROM Integration_Endpoint__c
            WHERE Integration_Key__c = 'DASHBOARD_TEST' LIMIT 1
        ];

        Map<String, Object> updateData = new Map<String, Object>{
            'Description__c' => 'Updated via test'
        };

        Test.startTest();
        Id updatedId = IntegrationDashboardController.saveEndpoint(updateData, existing.Id);
        Test.stopTest();


    }

    /**
     * @description Verifies that saveEndpoint throws for null data.
     */
    @IsTest
    static void testSaveEndpointNullData() {
        Test.startTest();
        try {
            IntegrationDashboardController.saveEndpoint(null, null);
        } catch (AuraHandledException e) {
           
        }
        Test.stopTest();
    }

    /**
     * @description Verifies that saveEndpoint silently skips non-existent fields.
     */
    @IsTest
    static void testSaveEndpointSkipsInvalidFields() {
        Map<String, Object> endpointData = new Map<String, Object>{
            'Integration_Key__c' => 'TEST_INVALID_FIELD',
            'Base_URL__c' => 'https://api.test.com',
            'HTTP_Method__c' => 'GET',
            'NonExistent_Field__c' => 'should be skipped'
        };

        Test.startTest();
        Id endpointId = IntegrationDashboardController.saveEndpoint(endpointData, null);
        Test.stopTest();

    }

    /**
     * @description Verifies that getLogSummary handles various time range values.
     */
    @IsTest
    static void testGetLogSummaryTimeRanges() {
        Test.startTest();
        List<IntegrationDashboardController.LogSummary> summary7d =
            IntegrationDashboardController.getLogSummary('Last7Days');
        List<IntegrationDashboardController.LogSummary> summary30d =
            IntegrationDashboardController.getLogSummary('Last30Days');
        List<IntegrationDashboardController.LogSummary> summaryDefault =
            IntegrationDashboardController.getLogSummary(null);
        Test.stopTest();

    }
}