/**
 * @description Test class for FormulaEvaluator
 */
@isTest
private class FormulaEvaluatorTest {

    @isTest
    static void evaluate_blankFormula_returnsZero() {
        Unit__c u = new Unit__c();
        System.assertEquals(0, FormulaEvaluator.evaluate('', u), 'Blank should return 0');
    }

    @isTest
    static void evaluate_nullUnit_throws() {
        Boolean threw = false;
        try {
            FormulaEvaluator.evaluate('1+1', null);
        } catch (FormulaEvaluator.FormulaEvaluatorException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Null unit should throw');
    }

    @isTest
    static void evaluate_basicArithmetic() {
        Unit__c u = new Unit__c();
        System.assertEquals(7, FormulaEvaluator.evaluate('3+4', u), 'addition');
        System.assertEquals(2, FormulaEvaluator.evaluate('6/3', u), 'division');
        System.assertEquals(20, FormulaEvaluator.evaluate('4*5', u), 'multiplication');
        System.assertEquals(1, FormulaEvaluator.evaluate('5-4', u), 'subtraction');
    }

    @isTest
    static void evaluate_parenthesesAndPrecedence() {
        Unit__c u = new Unit__c();
        System.assertEquals(14, FormulaEvaluator.evaluate('2+3*4', u), 'precedence');
        System.assertEquals(20, FormulaEvaluator.evaluate('(2+3)*4', u), 'parens');
    }

    @isTest
    static void evaluate_percentAndUnary() {
        Unit__c u = new Unit__c();
        Decimal half = FormulaEvaluator.evaluate('50%', u);
        System.assertEquals(0.5, half, 'percent');
        Decimal neg = FormulaEvaluator.evaluate('-3+5', u);
        System.assertEquals(2, neg, 'unary minus');
    }

    @isTest
    static void evaluate_functions() {
        Unit__c u = new Unit__c();
        System.assertEquals(5, FormulaEvaluator.evaluate('ABS(-5)', u), 'ABS');
        System.assertEquals(3, FormulaEvaluator.evaluate('CEIL(2.1)', u), 'CEIL');
        System.assertEquals(2, FormulaEvaluator.evaluate('FLOOR(2.9)', u), 'FLOOR');
        System.assertEquals(2, FormulaEvaluator.evaluate('MIN(2,5)', u), 'MIN');
        System.assertEquals(5, FormulaEvaluator.evaluate('MAX(2,5)', u), 'MAX');
        System.assertEquals(8, FormulaEvaluator.evaluate('POWER(2,3)', u), 'POWER');
    }

    @isTest
    static void evaluate_divisionByZero_returnsZero() {
        Unit__c u = new Unit__c();
        // Division by zero should not crash - returns 0
        Decimal result = FormulaEvaluator.evaluate('10/0', u);
        System.assertEquals(0, result, 'Div-by-zero should not crash');
    }

    @isTest
    static void evaluate_invalidCharacter_throws() {
        Unit__c u = new Unit__c();
        Boolean threw = false;
        try {
            FormulaEvaluator.evaluate('1@2', u);
        } catch (FormulaEvaluator.FormulaEvaluatorException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Invalid character should throw');
    }

    @isTest
    static void evaluate_invalidExpression_throws() {
        Unit__c u = new Unit__c();
        Boolean threw = false;
        try {
            FormulaEvaluator.evaluate('1+', u);
        } catch (FormulaEvaluator.FormulaEvaluatorException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Incomplete expression should throw');
    }

    @isTest
    static void validate_blankFormula_returnsError() {
        System.assertEquals('Formula cannot be empty', FormulaEvaluator.validate(''));
    }

    @isTest
    static void validate_validFormula_returnsValid() {
        System.assertEquals('VALID', FormulaEvaluator.validate('1+2*3'));
    }

    @isTest
    static void validate_mismatchedParens_returnsError() {
        String result = FormulaEvaluator.validate('(1+2');
        System.assert(result.startsWith('Error:'), 'Mismatched parens should report error');
    }

    @isTest
    static void validate_invalidField_returnsError() {
        String result = FormulaEvaluator.validate('NotAField__c+1');
        System.assert(result.startsWith('Error:'), 'Invalid field should report error');
    }

    @isTest
    static void validate_unsupportedFunction_returnsError() {
        String result = FormulaEvaluator.validate('UNKNOWN(1)');
        System.assert(result.startsWith('Error:'), 'Unknown function should report error');
    }
}