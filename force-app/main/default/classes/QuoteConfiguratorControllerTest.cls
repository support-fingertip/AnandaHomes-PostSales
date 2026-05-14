/**
 * @description Test class for QuoteConfiguratorController
 */
@isTest
private class QuoteConfiguratorControllerTest {

    @testSetup
    static void setup() {
        Project__c p = postSalesTestDataFactory.createProject('Quote Project');
        p.Quote_Calculation_Logic__c = 'Total_Flat_Cost__c * 0.1';
        update p;
    }

    @isTest
    static void getUnitNumericFields_returnsWrapper() {
        Project__c p = [SELECT Id FROM Project__c LIMIT 1];
        Test.startTest();
        QuoteConfiguratorController.InitWrapper w = QuoteConfiguratorController.getUnitNumericFields(p.Id);
        Test.stopTest();
        System.assertNotEquals(null, w, 'Should return wrapper');
        System.assertNotEquals(null, w.FieldInfos, 'Should have field infos');
    }

    @isTest
    static void saveFormulaRec_updatesProject() {
        Project__c p = [SELECT Id FROM Project__c LIMIT 1];
        QuoteConfiguratorController.saveFormulaRec(p.Id, 'NewFormula');
        Project__c after1 = [SELECT Quote_Calculation_Logic__c FROM Project__c WHERE Id = :p.Id];
        System.assertEquals('NewFormula', after1.Quote_Calculation_Logic__c, 'Should update');
    }

    @isTest
    static void validateFormula_returnsString() {
        String result = QuoteConfiguratorController.validateFormula('1+2');
        System.assertNotEquals(null, result, 'Should return string');
    }

    @isTest
    static void validateFormula_invalid_returnsErrorString() {
        String result = QuoteConfiguratorController.validateFormula('!@#$%');
        System.assertNotEquals(null, result, 'Should return some string (error message)');
    }
}