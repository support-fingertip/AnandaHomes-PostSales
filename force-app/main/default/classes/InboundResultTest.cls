/**
 * @description Test class for InboundResult
 */
@isTest
private class InboundResultTest {

    @isTest
    static void defaultConstructor_initialisesSafeDefaults() {
        InboundResult r = new InboundResult();
        System.assertEquals(false, r.success, 'success defaults to false');
        System.assertEquals(200, r.statusCode, 'statusCode defaults to 200');
        System.assertNotEquals(null, r.recordIds, 'recordIds list initialised');
        System.assertEquals(0, r.recordsProcessed, 'recordsProcessed defaults to 0');
        System.assertEquals(0, r.recordsFailed, 'recordsFailed defaults to 0');
        System.assertNotEquals(null, r.errors, 'errors list initialised');
        System.assertNotEquals(null, r.correlationId, 'correlationId generated');
    }

    @isTest
    static void successFactory_marksSuccessAndCopiesRecordIds() {
        Account a = new Account(Name = 'T');
        insert a;
        InboundResult r = InboundResult.success(new List<Id>{ a.Id }, 1);
        System.assertEquals(true, r.success);
        System.assertEquals(200, r.statusCode);
        System.assertEquals(1, r.recordIds.size());
        System.assertEquals(1, r.recordsProcessed);
        System.assertEquals(0, r.recordsFailed);
    }

    @isTest
    static void successFactory_handlesNullArgs() {
        InboundResult r = InboundResult.success(null, null);
        System.assertEquals(true, r.success);
        System.assertEquals(0, r.recordIds.size());
        System.assertEquals(0, r.recordsProcessed);
    }

    @isTest
    static void failureFactory_setsStatusAndMessage() {
        InboundResult r = InboundResult.failure(400, 'bad input');
        System.assertEquals(false, r.success);
        System.assertEquals(400, r.statusCode);
        System.assertEquals('bad input', r.errorMessage);
    }

    @isTest
    static void partialFactory_marksMultiStatusWhenSomeFailed() {
        InboundResult r = InboundResult.partial(new List<Id>(), 3, 2, new List<String>{ 'e1', 'e2' });
        System.assertEquals(false, r.success);
        System.assertEquals(207, r.statusCode);
        System.assertEquals(3, r.recordsProcessed);
        System.assertEquals(2, r.recordsFailed);
        System.assertEquals(2, r.errors.size());
    }

    @isTest
    static void partialFactory_treatsZeroFailedAsSuccess() {
        InboundResult r = InboundResult.partial(null, 5, 0, null);
        System.assertEquals(true, r.success);
        System.assertEquals(200, r.statusCode);
    }

    @isTest
    static void toResponseMap_includesPopulatedFieldsOnly() {
        InboundResult r = InboundResult.failure(500, 'boom');
        Map<String, Object> body = r.toResponseMap();
        System.assertEquals(false, body.get('success'));
        System.assert(body.containsKey('correlationId'));
        System.assertEquals('boom', body.get('errorMessage'));
        System.assertEquals(false, body.containsKey('recordIds'), 'empty recordIds omitted');
    }

    @isTest
    static void toResponseMap_serialisesRecordIdsAsStrings() {
        Account a = new Account(Name = 'T');
        insert a;
        InboundResult r = InboundResult.success(new List<Id>{ a.Id }, 1);
        r.errors = new List<String>{ 'warn' };
        Map<String, Object> body = r.toResponseMap();
        System.assert(body.containsKey('recordIds'));
        System.assert(body.containsKey('errors'));
    }
}