import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/auth/providers/user_provider.dart';
import 'package:attendance_app/core/localization/language_provider.dart';
import 'package:attendance_app/auth/services/auth_service.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/router/app_routes.dart';
import 'package:attendance_app/screens/home_screen.dart';
import 'package:attendance_app/student/models/mess_model.dart';
import 'package:attendance_app/student/models/passport_verification_result.dart';
import 'package:attendance_app/student/services/mess_service.dart';
import 'package:attendance_app/student/services/passport_verifier_service.dart';
import 'package:attendance_app/student/services/passport_offline_verifier_service.dart';
import 'package:attendance_app/mess/screens/mess_shell_screen.dart';
import 'package:attendance_app/mess/screens/mess_today_screen.dart';
import 'package:attendance_app/mess/screens/mess_batch_verification_screen.dart';
import 'package:attendance_app/mess/screens/mess_qr_scanner_screen.dart';
import 'package:attendance_app/mess/screens/mess_analytics_screen.dart';
import 'package:attendance_app/mess/screens/mess_profile_screen.dart';

// =============================================================================
// --- MOCK SERVICES FOR TEST SUITE ---
// =============================================================================

class MockMessService extends MessService {
  TodayMealStats mockTodayStats = TodayMealStats(
    date: '2026-10-15',
    activeMeal: 'LUNCH',
    mealTiming: '12:00 PM – 3:00 PM',
    menuStatus: 'PUBLISHED',
    totalVerifiedToday: 42,
    counts: {
      'LUNCH': MealTypeEntryCounts(total: 42, batch: 35, qr: 7),
      'BREAKFAST': MealTypeEntryCounts(total: 10, batch: 10, qr: 0),
    },
    recentEntries: [
      MealEntryRecord(
        id: 'rec_1',
        mealType: 'LUNCH',
        entryDate: '2026-10-15',
        studentId: 'stud_1',
        studentName: 'Alice Student',
        registrationNumber: 'REG2026001',
        verifiedBy: 'staff_1',
        verificationMode: 'BATCH',
      ),
    ],
  );

  MessOperationalAnalytics mockAnalytics = MessOperationalAnalytics(
    totalEntries: 250,
    batchEntries: 200,
    qrEntries: 50,
    todayEntries: 42,
    mealBreakdown: {
      'BREAKFAST': 50,
      'LUNCH': 120,
      'SNACKS': 30,
      'DINNER': 50,
    },
  );

  Map<String, dynamic> nextVerifyResult = {
    'status': 'VERIFIED',
    'message': 'Student verified for Lunch',
  };

  int verifyCallCount = 0;
  int batchSyncCallCount = 0;

  @override
  Future<TodayMealStats> getTodayMealStats({String? requesterId}) async {
    return mockTodayStats;
  }

  @override
  Future<MessMenu?> getTodayMenu({String? requesterId}) async {
    return MessMenu(
      id: 'menu_today_1',
      menuDate: '2026-10-15',
      status: 'PUBLISHED',
      meals: [
        MessMeal(
          id: 'meal_lunch_1',
          menuId: 'menu_today_1',
          mealType: 'LUNCH',
          title: 'Lunch',
          items: ['Rice', 'Dal', 'Paneer'],
        ),
      ],
    );
  }

  @override
  Future<MessOperationalAnalytics> getMessOperationalAnalytics({
    String? requesterId,
  }) async {
    return mockAnalytics;
  }

  @override
  Future<Map<String, dynamic>> verifyMealEntry({
    required String studentId,
    String? studentName,
    String? registrationNumber,
    required String mealType,
    String? date,
    String? mealId,
    String? menuId,
    String verificationMode = 'QR_FALLBACK',
    String? idempotencyKey,
    String? qrPayload,
    String? signature,
    String? requesterId,
  }) async {
    verifyCallCount++;
    return nextVerifyResult;
  }

  @override
  Future<Map<String, dynamic>> batchSyncMealEntries({
    required String mealType,
    required String date,
    required List<Map<String, dynamic>> records,
    String? requesterId,
  }) async {
    batchSyncCallCount++;
    return {
      'newSynced': records.length,
      'duplicates': 0,
      'totalRecords': records.length,
      'records': records.map((r) => MealEntryRecord.fromMap(r)).toList(),
    };
  }
}

class MockPassportVerifierService extends PassportVerifierService {
  PassportVerificationResult? nextResult;

  @override
  Future<PassportVerificationResult> verifyQrString(
    String qrString, {
    dynamic proximityObservation,
  }) async {
    return nextResult ??
        const PassportVerificationResult(
          valid: true,
          reason: 'VALID',
          userId: 'stud_1',
          user: PassportVerifiedUser(
            name: 'Alice Student',
            registrationNumber: 'REG2026001',
          ),
        );
  }
}

class MockPassportOfflineVerifierService extends PassportOfflineVerifierService {
  PassportVerificationResult? nextResult;

  @override
  Future<PassportVerificationResult> verifyOffline({
    required String qrPayload,
    int? currentTimestampSeconds,
    int maxClockSkewSeconds = 30,
  }) async {
    return nextResult ??
        const PassportVerificationResult(
          valid: true,
          reason: 'OFFLINE_VALID',
          verificationSource: 'OFFLINE',
          userId: 'stud_1',
          user: PassportVerifiedUser(
            name: 'Alice Student',
            registrationNumber: 'REG2026001',
          ),
        );
  }
}

// =============================================================================
// --- MAIN TEST SUITE ---
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messStaffUser = UserModel(
    id: 'staff_gordon',
    email: 'chef.gordon@campusos.edu',
    name: 'Chef Gordon',
    role: 'mess_staff',
  );

  Widget createTestWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>(
          create: (_) {
            final p = UserProvider();
            p.setUser(messStaffUser);
            return p;
          },
        ),
        ChangeNotifierProvider<LanguageProvider>.value(
          value: LanguageProvider.instance,
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(
          scaffoldBackgroundColor: AppColors.bg,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        ),
        home: child,
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CampusOS Mess Staff Experience — Auth & Role Routing', () {
    testWidgets('1. MESS_STAFF role routes to MessShellScreen in HomeScreen', (tester) async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'dummy_jwt_token',
        'user_data': '{"id":"staff_1","email":"chef@campusos.edu","name":"Chef Gordon","role":"mess_staff"}',
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<LanguageProvider>.value(
          value: LanguageProvider.instance,
          child: MaterialApp(
            home: const HomeScreen(),
            routes: {
              AppRoutes.login: (_) => const Scaffold(body: Text('Login Screen')),
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(MessShellScreen), findsOneWidget);
      expect(find.text('Mess Operations'), findsOneWidget);
    });

    testWidgets('2. Normal sign out preserves device security material and clears auth tokens', (tester) async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'dummy_jwt',
        'user_data': '{"id":"staff_1","role":"mess_staff"}',
        'mess_offline_entry_queue': ['{"id":"offline_1"}'],
      });

      await AuthService.signOut();
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('user_data'), isNull);
      // Offline queue preserved
      expect(prefs.getStringList('mess_offline_entry_queue'), isNotNull);
    });
  });

  group('CampusOS Mess Staff Experience — Shell Navigation Dock', () {
    testWidgets('3. MessShellScreen renders exactly 4 destinations and switches tabs', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          MessShellScreen(user: messStaffUser),
        ),
      );
      await tester.pumpAndSettle();

      // Exactly 4 navigation dock destinations
      expect(find.widgetWithText(MessDockItem, 'Today'), findsOneWidget);
      expect(find.widgetWithText(MessDockItem, 'Menus'), findsOneWidget);
      expect(find.widgetWithText(MessDockItem, 'Analytics'), findsOneWidget);
      expect(find.widgetWithText(MessDockItem, 'Profile'), findsOneWidget);

      // Tab 0: Today is default
      expect(find.text('Mess Operations'), findsOneWidget);

      // Tap Tab 2: Analytics
      await tester.tap(find.widgetWithText(MessDockItem, 'Analytics'));
      await tester.pumpAndSettle();
      expect(find.text('Mess Analytics'), findsOneWidget);

      // Tap Tab 3: Profile
      await tester.tap(find.widgetWithText(MessDockItem, 'Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Chef Gordon'), findsOneWidget);
      expect(find.text('MESS_STAFF'), findsOneWidget);
    });
  });

  group('CampusOS Mess Staff Experience — Today Operational Screen', () {
    testWidgets('4. MessTodayScreen displays active meal, counts, and primary actions', (tester) async {
      final mockService = MockMessService();

      await tester.pumpWidget(
        createTestWidget(
          MessTodayScreen(
            user: messStaffUser,
            messService: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mess Operations'), findsOneWidget);
      expect(find.text('LUNCH'), findsOneWidget);
      expect(find.text('BATCH VERIFICATION'), findsOneWidget);
      expect(find.text('Scan QR Code'), findsOneWidget);
      expect(find.text('Batch Verified'), findsOneWidget);
      expect(find.text('QR Fallbacks'), findsOneWidget);
      expect(find.text('Alice Student'), findsOneWidget);
    });
  });

  group('CampusOS Mess Staff Experience — Batch Verification & Fallback States', () {
    testWidgets('5. MessBatchVerificationScreen transitions to ACTIVE and records events', (tester) async {
      final mockService = MockMessService();

      await tester.pumpWidget(
        createTestWidget(
          MessBatchVerificationScreen(
            user: messStaffUser,
            mealType: 'LUNCH',
            date: '2026-10-15',
            messService: mockService,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('Students verified'), findsOneWidget);
      expect(find.text('Entries recorded'), findsOneWidget);
      expect(find.text('End Batch Session'), findsOneWidget);

      // Add verified event
      final state = tester.state<MessBatchVerificationScreenState>(
        find.byType(MessBatchVerificationScreen),
      );
      state.recordBatchEvent(
        BatchVerificationEvent(
          id: 'ev_1',
          studentName: 'Alice Student',
          studentId: 'stud_1',
          status: MealVerificationStatus.verified,
          message: 'Student verified via Batch',
          timestamp: DateTime.now(),
        ),
      );
      await tester.pump();

      expect(find.text('✓ verified'), findsOneWidget);
      expect(find.text('1'), findsWidgets); // 1 verified
    });

    testWidgets('6. Batch unavailable displays fallback card and switches to QR scanning', (tester) async {
      final mockService = MockMessService();

      await tester.pumpWidget(
        MaterialApp(
          home: MessBatchVerificationScreen(
            user: messStaffUser,
            mealType: 'LUNCH',
            date: '2026-10-15',
            messService: mockService,
            simulateUnavailableForTesting: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('UNAVAILABLE'), findsOneWidget);
      expect(find.text('Batch verification unavailable'), findsOneWidget);
      expect(find.text('Continue using individual student verification.'), findsOneWidget);
      expect(find.byKey(const Key('switch_to_qr_scanning_action')), findsOneWidget);

      // Tap SWITCH TO QR SCANNING
      await tester.tap(find.byKey(const Key('switch_to_qr_scanning_action')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(MessQrScannerScreen), findsOneWidget);
    });

    testWidgets('7. Batch failed displays fallback card and switches to QR scanning', (tester) async {
      final mockService = MockMessService();

      await tester.pumpWidget(
        MaterialApp(
          home: MessBatchVerificationScreen(
            user: messStaffUser,
            mealType: 'LUNCH',
            date: '2026-10-15',
            messService: mockService,
            simulateFailureForTesting: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('FAILED'), findsOneWidget);
      expect(find.text('Batch verification failed'), findsOneWidget);
      expect(find.byKey(const Key('switch_to_qr_scanning_action')), findsOneWidget);
    });
  });

  group('CampusOS Mess Staff Experience — QR Fallback Scanning & Verification', () {
    testWidgets('8. Valid QR scan verifies student and records meal entry', (tester) async {
      final mockMessService = MockMessService();
      final mockPassportService = MockPassportVerifierService();
      final fakeController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        autoStart: false,
      );

      mockPassportService.nextResult = const PassportVerificationResult(
        valid: true,
        reason: 'VALID',
        userId: 'stud_1',
        user: PassportVerifiedUser(
          name: 'Alice Student',
          registrationNumber: 'REG2026001',
        ),
      );

      mockMessService.nextVerifyResult = {
        'status': 'VERIFIED',
        'message': 'Student verified for Lunch',
      };

      await tester.pumpWidget(
        createTestWidget(
          MessQrScannerScreen(
            user: messStaffUser,
            mealType: 'LUNCH',
            date: '2026-10-15',
            messService: mockMessService,
            passportVerifierService: mockPassportService,
            controller: fakeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LUNCH · QR FALLBACK'), findsOneWidget);
      expect(find.text('End QR Verification'), findsOneWidget);

      // Simulate QR barcode detection
      final state = tester.state<MessQrScannerScreenState>(
        find.byType(MessQrScannerScreen),
      );
      await state.handleDetectedBarcode(
        const BarcodeCapture(barcodes: [Barcode(rawValue: 'valid_qr_presentation')]),
      );
      await tester.pump();

      expect(find.text('✓ VERIFIED'), findsOneWidget);
      expect(find.text('Alice Student'), findsOneWidget);
      expect(mockMessService.verifyCallCount, equals(1));

      fakeController.dispose();
    });

    testWidgets('9. Duplicate scan rejected with ALREADY USED', (tester) async {
      final mockMessService = MockMessService();
      final mockPassportService = MockPassportVerifierService();
      final fakeController = MobileScannerController(autoStart: false);

      mockPassportService.nextResult = const PassportVerificationResult(
        valid: true,
        reason: 'VALID',
        userId: 'stud_1',
        user: PassportVerifiedUser(name: 'Alice Student'),
      );

      mockMessService.nextVerifyResult = {
        'status': 'ALREADY_USED',
        'message': 'Student already checked in for Lunch on 2026-10-15',
      };

      await tester.pumpWidget(
        createTestWidget(
          MessQrScannerScreen(
            user: messStaffUser,
            mealType: 'LUNCH',
            date: '2026-10-15',
            messService: mockMessService,
            passportVerifierService: mockPassportService,
            controller: fakeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state<MessQrScannerScreenState>(
        find.byType(MessQrScannerScreen),
      );
      await state.handleDetectedBarcode(
        const BarcodeCapture(barcodes: [Barcode(rawValue: 'already_used_qr')]),
      );
      await tester.pump();

      expect(find.text('⚠ ALREADY USED'), findsOneWidget);
      fakeController.dispose();
    });

    testWidgets('10. Invalid QR presentation rejected with VERIFICATION FAILED', (tester) async {
      final mockMessService = MockMessService();
      final mockPassportService = MockPassportVerifierService();
      final fakeController = MobileScannerController(autoStart: false);

      mockPassportService.nextResult = const PassportVerificationResult(
        valid: false,
        reason: 'Cryptographic signature mismatch',
      );

      await tester.pumpWidget(
        createTestWidget(
          MessQrScannerScreen(
            user: messStaffUser,
            mealType: 'LUNCH',
            date: '2026-10-15',
            messService: mockMessService,
            passportVerifierService: mockPassportService,
            controller: fakeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state<MessQrScannerScreenState>(
        find.byType(MessQrScannerScreen),
      );
      await state.handleDetectedBarcode(
        const BarcodeCapture(barcodes: [Barcode(rawValue: 'tampered_qr')]),
      );
      await tester.pump();

      expect(find.text('✕ VERIFICATION FAILED'), findsOneWidget);
      expect(find.text('Cryptographic signature mismatch'), findsOneWidget);
      fakeController.dispose();
    });
  });

  group('CampusOS Mess Staff Experience — Offline Verification & Sync', () {
    testWidgets('11. Offline scan verifies locally and queues entry', (tester) async {
      final mockMessService = MockMessService();
      final mockOfflineVerifier = MockPassportOfflineVerifierService();
      final fakeController = MobileScannerController(autoStart: false);

      mockOfflineVerifier.nextResult = const PassportVerificationResult(
        valid: true,
        reason: 'OFFLINE_VALID',
        verificationSource: 'OFFLINE',
        userId: 'stud_offline_1',
        user: PassportVerifiedUser(
          name: 'Offline Student',
          registrationNumber: 'REG_OFF_001',
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          MessQrScannerScreen(
            user: messStaffUser,
            mealType: 'DINNER',
            date: '2026-10-15',
            messService: mockMessService,
            offlineVerifierService: mockOfflineVerifier,
            controller: fakeController,
            initialOfflineMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OFFLINE'), findsOneWidget);

      final state = tester.state<MessQrScannerScreenState>(
        find.byType(MessQrScannerScreen),
      );
      await state.handleDetectedBarcode(
        const BarcodeCapture(barcodes: [Barcode(rawValue: 'offline_valid_qr')]),
      );
      await tester.pump();

      expect(find.text('⚠ LOCAL VERIFIED'), findsOneWidget);
      expect(find.text('Offline Student'), findsOneWidget);

      // Verify entry was added to offline queue
      final queued = await mockMessService.getQueuedOfflineMealEntries();
      expect(queued.length, equals(1));
      expect(queued.first.studentId, equals('stud_offline_1'));

      fakeController.dispose();
    });

    testWidgets('12. Offline sync synchronizes queued entries and clears queue idempotently', (tester) async {
      final service = MockMessService();
      await service.queueOfflineMealEntry(
        MealEntryRecord(
          id: 'off_entry_1',
          mealType: 'LUNCH',
          entryDate: '2026-10-15',
          studentId: 'stud_1',
          studentName: 'Alice Student',
          verifiedBy: 'staff_1',
        ),
      );

      final beforeSync = await service.getQueuedOfflineMealEntries();
      expect(beforeSync.length, equals(1));

      final syncResult = await service.syncQueuedOfflineMealEntries(requesterId: 'staff_1');
      expect(syncResult['synced'], equals(1));
      expect(service.batchSyncCallCount, equals(1));

      final afterSync = await service.getQueuedOfflineMealEntries();
      expect(afterSync, isEmpty);
    });
  });

  group('CampusOS Mess Staff Experience — Analytics & Profile', () {
    testWidgets('13. MessAnalyticsScreen renders real operational distribution', (tester) async {
      final mockService = MockMessService();

      await tester.pumpWidget(
        createTestWidget(
          MessAnalyticsScreen(
            user: messStaffUser,
            messService: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mess Analytics'), findsOneWidget);
      expect(find.text('Total Verified Entries'), findsOneWidget);
      expect(find.text('250'), findsOneWidget);
      expect(find.text('Verification Method Ratio'), findsOneWidget);
      expect(find.text('Meal-Wise Entry Totals'), findsOneWidget);
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);
    });

    testWidgets('14. MessProfileScreen renders staff details and sign out dialog', (tester) async {
      final mockService = MockMessService();

      await tester.pumpWidget(
        createTestWidget(
          MessProfileScreen(
            user: messStaffUser,
            messService: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chef Gordon'), findsOneWidget);
      expect(find.text('chef.gordon@campusos.edu'), findsOneWidget);
      expect(find.text('MESS_STAFF'), findsOneWidget);
      expect(find.text('Institutional Trust Bundle'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);

      // Tap Log Out
      await tester.ensureVisible(find.text('Log Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();

      // Dialog opens explaining that security material is preserved
      expect(find.textContaining('safely preserved'), findsOneWidget);
    });
  });
}
