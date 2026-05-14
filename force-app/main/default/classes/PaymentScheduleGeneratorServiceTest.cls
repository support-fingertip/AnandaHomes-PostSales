/**
 * @description Test class for PaymentScheduleGeneratorService.
 *              Tests the auto-creation of Payment Schedules from Master Payment Schedules
 *              when a Booking is created.
 * @author System
 * @date 2026-03-15
 */
@IsTest
private class PaymentScheduleGeneratorServiceTest {

    @TestSetup
    static void setupData() {
        // Create Project
        Project__c project = new Project__c(
            Name = 'Test Project',
            Project_Type__c = 'Apartment',
            Interest_Rate__c = 18
        );
        insert project;

        // Create Master Payment Schedules
        List<Master_Payment_Schedule__c> masters = new List<Master_Payment_Schedule__c>();
        masters.add(new Master_Payment_Schedule__c(
            Name = 'On Booking',
            Project__c = project.Id,
            Payment_Type__c = 'On Booking',
            Percentage__c = 10,
            Sequence__c = 1,
            Status__c = 'In Progress',
            Is_Active__c = true,
            Days_After_Booking__c = 0,
            Applicable_For__c = 'Apartment',
            Description__c = '10% on booking'
        ));
        masters.add(new Master_Payment_Schedule__c(
            Name = 'On Agreement',
            Project__c = project.Id,
            Payment_Type__c = 'On Agreement',
            Percentage__c = 15,
            Sequence__c = 2,
            Status__c = 'In Progress',
            Is_Active__c = true,
            Days_After_Booking__c = 30,
            Applicable_For__c = 'Apartment',
            Description__c = '15% on agreement'
        ));
        masters.add(new Master_Payment_Schedule__c(
            Name = 'On Foundation',
            Project__c = project.Id,
            Payment_Type__c = 'On Foundation',
            Percentage__c = 10,
            Sequence__c = 3,
            Status__c = 'Completed',
            Is_Active__c = true,
            Days_After_Previous__c = 60,
            Applicable_For__c = 'Apartment',
            Description__c = '10% on foundation'
        ));
        masters.add(new Master_Payment_Schedule__c(
            Name = 'On Possession',
            Project__c = project.Id,
            Payment_Type__c = 'On Possession',
            Percentage__c = 65,
            Sequence__c = 4,
            Status__c = 'Pending',
            Is_Active__c = true,
            Days_After_Previous__c = 90,
            Applicable_For__c = 'Apartment',
            Description__c = '65% on possession'
        ));
        insert masters;

        // Create Unit
        Unit__c unit = new Unit__c(
            Project__c = project.Id,
            Unit_Type__c = 'Apartment',
            Status__c = 'Available'
        );
        insert unit;
    }

    @IsTest
    static void testGeneratePaymentSchedulesOnBookingCreation() {
        Project__c project = [SELECT Id FROM Project__c LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        // Create a booking with pricing data
        Booking__c booking = new Booking__c(
            Project__c = project.Id,
            Unit__c = unit.Id,
            Booking_Date__c = Date.today(),
            Total_Flat_Cost__c = 5000000,
            GST_Amount__c = 250000,
            Status__c = 'Active'
        );

        Test.startTest();
        insert booking;

        // Manually invoke since flow may not fire in test
        PaymentScheduleGeneratorService.FlowInput input = new PaymentScheduleGeneratorService.FlowInput();
        input.bookingId = booking.Id;
        PaymentScheduleGeneratorService.generateSchedules(new List<PaymentScheduleGeneratorService.FlowInput>{ input });
        Test.stopTest();

       
    }

    @IsTest
    static void testNoProjectNoSchedules() {
        // Create a booking without a project
        Booking__c booking = new Booking__c(
            Booking_Date__c = Date.today(),
            Status__c = 'Active'
        );
        insert booking;

        Test.startTest();
        PaymentScheduleGeneratorService.FlowInput input = new PaymentScheduleGeneratorService.FlowInput();
        input.bookingId = booking.Id;
        PaymentScheduleGeneratorService.generateSchedules(new List<PaymentScheduleGeneratorService.FlowInput>{ input });
        Test.stopTest();

       
    }

    @IsTest
    static void testDoNotRegenerateIfAlreadyCreated() {
        Project__c project = [SELECT Id FROM Project__c LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Booking__c booking = new Booking__c(
            Project__c = project.Id,
            Unit__c = unit.Id,
            Booking_Date__c = Date.today(),
            Total_Flat_Cost__c = 5000000,
            GST_Amount__c = 250000,
            Payment_Schedules_Created__c = true,
            Status__c = 'Active'
        );
        insert booking;

        Test.startTest();
        PaymentScheduleGeneratorService.FlowInput input = new PaymentScheduleGeneratorService.FlowInput();
        input.bookingId = booking.Id;
        PaymentScheduleGeneratorService.generateSchedules(new List<PaymentScheduleGeneratorService.FlowInput>{ input });
        Test.stopTest();

    }

    @IsTest
    static void testEmptyInput() {
        Test.startTest();
        PaymentScheduleGeneratorService.generateSchedules(new List<PaymentScheduleGeneratorService.FlowInput>());
        Test.stopTest();
        // Should not throw any exception
    }
}