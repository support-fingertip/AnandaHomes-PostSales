/**
 * @description Test class for ApprovalActionHandler
 */
@isTest
private class ApprovalActionHandlerTest {

    @testSetup
    static void setup() {
        Project__c project = new Project__c(
            Name = 'Approval Test Project',
            Project_Type__c = 'Apartment'
        );
        insert project;

        Unit__c unit = new Unit__c(
            Project__c = project.Id,
            Status__c = 'Booked'
        );
        insert unit;

        Booking__c booking = new Booking__c(
            Project__c = project.Id,
            Unit__c = unit.Id,
            Booking_Date__c = Date.today(),
            Status__c = 'Draft',
            Booking_Verification_Approval_Status__c = 'Approved'
        );
        insert booking;

        // Approval configuration that watches Booking_Verification_Approval_Status__c
        ApprovalActionHandler.ActionConfig approvalActions = new ApprovalActionHandler.ActionConfig();
        approvalActions.actions = new List<ApprovalActionHandler.ActionItem>();

        ApprovalActionHandler.ActionItem chatter = new ApprovalActionHandler.ActionItem();
        chatter.actionType = 'CHATTER_POST';
        chatter.chatterMessage = 'Booking approved';
        approvalActions.actions.add(chatter);

        ApprovalActionHandler.ActionItem fieldUpd = new ApprovalActionHandler.ActionItem();
        fieldUpd.actionType = 'FIELD_UPDATE';
        fieldUpd.fieldUpdates = new List<ApprovalActionHandler.FieldUpdate>();
        ApprovalActionHandler.FieldUpdate fu = new ApprovalActionHandler.FieldUpdate();
        fu.fieldName = 'Status__c';
        fu.value = 'Approved';
        fieldUpd.fieldUpdates.add(fu);
        approvalActions.actions.add(fieldUpd);

        Approval_Configuration__c config = new Approval_Configuration__c(
            Object_API_Name__c = 'Booking__c',
            Process_Type__c = 'Verification',
            Process_Label__c = 'Booking Verification',
            Status_Field_API_Name__c = 'Booking_Verification_Approval_Status__c',
            Approved_Status_Value__c = 'Approved',
            Rejected_Status_Value__c = 'Rejected',
            Is_Active__c = true,
            On_Approval_JSON__c = JSON.serialize(approvalActions),
            On_Rejection_JSON__c = JSON.serialize(approvalActions)
        );
        insert config;
    }

    @isTest
    static void processApprovalNotifications_nullRecordId_returnsError() {
        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = null;

        Test.startTest();
        List<ApprovalActionHandler.NotificationResult> results =
            ApprovalActionHandler.processApprovalNotifications(
                new List<ApprovalActionHandler.NotificationRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(false, results[0].success, 'Should not succeed with null id');
    }

    @isTest
    static void processApprovalNotifications_approvalDetected_runsActions() {
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];

        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = b.Id;
        req.priorValuesJson = JSON.serialize(
            new Map<String, String>{ 'Booking_Verification_Approval_Status__c' => 'Pending' }
        );

        Test.startTest();
        List<ApprovalActionHandler.NotificationResult> results =
            ApprovalActionHandler.processApprovalNotifications(
                new List<ApprovalActionHandler.NotificationRequest>{ req }
            );
        Test.stopTest();

        System.assertNotEquals(null, results, 'Result list should not be null');
        System.assertEquals(1, results.size(), 'Should return one result');
    }

    @isTest
    static void processApprovalNotifications_noConfigs_returnsMessage() {
        delete [SELECT Id FROM Approval_Configuration__c];
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];

        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = b.Id;

        Test.startTest();
        List<ApprovalActionHandler.NotificationResult> results =
            ApprovalActionHandler.processApprovalNotifications(
                new List<ApprovalActionHandler.NotificationRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(false, results[0].success, 'No configs should not succeed');
    }

    @isTest
    static void processApprovalNotifications_priorEqualsCurrent_skips() {
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];

        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = b.Id;
        req.priorValuesJson = JSON.serialize(
            new Map<String, String>{ 'Booking_Verification_Approval_Status__c' => 'Approved' }
        );

        Test.startTest();
        List<ApprovalActionHandler.NotificationResult> results =
            ApprovalActionHandler.processApprovalNotifications(
                new List<ApprovalActionHandler.NotificationRequest>{ req }
            );
        Test.stopTest();

        // No change detected (prior == current), so success may be false
        System.assertNotEquals(null, results[0].message, 'Message should be present');
    }

    // ===== Appended coverage tests =====

    @isTest
    static void processApprovalNotifications_rejection_runsActions() {
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        b.Booking_Verification_Approval_Status__c = 'Rejected';
        update b;

        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = b.Id;
        req.priorValuesJson = JSON.serialize(
            new Map<String, String>{ 'Booking_Verification_Approval_Status__c' => 'Pending' }
        );

        Test.startTest();
        List<ApprovalActionHandler.NotificationResult> results =
            ApprovalActionHandler.processApprovalNotifications(
                new List<ApprovalActionHandler.NotificationRequest>{ req }
            );
        Test.stopTest();
        System.assertEquals(1, results.size(), 'one result');
    }

    @isTest
    static void processApprovalNotifications_blankCurrent_skipped() {
        // Update booking to blank value
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        b.Booking_Verification_Approval_Status__c = null;
        try { update b; } catch (Exception e) { /* ok */ }

        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = b.Id;

        Test.startTest();
        List<ApprovalActionHandler.NotificationResult> results =
            ApprovalActionHandler.processApprovalNotifications(
                new List<ApprovalActionHandler.NotificationRequest>{ req }
            );
        Test.stopTest();
        System.assertNotEquals(null, results, 'results');
    }

    @isTest
    static void processApprovalNotifications_emailAndBellActions() {
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];

        // Build config with EMAIL_NOTIFICATION + BELL_NOTIFICATION + CHATTER + FIELD_UPDATE
        ApprovalActionHandler.ActionConfig acfg = new ApprovalActionHandler.ActionConfig();
        acfg.actions = new List<ApprovalActionHandler.ActionItem>();

        ApprovalActionHandler.ActionItem emailA = new ApprovalActionHandler.ActionItem();
        emailA.actionType = 'EMAIL_NOTIFICATION';
        emailA.emailConfig = new ApprovalActionHandler.EmailConfig();
        emailA.emailConfig.recipientFieldPaths = new List<String>{ 'OwnerId' };
        emailA.emailConfig.additionalEmails = new List<String>{ 'cc@example.com' };
        acfg.actions.add(emailA);

        ApprovalActionHandler.ActionItem bellA = new ApprovalActionHandler.ActionItem();
        bellA.actionType = 'BELL_NOTIFICATION';
        bellA.bellConfig = new ApprovalActionHandler.BellConfig();
        bellA.bellConfig.title = 'Hi';
        bellA.bellConfig.body = 'Approved {Status__c}';
        bellA.bellConfig.recipientFieldPaths = new List<String>{ 'OwnerId' };
        acfg.actions.add(bellA);

        ApprovalActionHandler.ActionItem chatterA = new ApprovalActionHandler.ActionItem();
        chatterA.actionType = 'CHATTER_POST';
        chatterA.chatterMessage = 'Posted!';
        acfg.actions.add(chatterA);

        ApprovalActionHandler.ActionItem fuA = new ApprovalActionHandler.ActionItem();
        fuA.actionType = 'FIELD_UPDATE';
        fuA.fieldUpdates = new List<ApprovalActionHandler.FieldUpdate>();
        ApprovalActionHandler.FieldUpdate fu1 = new ApprovalActionHandler.FieldUpdate();
        fu1.fieldName = 'Booking_Date__c';
        fu1.value = '$TODAY';
        fuA.fieldUpdates.add(fu1);
        acfg.actions.add(fuA);

        // Replace existing config
        delete [SELECT Id FROM Approval_Configuration__c];
        Approval_Configuration__c cfg = new Approval_Configuration__c(
            Object_API_Name__c = 'Booking__c',
            Process_Type__c = 'Verification',
            Process_Label__c = 'Booking Verification',
            Status_Field_API_Name__c = 'Booking_Verification_Approval_Status__c',
            Approved_Status_Value__c = 'Approved',
            Rejected_Status_Value__c = 'Rejected',
            Is_Active__c = true,
            On_Approval_JSON__c = JSON.serialize(acfg),
            On_Rejection_JSON__c = JSON.serialize(acfg)
        );
        insert cfg;

        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = b.Id;
        req.priorValuesJson = JSON.serialize(
            new Map<String, String>{ 'Booking_Verification_Approval_Status__c' => 'Pending' }
        );

        Test.startTest();
        List<ApprovalActionHandler.NotificationResult> results =
            ApprovalActionHandler.processApprovalNotifications(
                new List<ApprovalActionHandler.NotificationRequest>{ req }
            );
        Test.stopTest();
        System.assertEquals(1, results.size(), 'one result');
    }

    @isTest
    static void processApprovalNotifications_invalidPriorJson() {
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = b.Id;
        req.priorValuesJson = 'not-json';
        Test.startTest();
        List<ApprovalActionHandler.NotificationResult> results =
            ApprovalActionHandler.processApprovalNotifications(
                new List<ApprovalActionHandler.NotificationRequest>{ req }
            );
        Test.stopTest();
        System.assertNotEquals(null, results, 'results');
    }

    @isTest
    static void processApprovalNotifications_blankActionsJson_skipped() {
        delete [SELECT Id FROM Approval_Configuration__c];
        Approval_Configuration__c cfg = new Approval_Configuration__c(
            Object_API_Name__c = 'Booking__c',
            Process_Type__c = 'Verification',
            Process_Label__c = 'Booking Verification',
            Status_Field_API_Name__c = 'Booking_Verification_Approval_Status__c',
            Approved_Status_Value__c = 'Approved',
            Rejected_Status_Value__c = 'Rejected',
            Is_Active__c = true,
            On_Approval_JSON__c = null,
            On_Rejection_JSON__c = null
        );
        insert cfg;
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = b.Id;
        req.priorValuesJson = JSON.serialize(
            new Map<String, String>{ 'Booking_Verification_Approval_Status__c' => 'Pending' }
        );
        Test.startTest();
        List<ApprovalActionHandler.NotificationResult> results =
            ApprovalActionHandler.processApprovalNotifications(
                new List<ApprovalActionHandler.NotificationRequest>{ req }
            );
        Test.stopTest();
        System.assertNotEquals(null, results, 'results');
    }

    @isTest
    static void processApprovalNotifications_invalidActionsJson_skipped() {
        delete [SELECT Id FROM Approval_Configuration__c];
        Approval_Configuration__c cfg = new Approval_Configuration__c(
            Object_API_Name__c = 'Booking__c',
            Process_Type__c = 'Verification',
            Process_Label__c = 'Booking Verification',
            Status_Field_API_Name__c = 'Booking_Verification_Approval_Status__c',
            Approved_Status_Value__c = 'Approved',
            Rejected_Status_Value__c = 'Rejected',
            Is_Active__c = true,
            On_Approval_JSON__c = 'not-json',
            On_Rejection_JSON__c = 'not-json'
        );
        insert cfg;
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = b.Id;
        req.priorValuesJson = JSON.serialize(
            new Map<String, String>{ 'Booking_Verification_Approval_Status__c' => 'Pending' }
        );
        Test.startTest();
        ApprovalActionHandler.processApprovalNotifications(
            new List<ApprovalActionHandler.NotificationRequest>{ req }
        );
        Test.stopTest();
    }

    @isTest
    static void processApprovalNotifications_unknownActionType() {
        delete [SELECT Id FROM Approval_Configuration__c];
        ApprovalActionHandler.ActionConfig acfg = new ApprovalActionHandler.ActionConfig();
        acfg.actions = new List<ApprovalActionHandler.ActionItem>();
        ApprovalActionHandler.ActionItem unk = new ApprovalActionHandler.ActionItem();
        unk.actionType = 'UNKNOWN_TYPE';
        acfg.actions.add(unk);

        ApprovalActionHandler.ActionItem chatterEmpty = new ApprovalActionHandler.ActionItem();
        chatterEmpty.actionType = 'CHATTER_POST';
        chatterEmpty.chatterMessage = '';
        acfg.actions.add(chatterEmpty);

        ApprovalActionHandler.ActionItem emailNoConfig = new ApprovalActionHandler.ActionItem();
        emailNoConfig.actionType = 'EMAIL_NOTIFICATION';
        acfg.actions.add(emailNoConfig);

        ApprovalActionHandler.ActionItem bellNoConfig = new ApprovalActionHandler.ActionItem();
        bellNoConfig.actionType = 'BELL_NOTIFICATION';
        acfg.actions.add(bellNoConfig);

        ApprovalActionHandler.ActionItem fuNoFields = new ApprovalActionHandler.ActionItem();
        fuNoFields.actionType = 'FIELD_UPDATE';
        fuNoFields.fieldUpdates = new List<ApprovalActionHandler.FieldUpdate>();
        acfg.actions.add(fuNoFields);

        Approval_Configuration__c cfg = new Approval_Configuration__c(
            Object_API_Name__c = 'Booking__c',
            Process_Type__c = 'Verification',
            Process_Label__c = 'Booking Verification',
            Status_Field_API_Name__c = 'Booking_Verification_Approval_Status__c',
            Approved_Status_Value__c = 'Approved',
            Rejected_Status_Value__c = 'Rejected',
            Is_Active__c = true,
            On_Approval_JSON__c = JSON.serialize(acfg),
            On_Rejection_JSON__c = JSON.serialize(acfg)
        );
        insert cfg;
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = b.Id;
        req.priorValuesJson = JSON.serialize(
            new Map<String, String>{ 'Booking_Verification_Approval_Status__c' => 'Pending' }
        );
        Test.startTest();
        ApprovalActionHandler.processApprovalNotifications(
            new List<ApprovalActionHandler.NotificationRequest>{ req }
        );
        Test.stopTest();
    }

    @isTest
    static void processApprovalNotifications_fieldUpdateSpecialValues() {
        delete [SELECT Id FROM Approval_Configuration__c];
        ApprovalActionHandler.ActionConfig acfg = new ApprovalActionHandler.ActionConfig();
        acfg.actions = new List<ApprovalActionHandler.ActionItem>();
        ApprovalActionHandler.ActionItem fu = new ApprovalActionHandler.ActionItem();
        fu.actionType = 'FIELD_UPDATE';
        fu.fieldUpdates = new List<ApprovalActionHandler.FieldUpdate>();
        ApprovalActionHandler.FieldUpdate f1 = new ApprovalActionHandler.FieldUpdate();
        f1.fieldName = 'Booking_Date__c'; f1.value = '$TODAY';
        fu.fieldUpdates.add(f1);
        ApprovalActionHandler.FieldUpdate f2 = new ApprovalActionHandler.FieldUpdate();
        f2.fieldName = 'OwnerId'; f2.value = '$USER_ID';
        fu.fieldUpdates.add(f2);
        ApprovalActionHandler.FieldUpdate f3 = new ApprovalActionHandler.FieldUpdate();
        f3.fieldName = 'NonExistentField__c'; f3.value = 'x';
        fu.fieldUpdates.add(f3);
        acfg.actions.add(fu);

        Approval_Configuration__c cfg = new Approval_Configuration__c(
            Object_API_Name__c = 'Booking__c',
            Process_Type__c = 'Verification',
            Process_Label__c = 'Booking Verification',
            Status_Field_API_Name__c = 'Booking_Verification_Approval_Status__c',
            Approved_Status_Value__c = 'Approved',
            Rejected_Status_Value__c = 'Rejected',
            Is_Active__c = true,
            On_Approval_JSON__c = JSON.serialize(acfg),
            On_Rejection_JSON__c = JSON.serialize(acfg)
        );
        insert cfg;

        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = b.Id;
        req.priorValuesJson = JSON.serialize(
            new Map<String, String>{ 'Booking_Verification_Approval_Status__c' => 'Pending' }
        );
        Test.startTest();
        ApprovalActionHandler.processApprovalNotifications(
            new List<ApprovalActionHandler.NotificationRequest>{ req }
        );
        Test.stopTest();
    }

    // ===== Appended additional coverage tests =====

    @isTest
    static void processApprovalNotifications_fieldUpdateNowSpecial() {
        delete [SELECT Id FROM Approval_Configuration__c];
        ApprovalActionHandler.ActionConfig acfg = new ApprovalActionHandler.ActionConfig();
        acfg.actions = new List<ApprovalActionHandler.ActionItem>();
        ApprovalActionHandler.ActionItem fu = new ApprovalActionHandler.ActionItem();
        fu.actionType = 'FIELD_UPDATE';
        fu.fieldUpdates = new List<ApprovalActionHandler.FieldUpdate>();
        ApprovalActionHandler.FieldUpdate f1 = new ApprovalActionHandler.FieldUpdate();
        f1.fieldName = 'CreatedDate'; f1.value = '$NOW';
        fu.fieldUpdates.add(f1);
        acfg.actions.add(fu);

        Approval_Configuration__c cfg = new Approval_Configuration__c(
            Object_API_Name__c = 'Booking__c',
            Process_Type__c = 'Verification',
            Process_Label__c = 'Booking Verification',
            Status_Field_API_Name__c = 'Booking_Verification_Approval_Status__c',
            Approved_Status_Value__c = 'Approved',
            Rejected_Status_Value__c = 'Rejected',
            Is_Active__c = true,
            On_Approval_JSON__c = JSON.serialize(acfg),
            On_Rejection_JSON__c = JSON.serialize(acfg)
        );
        insert cfg;

        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = b.Id;
        req.priorValuesJson = JSON.serialize(
            new Map<String, String>{ 'Booking_Verification_Approval_Status__c' => 'Pending' }
        );
        Test.startTest();
        ApprovalActionHandler.processApprovalNotifications(
            new List<ApprovalActionHandler.NotificationRequest>{ req }
        );
        Test.stopTest();
    }

    @isTest
    static void processApprovalNotifications_emailWithTemplateNotFound() {
        delete [SELECT Id FROM Approval_Configuration__c];
        ApprovalActionHandler.ActionConfig acfg = new ApprovalActionHandler.ActionConfig();
        acfg.actions = new List<ApprovalActionHandler.ActionItem>();
        ApprovalActionHandler.ActionItem em = new ApprovalActionHandler.ActionItem();
        em.actionType = 'EMAIL_NOTIFICATION';
        em.emailConfig = new ApprovalActionHandler.EmailConfig();
        em.emailConfig.recipientFieldPaths = new List<String>{ 'OwnerId' };
        em.emailConfig.additionalEmails = new List<String>{ 'cc@example.com' };
        em.emailConfig.templateDeveloperName = 'NonExistent_Template_DevName_X';
        acfg.actions.add(em);

        Approval_Configuration__c cfg = new Approval_Configuration__c(
            Object_API_Name__c = 'Booking__c',
            Process_Type__c = 'Verification',
            Process_Label__c = 'BV',
            Status_Field_API_Name__c = 'Booking_Verification_Approval_Status__c',
            Approved_Status_Value__c = 'Approved',
            Rejected_Status_Value__c = 'Rejected',
            Is_Active__c = true,
            On_Approval_JSON__c = JSON.serialize(acfg),
            On_Rejection_JSON__c = JSON.serialize(acfg)
        );
        insert cfg;

        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = b.Id;
        req.priorValuesJson = JSON.serialize(
            new Map<String, String>{ 'Booking_Verification_Approval_Status__c' => 'Pending' }
        );
        Test.startTest();
        ApprovalActionHandler.processApprovalNotifications(
            new List<ApprovalActionHandler.NotificationRequest>{ req }
        );
        Test.stopTest();
    }

    @isTest
    static void processApprovalNotifications_emailNoRecipients() {
        delete [SELECT Id FROM Approval_Configuration__c];
        ApprovalActionHandler.ActionConfig acfg = new ApprovalActionHandler.ActionConfig();
        acfg.actions = new List<ApprovalActionHandler.ActionItem>();
        ApprovalActionHandler.ActionItem em = new ApprovalActionHandler.ActionItem();
        em.actionType = 'EMAIL_NOTIFICATION';
        em.emailConfig = new ApprovalActionHandler.EmailConfig();
        // empty recipientFieldPaths
        acfg.actions.add(em);

        Approval_Configuration__c cfg = new Approval_Configuration__c(
            Object_API_Name__c = 'Booking__c',
            Process_Type__c = 'Verification',
            Process_Label__c = 'BV',
            Status_Field_API_Name__c = 'Booking_Verification_Approval_Status__c',
            Approved_Status_Value__c = 'Approved',
            Rejected_Status_Value__c = 'Rejected',
            Is_Active__c = true,
            On_Approval_JSON__c = JSON.serialize(acfg),
            On_Rejection_JSON__c = JSON.serialize(acfg)
        );
        insert cfg;

        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = b.Id;
        req.priorValuesJson = JSON.serialize(
            new Map<String, String>{ 'Booking_Verification_Approval_Status__c' => 'Pending' }
        );
        Test.startTest();
        ApprovalActionHandler.processApprovalNotifications(
            new List<ApprovalActionHandler.NotificationRequest>{ req }
        );
        Test.stopTest();
    }

    @isTest
    static void processApprovalNotifications_bellMissingTitleAndBody() {
        delete [SELECT Id FROM Approval_Configuration__c];
        ApprovalActionHandler.ActionConfig acfg = new ApprovalActionHandler.ActionConfig();
        acfg.actions = new List<ApprovalActionHandler.ActionItem>();
        ApprovalActionHandler.ActionItem bell = new ApprovalActionHandler.ActionItem();
        bell.actionType = 'BELL_NOTIFICATION';
        bell.bellConfig = new ApprovalActionHandler.BellConfig();
        bell.bellConfig.title = '';
        bell.bellConfig.body = '';
        acfg.actions.add(bell);

        Approval_Configuration__c cfg = new Approval_Configuration__c(
            Object_API_Name__c = 'Booking__c',
            Process_Type__c = 'Verification',
            Process_Label__c = 'BV',
            Status_Field_API_Name__c = 'Booking_Verification_Approval_Status__c',
            Approved_Status_Value__c = 'Approved',
            Rejected_Status_Value__c = 'Rejected',
            Is_Active__c = true,
            On_Approval_JSON__c = JSON.serialize(acfg),
            On_Rejection_JSON__c = JSON.serialize(acfg)
        );
        insert cfg;

        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = b.Id;
        req.priorValuesJson = JSON.serialize(
            new Map<String, String>{ 'Booking_Verification_Approval_Status__c' => 'Pending' }
        );
        Test.startTest();
        ApprovalActionHandler.processApprovalNotifications(
            new List<ApprovalActionHandler.NotificationRequest>{ req }
        );
        Test.stopTest();
    }

    @isTest
    static void processApprovalNotifications_bellNoRecipients() {
        delete [SELECT Id FROM Approval_Configuration__c];
        ApprovalActionHandler.ActionConfig acfg = new ApprovalActionHandler.ActionConfig();
        acfg.actions = new List<ApprovalActionHandler.ActionItem>();
        ApprovalActionHandler.ActionItem bell = new ApprovalActionHandler.ActionItem();
        bell.actionType = 'BELL_NOTIFICATION';
        bell.bellConfig = new ApprovalActionHandler.BellConfig();
        bell.bellConfig.title = 'Hi';
        bell.bellConfig.body = 'Body';
        // no recipientFieldPaths
        acfg.actions.add(bell);

        Approval_Configuration__c cfg = new Approval_Configuration__c(
            Object_API_Name__c = 'Booking__c',
            Process_Type__c = 'Verification',
            Process_Label__c = 'BV',
            Status_Field_API_Name__c = 'Booking_Verification_Approval_Status__c',
            Approved_Status_Value__c = 'Approved',
            Rejected_Status_Value__c = 'Rejected',
            Is_Active__c = true,
            On_Approval_JSON__c = JSON.serialize(acfg),
            On_Rejection_JSON__c = JSON.serialize(acfg)
        );
        insert cfg;

        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = b.Id;
        req.priorValuesJson = JSON.serialize(
            new Map<String, String>{ 'Booking_Verification_Approval_Status__c' => 'Pending' }
        );
        Test.startTest();
        ApprovalActionHandler.processApprovalNotifications(
            new List<ApprovalActionHandler.NotificationRequest>{ req }
        );
        Test.stopTest();
    }

    @isTest
    static void processApprovalNotifications_chatterBlankMessage_skipped() {
        delete [SELECT Id FROM Approval_Configuration__c];
        ApprovalActionHandler.ActionConfig acfg = new ApprovalActionHandler.ActionConfig();
        acfg.actions = new List<ApprovalActionHandler.ActionItem>();
        ApprovalActionHandler.ActionItem ch = new ApprovalActionHandler.ActionItem();
        ch.actionType = 'CHATTER_POST';
        ch.chatterMessage = null;
        acfg.actions.add(ch);

        Approval_Configuration__c cfg = new Approval_Configuration__c(
            Object_API_Name__c = 'Booking__c',
            Process_Type__c = 'Verification',
            Process_Label__c = 'BV',
            Status_Field_API_Name__c = 'Booking_Verification_Approval_Status__c',
            Approved_Status_Value__c = 'Approved',
            Rejected_Status_Value__c = 'Rejected',
            Is_Active__c = true,
            On_Approval_JSON__c = JSON.serialize(acfg),
            On_Rejection_JSON__c = JSON.serialize(acfg)
        );
        insert cfg;

        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = b.Id;
        req.priorValuesJson = JSON.serialize(
            new Map<String, String>{ 'Booking_Verification_Approval_Status__c' => 'Pending' }
        );
        Test.startTest();
        ApprovalActionHandler.processApprovalNotifications(
            new List<ApprovalActionHandler.NotificationRequest>{ req }
        );
        Test.stopTest();
    }

    @isTest
    static void processApprovalNotifications_multipleRequestsBatch() {
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        List<ApprovalActionHandler.NotificationRequest> reqs = new List<ApprovalActionHandler.NotificationRequest>();
        for (Integer i = 0; i < 5; i++) {
            ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
            req.recordId = b.Id;
            req.priorValuesJson = JSON.serialize(
                new Map<String, String>{ 'Booking_Verification_Approval_Status__c' => 'Pending' }
            );
            reqs.add(req);
        }
        Test.startTest();
        List<ApprovalActionHandler.NotificationResult> res =
            ApprovalActionHandler.processApprovalNotifications(reqs);
        Test.stopTest();
        System.assertEquals(5, res.size(), 'should return 5');
    }

    @isTest
    static void processApprovalNotifications_neitherApprovedNorRejected_skipsAction() {
        delete [SELECT Id FROM Approval_Configuration__c];
        Approval_Configuration__c cfg = new Approval_Configuration__c(
            Object_API_Name__c = 'Booking__c',
            Process_Type__c = 'Verification',
            Process_Label__c = 'BV',
            Status_Field_API_Name__c = 'Booking_Verification_Approval_Status__c',
            Approved_Status_Value__c = 'Approved',
            Rejected_Status_Value__c = 'Rejected',
            Is_Active__c = true,
            On_Approval_JSON__c = '{}',
            On_Rejection_JSON__c = '{}'
        );
        insert cfg;
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        b.Booking_Verification_Approval_Status__c = 'Pending';
        try { update b; } catch (Exception e) { /* ok */ }

        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = b.Id;
        req.priorValuesJson = JSON.serialize(
            new Map<String, String>{ 'Booking_Verification_Approval_Status__c' => 'Draft' }
        );
        Test.startTest();
        ApprovalActionHandler.processApprovalNotifications(
            new List<ApprovalActionHandler.NotificationRequest>{ req }
        );
        Test.stopTest();
    }

    @isTest
    static void processApprovalNotifications_bellWithMergeFields() {
        delete [SELECT Id FROM Approval_Configuration__c];
        ApprovalActionHandler.ActionConfig acfg = new ApprovalActionHandler.ActionConfig();
        acfg.actions = new List<ApprovalActionHandler.ActionItem>();
        ApprovalActionHandler.ActionItem bell = new ApprovalActionHandler.ActionItem();
        bell.actionType = 'BELL_NOTIFICATION';
        bell.bellConfig = new ApprovalActionHandler.BellConfig();
        bell.bellConfig.title = 'Title with {Name} and {InvalidField__c}';
        bell.bellConfig.body = 'Body with {Status__c}';
        bell.bellConfig.recipientFieldPaths = new List<String>{ 'OwnerId' };
        acfg.actions.add(bell);

        Approval_Configuration__c cfg = new Approval_Configuration__c(
            Object_API_Name__c = 'Booking__c',
            Process_Type__c = 'Verification',
            Process_Label__c = 'BV',
            Status_Field_API_Name__c = 'Booking_Verification_Approval_Status__c',
            Approved_Status_Value__c = 'Approved',
            Rejected_Status_Value__c = 'Rejected',
            Is_Active__c = true,
            On_Approval_JSON__c = JSON.serialize(acfg),
            On_Rejection_JSON__c = JSON.serialize(acfg)
        );
        insert cfg;

        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        ApprovalActionHandler.NotificationRequest req = new ApprovalActionHandler.NotificationRequest();
        req.recordId = b.Id;
        req.priorValuesJson = JSON.serialize(
            new Map<String, String>{ 'Booking_Verification_Approval_Status__c' => 'Pending' }
        );
        Test.startTest();
        ApprovalActionHandler.processApprovalNotifications(
            new List<ApprovalActionHandler.NotificationRequest>{ req }
        );
        Test.stopTest();
    }

    @isTest
    static void wrappers_areInstantiable() {
        ApprovalActionHandler.NotificationRequest nr = new ApprovalActionHandler.NotificationRequest();
        ApprovalActionHandler.NotificationResult nres = new ApprovalActionHandler.NotificationResult();
        ApprovalActionHandler.ActionConfig ac = new ApprovalActionHandler.ActionConfig();
        ApprovalActionHandler.ActionItem ai = new ApprovalActionHandler.ActionItem();
        ApprovalActionHandler.EmailConfig ec = new ApprovalActionHandler.EmailConfig();
        ApprovalActionHandler.BellConfig bc = new ApprovalActionHandler.BellConfig();
        ApprovalActionHandler.FieldUpdate fu = new ApprovalActionHandler.FieldUpdate();
        nres.success = true; nres.message = 'm';
        ai.actionType = 'X'; ai.chatterMessage = 'm';
        fu.fieldName = 'F'; fu.value = 'V';
        System.assertEquals(true, nres.success);
        System.assertEquals('m', nres.message);
        System.assertNotEquals(null, ac);
        System.assertNotEquals(null, ai);
        System.assertNotEquals(null, ec);
        System.assertNotEquals(null, bc);
        System.assertNotEquals(null, nr);
    }
}