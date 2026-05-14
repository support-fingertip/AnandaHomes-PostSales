/**
 * @description Test class for FormulaBuilderController
 */
@isTest
private class FormulaBuilderControllerTest {

    @testSetup
    static void setup() {
        Project__c p = postSalesTestDataFactory.createProject('Formula Project');
        Unit__c u = postSalesTestDataFactory.createUnit(p.Id);

        Project_Calculation_Template__c t = new Project_Calculation_Template__c(
            Project__c = p.Id,
            Template_Name__c = 'TestTemplate',
            Description__c = 'desc',
            Is_Active__c = true,
            Source_Object_API_Name__c = 'Unit__c',
            Target_Object_API_Name__c = 'Booking__c',
            Source_Lookup_Field__c = 'Unit__c'
        );
        insert t;
    }

    @isTest
    static void getProjects_returnsList() {
        List<Project__c> list1 = FormulaBuilderController.getProjects();
        System.assert(list1.size() >= 1, 'Should return projects');
    }

    @isTest
    static void getTemplates_returnsList() {
        Project__c p = [SELECT Id FROM Project__c LIMIT 1];
        List<Project_Calculation_Template__c> list1 = FormulaBuilderController.getTemplates(p.Id);
        System.assert(list1.size() >= 1, 'Should return templates');
    }

    @isTest
    static void getTemplateWithSteps_returnsRecord() {
        Project_Calculation_Template__c t = [SELECT Id FROM Project_Calculation_Template__c LIMIT 1];
        Project_Calculation_Template__c result = FormulaBuilderController.getTemplateWithSteps(t.Id);
        System.assertEquals(t.Id, result.Id, 'Should match');
    }

    @isTest
    static void getAvailableFields_returnsMap() {
        Map<String, Object> result = FormulaBuilderController.getAvailableFields();
        System.assertNotEquals(null, result, 'Should return map');
        System.assertEquals(true, result.containsKey('unitFields'), 'Should have unitFields');
    }

    @isTest
    static void getPicklistValues_returnsList() {
        List<Map<String, String>> r = FormulaBuilderController.getPicklistValues('Account', 'Industry');
        System.assertNotEquals(null, r, 'Should return list');
    }

    @isTest
    static void getAvailableObjects_returnsList() {
        List<Map<String, String>> r = FormulaBuilderController.getAvailableObjects();
        System.assert(r.size() > 0, 'Should return objects');
    }

    @isTest
    static void getLookupFields_returnsList() {
        List<Map<String, String>> r = FormulaBuilderController.getLookupFields('Booking__c', 'Unit__c');
        System.assertNotEquals(null, r, 'Should return list');
    }

    @isTest
    static void getFieldsForObject_returnsMap() {
        Map<String, Object> r = FormulaBuilderController.getFieldsForObject('Unit__c');
        System.assertNotEquals(null, r, 'Should return map');
    }

    @isTest
    static void getCombinedFieldsForStep_returnsMap() {
        Map<String, Object> r = FormulaBuilderController.getCombinedFieldsForStep('Unit__c', 'Booking__c');
        System.assertNotEquals(null, r, 'Should return map');
    }

    @isTest
    static void saveTemplate_creates() {
        Project__c p = [SELECT Id FROM Project__c LIMIT 1];
        Map<String, Object> data = new Map<String, Object>{
            'templateName' => 'New Template',
            'description' => 'desc',
            'projectId' => p.Id,
            'isActive' => true,
            'sourceObject' => 'Unit__c',
            'targetObject' => 'Booking__c',
            'sourceLookupField' => 'Unit__c',
            'calculationDetailField' => null
        };
        Test.startTest();
        Id newId = FormulaBuilderController.saveTemplate(JSON.serialize(data));
        Test.stopTest();
        System.assertNotEquals(null, newId, 'Should return Id');
    }

    @isTest
    static void saveSteps_createsSteps() {
        Project_Calculation_Template__c t = [SELECT Id FROM Project_Calculation_Template__c LIMIT 1];
        List<Object> steps = new List<Object>{
            new Map<String, Object>{
                'stepNumber' => 1,
                'stepLabel' => 'Step 1',
                'variableName' => 'X',
                'formula' => '1+2',
                'storeInField' => null,
                'description' => null
            }
        };
        FormulaBuilderController.saveSteps(t.Id, JSON.serialize(steps));
        Integer count = [SELECT COUNT() FROM Calculation_Step__c WHERE Project_Calculation_Template__c = :t.Id];
        System.assertEquals(1, count, 'Should have 1 step');
    }

    @isTest
    static void deleteTemplate_removes() {
        Project_Calculation_Template__c t = [SELECT Id FROM Project_Calculation_Template__c LIMIT 1];
        FormulaBuilderController.deleteTemplate(t.Id);
        Integer c1 = [SELECT COUNT() FROM Project_Calculation_Template__c WHERE Id = :t.Id];
        System.assertEquals(0, c1, 'Should be deleted');
    }

    @isTest
    static void toggleTemplateStatus_updates() {
        Project_Calculation_Template__c t = [SELECT Id FROM Project_Calculation_Template__c LIMIT 1];
        FormulaBuilderController.toggleTemplateStatus(t.Id, false);
        FormulaBuilderController.toggleTemplateStatus(t.Id, true);
        Project_Calculation_Template__c after1 = [SELECT Is_Active__c FROM Project_Calculation_Template__c WHERE Id = :t.Id];
        System.assertEquals(true, after1.Is_Active__c, 'Should be active');
    }

    @isTest
    static void testCalculation_returnsResult() {
        Project_Calculation_Template__c t = [SELECT Id FROM Project_Calculation_Template__c LIMIT 1];
        Unit__c u = [SELECT Id FROM Unit__c LIMIT 1];
        Map<String, Object> r = FormulaBuilderController.testCalculation(t.Id, u.Id);
        System.assertNotEquals(null, r, 'Should return map');
    }

    @isTest
    static void getUnitsForProject_returnsList() {
        Project__c p = [SELECT Id FROM Project__c LIMIT 1];
        List<SObject> units = FormulaBuilderController.getUnitsForProject(p.Id, 'Unit__c');
        System.assertNotEquals(null, units, 'Should return list');
    }

    @isTest
    static void getRecordsForObject_returnsList() {
        Project__c p = [SELECT Id FROM Project__c LIMIT 1];
        List<SObject> recs = FormulaBuilderController.getRecordsForObject('Unit__c', p.Id);
        System.assertNotEquals(null, recs, 'Should return list');
    }

    @isTest
    static void getRichTextFields_returnsList() {
        List<Map<String, String>> r = FormulaBuilderController.getRichTextFields('Account');
        System.assertNotEquals(null, r, 'Should return list');
        List<Map<String, String>> empty1 = FormulaBuilderController.getRichTextFields('');
        System.assertEquals(0, empty1.size(), 'Empty for blank');
        List<Map<String, String>> empty2 = FormulaBuilderController.getRichTextFields('NotAnObject');
        System.assertEquals(0, empty2.size(), 'Empty for invalid');
    }
}