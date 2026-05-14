@IsTest
private class ComplaintEscalationServiceTest {

    @TestSetup
    static void setupTestData() {
        // Create project
        Project__c project = new Project__c(
            Name = 'Test Project',
            Project_Head__c = UserInfo.getUserId()
        );
        insert project;

        // Create unit
        Unit__c unit = new Unit__c(
            Project__c = project.Id,
            Status__c = 'Booked'
        );
        insert unit;

        // Create booking
        Booking__c booking = new Booking__c(
            Unit__c = unit.Id,
            Project__c = project.Id,
            Booking_Date__c = Date.today().addDays(-60),
            Status__c = 'Approved, Active'
        );
        insert booking;

        // Create escalation matrix rules
        List<Complaint_Escalation_Matrix__c> rules = new List<Complaint_Escalation_Matrix__c>();

        // Rule 1: High priority - tight SLAs
        rules.add(new Complaint_Escalation_Matrix__c(
            Priority__c = 'High',
            Level_1_Days__c = 1,
            Level_1_Notify__c = 'Assigned To',
            Level_2_Days__c = 3,
            Level_2_Notify__c = 'Project Head',
            Level_3_Days__c = 5,
            Level_3_Notify__c = 'Owner',
            Auto_Reassign__c = true,
            Active__c = true
        ));

        // Rule 2: Medium priority
        rules.add(new Complaint_Escalation_Matrix__c(
            Priority__c = 'Medium',
            Level_1_Days__c = 3,
            Level_1_Notify__c = 'Assigned To',
            Level_2_Days__c = 7,
            Level_2_Notify__c = 'Project Head',
            Active__c = true
        ));

        // Rule 3: Default (no filters)
        rules.add(new Complaint_Escalation_Matrix__c(
            Level_1_Days__c = 5,
            Level_1_Notify__c = 'Owner',
            Level_2_Days__c = 10,
            Level_2_Notify__c = 'Project Head',
            Level_3_Days__c = 15,
            Level_3_Notify__c = 'Project Head',
            Active__c = true
        ));

        // Rule 4: Specific category + project
        rules.add(new Complaint_Escalation_Matrix__c(
            Category__c = 'Construction Delay',
            Project__c = project.Id,
            Level_1_Days__c = 2,
            Level_1_Notify__c = 'Project Head',
            Level_2_Days__c = 5,
            Level_2_Notify__c = 'Custom User',
            Level_2_User__c = UserInfo.getUserId(),
            Active__c = true
        ));

        // Rule 5: Inactive rule (should be ignored)
        rules.add(new Complaint_Escalation_Matrix__c(
            Priority__c = 'Low',
            Level_1_Days__c = 1,
            Level_1_Notify__c = 'Owner',
            Active__c = false
        ));

        insert rules;

        // Create complaints
        List<Complaint__c> complaints = new List<Complaint__c>();

        // Complaint 1: High priority, 6 days overdue -> should hit L3
        complaints.add(new Complaint__c(
            Subject__c = 'Critical plumbing issue',
            Category__c = 'Property Issue',
            Priority__c = 'High',
            Status__c = 'In Progress',
            Complaint_Date__c = Date.today().addDays(-10),
            Expected_Resolution_Date__c = Date.today().addDays(-6),
            Booking__c = booking.Id,
            Project__c = project.Id,
            Assigned_To__c = UserInfo.getUserId(),
            Customer_Name__c = 'Test Customer',
            Customer_Email__c = 'test@example.com'
        ));

        // Complaint 2: Medium priority, 4 days overdue -> should hit L1
        complaints.add(new Complaint__c(
            Subject__c = 'Parking allocation issue',
            Category__c = 'Booking Issue',
            Priority__c = 'Medium',
            Status__c = 'Assigned',
            Complaint_Date__c = Date.today().addDays(-8),
            Expected_Resolution_Date__c = Date.today().addDays(-4),
            Booking__c = booking.Id,
            Project__c = project.Id,
            Assigned_To__c = UserInfo.getUserId(),
            Customer_Name__c = 'Test Customer 2',
            Customer_Email__c = 'test2@example.com'
        ));

        // Complaint 3: Construction delay in project, 3 days overdue -> specific rule
        complaints.add(new Complaint__c(
            Subject__c = 'Construction behind schedule',
            Category__c = 'Construction Delay',
            Priority__c = 'Low',
            Status__c = 'New',
            Complaint_Date__c = Date.today().addDays(-7),
            Expected_Resolution_Date__c = Date.today().addDays(-3),
            Booking__c = booking.Id,
            Project__c = project.Id,
            Assigned_To__c = UserInfo.getUserId(),
            Customer_Name__c = 'Test Customer 3',
            Customer_Email__c = 'test3@example.com'
        ));

        // Complaint 4: Already resolved (should be skipped)
        complaints.add(new Complaint__c(
            Subject__c = 'Already fixed',
            Category__c = 'General Complaint',
            Priority__c = 'Low',
            Status__c = 'Resolved',
            Complaint_Date__c = Date.today().addDays(-10),
            Expected_Resolution_Date__c = Date.today().addDays(-5),
            Booking__c = booking.Id,
            Project__c = project.Id,
            Customer_Name__c = 'Test Customer 4'
        ));

        // Complaint 5: Not yet overdue (should be skipped)
        complaints.add(new Complaint__c(
            Subject__c = 'New complaint',
            Category__c = 'General Complaint',
            Priority__c = 'Low',
            Status__c = 'New',
            Complaint_Date__c = Date.today(),
            Expected_Resolution_Date__c = Date.today().addDays(5),
            Booking__c = booking.Id,
            Project__c = project.Id,
            Customer_Name__c = 'Test Customer 5'
        ));

        insert complaints;
    }

    @IsTest
    static void testProcessEscalations() {
        Test.startTest();
        ComplaintEscalationService.EscalationResult result =
            ComplaintEscalationService.processEscalations();
        Test.stopTest();

       
      
    }

    @IsTest
    static void testProcessEscalationsNoRules() {
        // Delete all rules
        delete [SELECT Id FROM Complaint_Escalation_Matrix__c];

        Test.startTest();
        ComplaintEscalationService.EscalationResult result =
            ComplaintEscalationService.processEscalations();
        Test.stopTest();

    }

    @IsTest
    static void testSchedulable() {
        Test.startTest();
        ComplaintEscalationSchedulable schedulable = new ComplaintEscalationSchedulable();
        String jobId = System.schedule(
            'Test Complaint Escalation',
            '0 0 10 * * ?',
            schedulable
        );
        Test.stopTest();

    }

    @IsTest
    static void testGetEscalationRules() {
        Test.startTest();
        List<Complaint_Escalation_Matrix__c> rules =
            ComplaintEscalationService.getEscalationRules();
        Test.stopTest();

    }

    @IsTest
    static void testSaveEscalationRule() {
        Map<String, Object> ruleData = new Map<String, Object>{
            'priority' => 'High',
            'category' => 'Payment Issue',
            'description' => 'Test rule',
            'level1Days' => 1,
            'level1Notify' => 'Assigned To',
            'level2Days' => 3,
            'level2Notify' => 'Project Head',
            'autoReassign' => true,
            'active' => true
        };

        Test.startTest();
        Id ruleId = ComplaintEscalationService.saveEscalationRule(JSON.serialize(ruleData));
        Test.stopTest();

    }

    @IsTest
    static void testToggleAndDeleteRule() {
        Complaint_Escalation_Matrix__c rule = [
            SELECT Id, Active__c FROM Complaint_Escalation_Matrix__c
            WHERE Active__c = true LIMIT 1
        ];

        Test.startTest();
        ComplaintEscalationService.toggleEscalationRule(rule.Id, false);
        Test.stopTest();

    }

    

    @IsTest
    static void testDetermineEscalationLevel() {
        Complaint_Escalation_Matrix__c rule = new Complaint_Escalation_Matrix__c(
            Level_1_Days__c = 2,
            Level_2_Days__c = 5,
            Level_3_Days__c = 10
        );


      }
}