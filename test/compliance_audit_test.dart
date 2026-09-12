import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_saver/core/compliance/compliance_audit_service.dart';
import 'package:media_saver/core/compliance/content_authorization.dart';
import 'package:media_saver/core/compliance/copyright_complaint_repository.dart';
import 'package:media_saver/core/storage/preferences_service.dart';
import 'package:media_saver/core/utils/url_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late PreferencesService prefsService;
  late ComplianceAuditService auditService;
  late CopyrightComplaintRepository complaintRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    prefsService = PreferencesService(prefs);
    auditService = ComplianceAuditService(prefsService);
    complaintRepo = CopyrightComplaintRepository(prefsService);
  });

  group('ComplianceAuditService', () {
    test('records non-sensitive compliance audit entries without credentials or tokens', () async {
      await auditService.recordEvent(
        platform: MediaPlatform.facebookVideo,
        action: 'download',
        decision: 'permitted',
        authorizationType: ContentAuthorizationType.owner,
      );

      final logs = auditService.getRecentAuditLogs();
      expect(logs.length, 1);
      final log = logs.first;
      expect(log.platform, 'facebookVideo');
      expect(log.action, 'download');
      expect(log.decision, 'permitted');
      expect(log.authorizationType, 'owner');
      expect(log.policyVersion, isNotEmpty);
      expect(log.timestamp, isNotNull);

      final json = log.toJson();
      expect(json.containsKey('password'), isFalse);
      expect(json.containsKey('cookie'), isFalse);
      expect(json.containsKey('token'), isFalse);
    });

    test('maintains a rolling buffer and caps logs at max entries', () async {
      for (int i = 0; i < 55; i++) {
        await auditService.recordEvent(
          platform: MediaPlatform.instagramReel,
          action: 'inspect',
          decision: 'permitted',
          reason: 'Event #$i',
        );
      }

      final logs = auditService.getRecentAuditLogs();
      expect(logs.length, 50);
      expect(logs.first.reason, 'Event #54');
    });

    test('clears audit logs cleanly', () async {
      await auditService.recordEvent(
        platform: MediaPlatform.facebookVideo,
        action: 'download',
        decision: 'permitted',
      );
      expect(auditService.getRecentAuditLogs().length, 1);

      await auditService.clearLogs();
      expect(auditService.getRecentAuditLogs(), isEmpty);
    });
  });

  group('CopyrightComplaintRepository', () {
    test('submits and retrieves legitimate rights holder complaints', () async {
      final complaint = await complaintRepo.submitComplaint(
        contentUrl: 'https://www.facebook.com/video/12345',
        rightsHolderName: 'Acme Media Corp',
        contactEmail: 'dmca@acme.com',
        description: 'Unauthorized distribution of licensed clip',
        ownershipDetails: 'Exclusive broadcasting licensee',
        requestedAction: 'takedown',
      );

      expect(complaint.id, isNotEmpty);
      expect(complaint.status, 'submitted');

      final list = complaintRepo.getComplaints();
      expect(list.length, 1);
      expect(list.first.rightsHolderName, 'Acme Media Corp');
      expect(list.first.contactEmail, 'dmca@acme.com');
    });
  });

  group('PreferencesService Compliance Persistence', () {
    test('tracks policy acceptance timestamp and version', () async {
      expect(prefsService.hasAcceptedPolicy, isFalse);
      expect(prefsService.policyAcceptedTimestamp, isNull);

      await prefsService.recordPolicyAcceptance(version: '1.0.0');

      expect(prefsService.hasAcceptedPolicy, isTrue);
      expect(prefsService.policyAcceptedTimestamp, isNotNull);
      expect(prefsService.policyAcceptedVersion, '1.0.0');
    });

    test('tracks last selected authorization type', () async {
      expect(prefsService.lastAuthorizationType, isNull);

      await prefsService.setLastAuthorizationType(ContentAuthorizationType.licensee.id);
      expect(prefsService.lastAuthorizationType, 'licensee');
    });
  });
}
