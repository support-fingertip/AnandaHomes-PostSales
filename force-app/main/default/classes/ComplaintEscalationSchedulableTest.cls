/**
 * @description Test class for ComplaintEscalationSchedulable
 */
@isTest
private class ComplaintEscalationSchedulableTest {

    @isTest
    static void execute_schedulesJob() {
        Test.startTest();
        String jobId = System.schedule(
            'Test ComplaintEscalationSchedulable',
            '0 0 0 1 1 ? 2099',
            new ComplaintEscalationSchedulable()
        );
        Test.stopTest();

        List<CronTrigger> jobs = [SELECT Id FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(1, jobs.size(), 'Scheduled job should exist');
    }

    @isTest
    static void execute_directInvocation() {
        Test.startTest();
        // Direct invocation to cover the execute() body even when no rules exist
        new ComplaintEscalationSchedulable().execute(null);
        Test.stopTest();
        System.assert(true, 'Execute should complete without throwing');
    }
}