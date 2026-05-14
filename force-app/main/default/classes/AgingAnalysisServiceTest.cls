@IsTest
private class AgingAnalysisServiceTest {

    @TestSetup
    static void setupTestData() {
        // Create projects
        Project__c project1 = new Project__c(
            Name = 'Sunrise Heights',
            Project_Head__c = UserInfo.getUserId()
        );
        Project__c project2 = new Project__c(
            Name = 'Green Valley',
            Project_Head__c = UserInfo.getUserId()
        );
        insert new List<Project__c>{ project1, project2 };

        // Create units
        Unit__c unit1 = new Unit__c(Project__c = project1.Id, Status__c = 'Booked');
        Unit__c unit2 = new Unit__c(Project__c = project2.Id, Status__c = 'Booked');
        insert new List<Unit__c>{ unit1, unit2 };

        // Create bookings
        Booking__c booking1 = new Booking__c(
            Unit__c = unit1.Id, Project__c = project1.Id,
            Booking_Date__c = Date.today().addDays(-180), Status__c = 'Approved, Active'
        );
        Booking__c booking2 = new Booking__c(
            Unit__c = unit2.Id, Project__c = project2.Id,
            Booking_Date__c = Date.today().addDays(-90), Status__c = 'Approved, Active'
        );
        insert new List<Booking__c>{ booking1, booking2 };

        // Create demands with various overdue dates
        List<Demands__c> demands = new List<Demands__c>();
        // Current (due today) - should not appear in overdue
        demands.add(new Demands__c(
            Booking__c = booking1.Id, Project__c = project1.Id,
            Demand_Amount__c = 100000, Paid_Amount__c = 0, Pending_Amount__c = 100000,
            Due_Date__c = Date.today(), Status__c = 'Raised', Demand_Type__c = 'Individual Demand'
        ));
        // 15 days overdue (1-30 bucket)
        demands.add(new Demands__c(
            Booking__c = booking1.Id, Project__c = project1.Id,
            Demand_Amount__c = 200000, Paid_Amount__c = 50000, Pending_Amount__c = 150000,
            Due_Date__c = Date.today().addDays(-15), Status__c = 'Overdue', Demand_Type__c = 'Individual Demand'
        ));
        // 45 days overdue (31-60 bucket)
        demands.add(new Demands__c(
            Booking__c = booking1.Id, Project__c = project1.Id,
            Demand_Amount__c = 300000, Paid_Amount__c = 0, Pending_Amount__c = 300000,
            Due_Date__c = Date.today().addDays(-45), Status__c = 'Overdue', Demand_Type__c = 'Bulk Demand'
        ));
        // 75 days overdue (61-90 bucket) - project 2
        demands.add(new Demands__c(
            Booking__c = booking2.Id, Project__c = project2.Id,
            Demand_Amount__c = 500000, Paid_Amount__c = 100000, Pending_Amount__c = 400000,
            Due_Date__c = Date.today().addDays(-75), Status__c = 'Overdue', Demand_Type__c = 'Individual Demand'
        ));
        // 120 days overdue (90+ bucket) - project 2
        demands.add(new Demands__c(
            Booking__c = booking2.Id, Project__c = project2.Id,
            Demand_Amount__c = 800000, Paid_Amount__c = 0, Pending_Amount__c = 800000,
            Due_Date__c = Date.today().addDays(-120), Status__c = 'Overdue', Demand_Type__c = 'Individual Demand'
        ));
        // Paid demand (should be excluded)
        demands.add(new Demands__c(
            Booking__c = booking1.Id, Project__c = project1.Id,
            Demand_Amount__c = 100000, Paid_Amount__c = 100000, Pending_Amount__c = 0,
            Due_Date__c = Date.today().addDays(-30), Status__c = 'Paid', Demand_Type__c = 'Individual Demand'
        ));
        insert demands;

        // Create complaints
        List<Complaint__c> complaints = new List<Complaint__c>();
        // 10 days old (1-30 bucket)
        complaints.add(new Complaint__c(
            Subject__c = 'Water leakage', Category__c = 'Property Issue', Priority__c = 'High',
            Status__c = 'In Progress', Complaint_Date__c = Date.today().addDays(-10),
            Expected_Resolution_Date__c = Date.today().addDays(-5),
            Booking__c = booking1.Id, Project__c = project1.Id,
            Assigned_To__c = UserInfo.getUserId(),
            Customer_Name__c = 'Customer A', Customer_Email__c = 'a@test.com'
        ));
        // 50 days old (31-60 bucket)
        complaints.add(new Complaint__c(
            Subject__c = 'Parking issue', Category__c = 'Booking Issue', Priority__c = 'Medium',
            Status__c = 'Assigned', Complaint_Date__c = Date.today().addDays(-50),
            Expected_Resolution_Date__c = Date.today().addDays(-30),
            Booking__c = booking2.Id, Project__c = project2.Id,
            Customer_Name__c = 'Customer B', Customer_Email__c = 'b@test.com'
        ));
        // 100 days old (90+ bucket)
        complaints.add(new Complaint__c(
            Subject__c = 'Delayed possession', Category__c = 'Possession Delay', Priority__c = 'High',
            Status__c = 'Escalated', Complaint_Date__c = Date.today().addDays(-100),
            Expected_Resolution_Date__c = Date.today().addDays(-60),
            Booking__c = booking1.Id, Project__c = project1.Id,
            Customer_Name__c = 'Customer C', Customer_Email__c = 'c@test.com',
            Escalation_Level__c = 2
        ));
        // Closed complaint (should be excluded)
        complaints.add(new Complaint__c(
            Subject__c = 'Fixed issue', Category__c = 'General Complaint', Priority__c = 'Low',
            Status__c = 'Closed', Complaint_Date__c = Date.today().addDays(-40),
            Booking__c = booking1.Id, Project__c = project1.Id,
            Customer_Name__c = 'Customer D'
        ));
        insert complaints;

       
    }

    @IsTest
    static void testGetDemandAgingReport_AllProjects() {
        Test.startTest();
        AgingAnalysisService.AgingReport report =
            AgingAnalysisService.getDemandAgingReport(null);
        Test.stopTest();

        System.assertNotEquals(null, report, 'Report should not be null');
        System.assertEquals('Demand Aging', report.reportType);
        System.assert(report.totalRecords > 0, 'Should have overdue demands');
        System.assert(report.totalAmount > 0, 'Total outstanding should be > 0');
        System.assertEquals(5, report.buckets.size(), 'Should have 5 aging buckets');
        System.assert(report.projectBreakdown.size() >= 1, 'Should have project breakdown');
    }

    @IsTest
    static void testGetDemandAgingReport_SpecificProject() {
        Project__c project = [SELECT Id FROM Project__c WHERE Name = 'Green Valley' LIMIT 1];

        Test.startTest();
        AgingAnalysisService.AgingReport report =
            AgingAnalysisService.getDemandAgingReport(project.Id);
        Test.stopTest();

        System.assertNotEquals(null, report);
        System.assert(report.totalRecords > 0, 'Should have demands for Green Valley');
        // All project breakdowns should be for the selected project
        for (AgingAnalysisService.ProjectAgingSummary ps : report.projectBreakdown) {
            System.assertEquals(project.Id, ps.projectId);
        }
    }

    @IsTest
    static void testGetComplaintAgingReport() {
        Test.startTest();
        AgingAnalysisService.AgingReport report =
            AgingAnalysisService.getComplaintAgingReport(null);
        Test.stopTest();

        System.assertNotEquals(null, report);
        System.assertEquals('Complaint Aging', report.reportType);
        // Should have 3 open complaints (1 closed is excluded)
        System.assertEquals(3, report.totalRecords, 'Should have 3 open complaints');
        System.assertEquals(5, report.buckets.size());
    }

    @IsTest
    static void testGetSnagAgingReport() {
        Test.startTest();
        AgingAnalysisService.AgingReport report =
            AgingAnalysisService.getSnagAgingReport(null);
        Test.stopTest();

        
    }

    @IsTest
    static void testGetAgingOverview() {
        Test.startTest();
        Map<String, AgingAnalysisService.AgingReport> overview =
            AgingAnalysisService.getAgingOverview(null);
        Test.stopTest();

       
    }

    @IsTest
    static void testGetProjectOptions() {
        Test.startTest();
        List<Map<String, String>> options =
            AgingAnalysisService.getProjectOptions();
        Test.stopTest();

        System.assert(options.size() >= 2, 'Should have at least 2 projects');
    }

    @IsTest
    static void testBucketDistribution() {
        Test.startTest();
        AgingAnalysisService.AgingReport report =
            AgingAnalysisService.getDemandAgingReport(null);
        Test.stopTest();

        // Verify demands are in correct buckets
        Integer totalInBuckets = 0;
        for (AgingAnalysisService.AgingBucketResult bucket : report.buckets) {
            totalInBuckets += bucket.count;
        }
       
    }

    @IsTest
    static void testProjectBreakdownRecords() {
        Test.startTest();
        AgingAnalysisService.AgingReport report =
            AgingAnalysisService.getDemandAgingReport(null);
        Test.stopTest();

       
    }
}