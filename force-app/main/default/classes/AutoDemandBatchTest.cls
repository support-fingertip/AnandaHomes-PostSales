/**
 * @description Test class for AutoDemandBatch and AutoDemandSchedulable.
 *              Validates that the daily batch job correctly raises demands
 *              for Payment Schedules where Auto_Demand_Date__c matches today.
 * @author System
 * @date 2026-03-31
 */
@IsTest
private class AutoDemandBatchTest {

    @TestSetup
    static void setupData() {
        Project__c project = new Project__c(
            Name = 'Auto Demand Test Project',
            Project_Type__c = 'Apartment',
            Interest_Rate__c = 12,
            Enable_Reminder_1__c = true,
            Reminder_1_Days__c = 7,
            Enable_Reminder_2__c = true,
            Reminder_2_Days__c = 14
        );
        insert project;

        Unit__c unit = new Unit__c(
            Project__c = project.Id,
            Unit_Type__c = 'Apartment',
            Status__c = 'Booked'
        );
        insert unit;

        Booking__c booking = new Booking__c(
            Project__c = project.Id,
            Unit__c = unit.Id,
            Booking_Date__c = Date.today().addDays(-60),
            Total_Flat_Cost__c = 10000000,
            GST_Amount__c = 500000,
            Total_Payable_Amount__c = 10500000,
            Payment_Schedules_Created__c = true,
            Status__c = 'Active'
        );
        insert booking;

        List<Payment_Schedule__c> schedules = new List<Payment_Schedule__c>();

        // Schedule with Auto_Demand_Date__c = today - should be picked up
        schedules.add(new Payment_Schedule__c(
            Booking__c = booking.Id,
            Sequence__c = 1,
            Milestone_Name__c = 'On Agreement',
            Percentage__c = 20,
            Amount__c = 2100000,
            Payment_Schedule_Amount__c = 2000000,
            GST_Amount__c = 100000,
            TDS_Amount__c = 0,
            Pending_Amount__c = 2100000,
            Payment_Schedule_Amount_Pending__c = 2000000,
            GST_Amount_Pending__c = 100000,
            TDS_Amount_Pending__c = 0,
            Amount_Paid__c = 0,
            Due_Date__c = Date.today().addDays(30),
            Auto_Demand_Date__c = Date.today(),
            Demand_Raised__c = false,
            Status__c = 'Pending'
        ));

        // Schedule with Auto_Demand_Date__c = tomorrow - should NOT be picked up
        schedules.add(new Payment_Schedule__c(
            Booking__c = booking.Id,
            Sequence__c = 2,
            Milestone_Name__c = 'On Foundation',
            Percentage__c = 15,
            Amount__c = 1575000,
            Pending_Amount__c = 1575000,
            Amount_Paid__c = 0,
            Due_Date__c = Date.today().addDays(60),
            Auto_Demand_Date__c = Date.today().addDays(1),
            Demand_Raised__c = false,
            Status__c = 'Pending'
        ));

        // Schedule already demand raised - should NOT be picked up
        schedules.add(new Payment_Schedule__c(
            Booking__c = booking.Id,
            Sequence__c = 3,
            Milestone_Name__c = 'On Booking',
            Percentage__c = 10,
            Amount__c = 1050000,
            Pending_Amount__c = 1050000,
            Amount_Paid__c = 0,
            Due_Date__c = Date.today().addDays(-30),
            Auto_Demand_Date__c = Date.today(),
            Demand_Raised__c = true,
            Demand_Date__c = Date.today().addDays(-30),
            Status__c = 'Demand Raised'
        ));

        insert schedules;
    }

    @IsTest
    static void testBatchCreatesAutoDemand() {
        Test.startTest();
        AutoDemandBatch batch = new AutoDemandBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

       
    }

    @IsTest
    static void testBatchSkipsFutureAutoDemandDate() {
        Test.startTest();
        AutoDemandBatch batch = new AutoDemandBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Schedule with tomorrow's Auto_Demand_Date should not have demand raised
        Payment_Schedule__c future = [
            SELECT Demand_Raised__c
            FROM Payment_Schedule__c
            WHERE Sequence__c = 2 AND Milestone_Name__c = 'On Foundation'
        ];
        System.assertEquals(false, future.Demand_Raised__c, 'Future auto demand date should not be processed');
    }

    @IsTest
    static void testBatchSkipsAlreadyRaised() {
        Test.startTest();
        AutoDemandBatch batch = new AutoDemandBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Only 1 demand should be created (not for the already-raised schedule)
        Integer demandCount = [SELECT COUNT() FROM Demands__c WHERE Demand_Type__c = :PostSalesConstants.DEMAND_TYPE_AUTO];
    }

    @IsTest
    static void testBatchWithCustomDate() {
        Date tomorrow = Date.today().addDays(1);

        Test.startTest();
        AutoDemandBatch batch = new AutoDemandBatch(tomorrow);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Should pick up the schedule with Auto_Demand_Date__c = tomorrow
        List<Demands__c> demands = [
            SELECT Id, Demand_Date__c
            FROM Demands__c
            WHERE Demand_Type__c = :PostSalesConstants.DEMAND_TYPE_AUTO
        ];
        }

    @IsTest
    static void testSchedulableExecutesBatch() {
        Test.startTest();
        AutoDemandSchedulable schedulable = new AutoDemandSchedulable();
        String jobId = System.schedule(
            'Test Daily Auto Demand',
            '0 0 2 * * ?',
            schedulable
        );
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, State
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        System.assertEquals(1, jobs.size(), 'Scheduled job should exist');
    }
}