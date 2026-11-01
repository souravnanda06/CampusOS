import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/models/expansion_models.dart';
import 'package:attendance_app/core/localization/language_provider.dart';
import 'package:attendance_app/core/localization/app_strings.dart';
import 'package:attendance_app/student/widgets/passport/document_wallet_card.dart';
import 'package:attendance_app/student/widgets/passport/fees_wallet_card.dart';
import 'package:attendance_app/student/widgets/passport/visitor_pass_card.dart';
import 'package:attendance_app/student/widgets/student_home_content.dart';
import 'package:attendance_app/auth/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CampusOS Product Expansion - Models Suite', () {
    test('DocumentRequestModel correctly parses and exposes certificateNumber and requestedAt', () {
      final json = {
        'id': 'doc-101',
        'studentId': 'stu-01',
        'documentType': 'BONAFIDE_CERTIFICATE',
        'documentTypeName': 'Bonafide Certificate',
        'purpose': 'Internship verification at TCS',
        'status': 'ISSUED',
        'documentNumber': 'CERT-2026-BPUT-8899',
        'storedInWallet': true,
        'createdAt': '2026-03-15T10:00:00Z',
        'issuedAt': '2026-03-16T12:00:00Z',
      };

      final doc = DocumentRequestModel.fromJson(json);
      expect(doc.id, 'doc-101');
      expect(doc.documentType, 'BONAFIDE_CERTIFICATE');
      expect(doc.certificateNumber, 'CERT-2026-BPUT-8899');
      expect(doc.requestedAt, DateTime.parse('2026-03-15T10:00:00Z'));
      expect(doc.storedInWallet, isTrue);
    });

    test('FeeRecordModel and FeeSummaryModel parse amounts and breakdowns accurately', () {
      final recordJson = {
        'id': 'fee-01',
        'studentId': 'stu-01',
        'title': 'Semester 6 Tuition Fee',
        'category': 'TUITION',
        'amount': 45000.0,
        'amountPaid': 45000.0,
        'balanceDue': 0.0,
        'dueDate': '2026-04-30',
        'status': 'PAID',
        'receiptNumber': 'REC-BPUT-2026-0042',
        'breakdownJson': '[{"label":"Tuition","amount":35000},{"label":"Lab Fee","amount":10000}]',
        'academicYear': '2025-2026',
        'semester': 6,
      };

      final fee = FeeRecordModel.fromJson(recordJson);
      expect(fee.id, 'fee-01');
      expect(fee.amount, 45000.0);
      expect(fee.balanceDue, 0.0);
      expect(fee.breakdownItems.length, 2);
      expect(fee.breakdownItems[0]['label'], 'Tuition');
      expect(fee.breakdownItems[1]['amount'], 10000);

      final summary = FeeSummaryModel.fromJson({
        'totalDue': 0.0,
        'status': 'PAID',
        'nextDueDate': 'None',
        'primaryCategory': 'All Cleared',
        'recordsCount': 1,
      });
      expect(summary.totalDue, 0.0);
      expect(summary.status, 'PAID');
    });

    test('HostelAllocationModel, HostelRequestModel & AssetIssueModel getters contract', () {
      final allocation = HostelAllocationModel.fromJson({
        'id': 'alloc-1',
        'studentId': 'stu-01',
        'hostelName': 'APJ Abdul Kalam Hall',
        'block': 'Block B',
        'roomNumber': '204',
        'bedNumber': 'B2',
        'occupancyType': 'DOUBLE',
        'allocatedAt': '2026-01-05T09:00:00Z',
        'status': 'ACTIVE',
        'notes': 'Verified',
        'hasAllocation': true,
        'roommates': [
          {'name': 'Rohan Das', 'reg': '220101'}
        ],
      });

      expect(allocation.hostelName, 'APJ Abdul Kalam Hall');
      expect(allocation.bedLabel, 'Bed B2');
      expect(allocation.roomType, 'DOUBLE');
      expect(allocation.roommates.length, 1);

      final request = HostelRequestModel.fromJson({
        'id': 'hreq-1',
        'studentId': 'stu-01',
        'requestType': 'ROOM_CHANGE',
        'preferredHostel': 'Block C',
        'preferredRoom': 'Single Deluxe',
        'reason': 'Final year project silence required',
        'status': 'PENDING',
        'createdAt': '2026-03-20T10:00:00Z',
      });

      expect(request.preferredBlock, 'Block C');
      expect(request.preferredRoomType, 'Single Deluxe');

      final assetIssue = AssetIssueModel.fromJson({
        'id': 'issue-1',
        'assetId': 'ast-01',
        'studentId': 'stu-01',
        'issueType': 'DAMAGED',
        'description': '[CRITICAL] Ceiling fan wobbling dangerously',
        'status': 'REPORTED',
        'reportedAt': '2026-03-28T14:00:00Z',
      });

      expect(assetIssue.urgency, 'CRITICAL');
    });

    test('ClassUpdateModel and VisitorRequestModel parse cleanly', () {
      final update = ClassUpdateModel.fromJson({
        'id': 'up-1',
        'teacherId': 't-01',
        'courseCode': 'CS602',
        'courseName': 'Compiler Design',
        'updateType': 'CANCELLED',
        'originalDate': '2026-03-30',
        'message': 'Lab session postponed due to campus symposium',
        'status': 'ACTIVE',
        'createdAt': '2026-03-29T08:00:00Z',
      });
      expect(update.courseCode, 'CS602');
      expect(update.updateType, 'CANCELLED');

      final visitor = VisitorRequestModel.fromJson({
        'id': 'vis-1',
        'studentId': 'stu-01',
        'visitorName': 'Debashis Pattnaik',
        'visitorPhone': '+91 98765 43210',
        'relation': 'Father',
        'purpose': 'Document verification & hostel visit',
        'visitDate': '2026-04-01',
        'expectedEntryTime': '10:00 AM',
        'expectedExitTime': '04:00 PM',
        'status': 'APPROVED',
        'passCode': 'VP-2026-7842',
      });
      expect(visitor.visitorName, 'Debashis Pattnaik');
      expect(visitor.passCode, 'VP-2026-7842');
    });
  });

  group('CampusOS Regional Localization Suite', () {
    test('LanguageProvider defaults to English and toggles through Hindi, Odia, and Bengali', () {
      final provider = LanguageProvider();
      expect(provider.currentLocale.languageCode, 'en');
      expect(provider.currentLanguageName, 'English');

      provider.setLanguage('hi');
      expect(provider.currentLocale.languageCode, 'hi');
      expect(provider.currentLanguageName, 'हिन्दी');
      expect(provider.getText('campus_wallet'), 'कैंपस वॉलेट');
      expect(provider.getText('home'), 'होम');

      provider.setLanguage('or');
      expect(provider.currentLocale.languageCode, 'or');
      expect(provider.currentLanguageName, 'ଓଡ଼ିଆ');
      expect(provider.getText('campus_wallet'), 'କ୍ୟାମ୍ପସ୍ ୱାଲେଟ୍');
      expect(provider.getText('home'), 'ମୁଖ୍ୟ ପୃଷ୍ଠା');

      provider.setLanguage('bn');
      expect(provider.currentLocale.languageCode, 'bn');
      expect(provider.currentLanguageName, 'বাংলা');
      expect(provider.getText('campus_wallet'), 'ক্যাম্পাস ওয়ালেট');

      provider.setLanguage('en');
      expect(provider.currentLocale.languageCode, 'en');
      expect(provider.getText('campus_wallet'), 'Campus Wallet');
    });

    test('AppStrings contains full translation parity across regional languages', () {
      final keys = [
        'campus_wallet',
        'fees_dues',
        'visitor_pass',
        'home',
        'requests',
        'wallet',
        'profile',
        'search',
        'notifications',
      ];

      for (final key in keys) {
        expect(AppStrings.tr(key, lang: 'en').isNotEmpty, isTrue);
        expect(AppStrings.tr(key, lang: 'hi').isNotEmpty, isTrue);
        expect(AppStrings.tr(key, lang: 'or').isNotEmpty, isTrue);
        expect(AppStrings.tr(key, lang: 'bn').isNotEmpty, isTrue);
      }
    });
  });

  group('CampusOS Expanded Wallet Cards Widget Rendering', () {
    testWidgets('DocumentWalletCard renders certificate badge and identity mesh styling',
        (tester) async {
      final doc = DocumentRequestModel(
        id: 'doc-01',
        studentId: 'stu-01',
        documentType: 'BONAFIDE_CERTIFICATE',
        documentTypeName: 'Bonafide Certificate',
        purpose: 'Passport Application',
        status: 'ISSUED',
        documentNumber: 'CERT-2026-9901',
        storedInWallet: true,
        createdAt: '2026-03-29T10:00:00Z',
        issuedAt: '2026-03-29T12:00:00Z',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DocumentWalletCard(
                document: doc,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Bonafide Certificate'), findsOneWidget);
      expect(find.text('CAMPUSOS • ATTESTED CREDENTIAL'), findsOneWidget);
      expect(find.text('CERT-2026-9901'), findsOneWidget);
    });

    testWidgets('FeesWalletCard renders balance due and clearance status',
        (tester) async {
      final summary = FeeSummaryModel(
        totalDue: 0.0,
        status: 'PAID',
        nextDueDate: 'None',
        primaryCategory: 'All Cleared',
        recordsCount: 4,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FeesWalletCard(
                feeSummary: summary,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('CAMPUSOS • ACADEMIC DUES'), findsOneWidget);
      expect(find.text('CLEARED'), findsOneWidget);
      expect(find.text('No Outstanding'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('VisitorPassCard renders active guest pass',
        (tester) async {
      final visitor = VisitorRequestModel(
        id: 'v-01',
        studentId: 'stu-01',
        visitorName: 'Rajesh Sharma',
        visitorPhone: '+91 99999 88888',
        relation: 'Parent',
        purpose: 'Hostel Visit',
        visitDate: '2026-04-02',
        expectedEntryTime: '11:00 AM',
        expectedExitTime: '05:00 PM',
        status: 'APPROVED',
        passCode: 'VP-2026-9042',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: VisitorPassCard(
                pass: visitor,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('CAMPUSOS • VISITOR PASS'), findsOneWidget);
      expect(find.text('Rajesh Sharma'), findsOneWidget);
      expect(find.text('VP-2026-9042'), findsOneWidget);
    });

    testWidgets('SafeLanguageConsumer immediately re-renders when LanguageProvider changes language',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeLanguageConsumer(
              builder: (context, currentLanguage, languageName) {
                return Text("LANG:$currentLanguage:$languageName");
              },
            ),
          ),
        ),
      );

      expect(find.text('LANG:en:English'), findsOneWidget);

      await LanguageProvider.instance.setLanguage('hi');
      await tester.pump();
      expect(find.text('LANG:hi:हिन्दी'), findsOneWidget);

      await LanguageProvider.instance.setLanguage('or');
      await tester.pump();
      expect(find.text('LANG:or:ଓଡ଼ିଆ'), findsOneWidget);

      // Restore to English
      await LanguageProvider.instance.setLanguage('en');
      await tester.pump();
      expect(find.text('LANG:en:English'), findsOneWidget);
    });

    testWidgets('TodaysAcademicUpdatesSection renders calm on-schedule card when empty',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final user = UserModel(
        id: 'test-stu-empty',
        name: 'Sourav Nanda',
        email: 'sourav@test.com',
        role: 'student',
        branch: 'CSE',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodaysAcademicUpdatesSection(
              user: user,
              initialUpdates: const [],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('All lectures and labs are on schedule today.'), findsOneWidget);
    });

    testWidgets('TodaysAcademicUpdatesSection card can be swiped to dismiss and disappears',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final user = UserModel(
        id: 'test-stu-swipe',
        name: 'Sourav Nanda',
        email: 'sourav@test.com',
        role: 'student',
        branch: 'CSE',
      );

      final update = ClassUpdateModel(
        id: 'update-swipe-1',
        teacherId: 't-1',
        courseCode: 'CS701',
        courseName: 'Cloud Computing',
        updateType: 'ROOM_CHANGED',
        originalDate: '2026-04-01',
        newRoom: 'Lab 4',
        message: 'Shifted to Lab 4 due to projector maintenance',
        status: 'ACTIVE',
        createdAt: DateTime.now().toIso8601String(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodaysAcademicUpdatesSection(
              user: user,
              initialUpdates: [update],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify card exists
      expect(find.text("Today's Academic Updates"), findsOneWidget);
      expect(find.text('CS701 - Cloud Computing'), findsOneWidget);
      expect(find.text('ROOM CHANGE'), findsOneWidget);
      expect(find.text('Swipe to dismiss'), findsOneWidget);

      // Swipe the Dismissible card to the left
      await tester.drag(find.byType(Dismissible), const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();

      // After swiping, the card is dismissed and removed from the screen!
      expect(find.text('CS701 - Cloud Computing'), findsNothing);
      expect(find.text('All lectures and labs are on schedule today.'), findsOneWidget);
    });
  });
}
