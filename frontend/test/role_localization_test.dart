import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_app/core/localization/language_provider.dart';
import 'package:attendance_app/core/localization/app_strings.dart';
import 'package:attendance_app/core/localization/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LanguageProvider.instance.setLanguage('en');
  });

  group('Multi-Role Regional Localization Tests', () {
    test('LanguageProvider supports 4 institutional regional languages', () {
      const supported = LanguageProvider.supportedLanguages;
      expect(supported.keys, containsAll(['en', 'hi', 'or', 'bn']));
      expect(supported['en'], equals('English'));
      expect(supported['hi'], equals('हिन्दी'));
      expect(supported['or'], equals('ଓଡ଼ିଆ'));
      expect(supported['bn'], equals('বাংলা'));
    });

    test('Teacher operations dictionary translations exist for all languages', () {
      const keys = [
        'Faculty',
        'Start Attendance',
        'Assigned Classes',
        'Recent Sessions',
        'Cohort attendance & student risk tracking',
        'FILTER COHORT',
        'Apply Filters',
        'Reset Device ID?',
      ];

      for (final lang in ['en', 'hi', 'or', 'bn']) {
        for (final k in keys) {
          final translated = AppStrings.tr(k, lang: lang);
          expect(translated, isNotEmpty, reason: 'Key "$k" should not be empty in $lang');
          if (lang != 'en') {
            expect(translated, isNot(equals(k)),
                reason: 'Key "$k" should be translated into $lang');
          }
        }
      }
    });

    test('Mess operations dictionary translations exist for all languages', () {
      const keys = [
        'Mess Operations',
        'Offline Entries Pending',
        'Sync Now',
        'Batch Verification',
        'Scan QR Code',
        'Mess Analytics',
        'Total Verified Entries',
        "Today's Check-ins",
      ];

      for (final lang in ['en', 'hi', 'or', 'bn']) {
        for (final k in keys) {
          final translated = AppStrings.tr(k, lang: lang);
          expect(translated, isNotEmpty, reason: 'Key "$k" should not be empty in $lang');
          if (lang != 'en') {
            expect(translated, isNot(equals(k)),
                reason: 'Key "$k" should be translated into $lang');
          }
        }
      }
    });

    test('Security gate operations dictionary translations exist for all languages', () {
      const keys = [
        'Gate Command Center',
        'Terminal: Main North Gate',
        'VERIFY GATE PASS',
        'Operational Transit Metrics',
        'Awaiting Verification',
        'Students Outside',
        'Exits Today',
        'Returns Today',
        'Secondary Gate Operations',
        'Active Passes',
        'Outside Campus',
        'Pending Sync',
        'Security Profile',
        'Sign Out of Terminal',
      ];

      for (final lang in ['en', 'hi', 'or', 'bn']) {
        for (final k in keys) {
          final translated = AppStrings.tr(k, lang: lang);
          expect(translated, isNotEmpty, reason: 'Key "$k" should not be empty in $lang');
          if (lang != 'en') {
            expect(translated, isNot(equals(k)),
                reason: 'Key "$k" should be translated into $lang');
          }
        }
      }
    });

    test('Warden operations dictionary translations exist for all languages', () {
      const keys = [
        'Campus Warden Command Center',
        'INSTITUTIONAL WARDEN',
        'Student Leave & Pass Control',
        'Operational Overview',
        'Pending Leaves',
        'Visitor Passes',
        'Approved Today',
        'Active Gate Passes',
        'Hostel & Room Triage',
        'Triage',
        'Pending Approvals',
        'View All Leaves',
        'Student Leaves',
        'Warden Profile',
        'Leave Requests Management',
      ];

      for (final lang in ['en', 'hi', 'or', 'bn']) {
        for (final k in keys) {
          final translated = AppStrings.tr(k, lang: lang);
          expect(translated, isNotEmpty, reason: 'Key "$k" should not be empty in $lang');
          if (lang != 'en') {
            expect(translated, isNot(equals(k)),
                reason: 'Key "$k" should be translated into $lang');
          }
        }
      }
    });

    testWidgets('Reactive language switching with .tr(context) updates UI across all roles',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ListenableBuilder(
            listenable: LanguageProvider.instance,
            builder: (context, _) {
              return Scaffold(
                body: Column(
                  children: [
                    Text('Gate Command Center'.tr(context)),
                    Text('Mess Operations'.tr(context)),
                    Text('Start Attendance'.tr(context)),
                    Text('INSTITUTIONAL WARDEN'.tr(context)),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Initially in English
      expect(find.text('Gate Command Center'), findsOneWidget);
      expect(find.text('Mess Operations'), findsOneWidget);
      expect(find.text('Start Attendance'), findsOneWidget);
      expect(find.text('INSTITUTIONAL WARDEN'), findsOneWidget);

      // Switch to Hindi
      await LanguageProvider.instance.setLanguage('hi');
      await tester.pumpAndSettle();

      expect(find.text('गेट कमांड सेंटर'), findsOneWidget);
      expect(find.text('मेस संचालन'), findsOneWidget);
      expect(find.text('उपस्थिति शुरू करें'), findsOneWidget);
      expect(find.text('संस्थानिक वार्डन'), findsOneWidget);

      // Switch to Odia
      await LanguageProvider.instance.setLanguage('or');
      await tester.pumpAndSettle();

      expect(find.text('ଗେଟ୍ କମାଣ୍ଡ ସେଣ୍ଟର'), findsOneWidget);
      expect(find.text('ମେସ୍ ପରିଚାଳନା'), findsOneWidget);
      expect(find.text('ଉପସ୍ଥିତି ଆରମ୍ଭ କରନ୍ତୁ'), findsOneWidget);
      expect(find.text('ସଂସ୍ଥାଗତ ୱାର୍ଡେନ୍'), findsOneWidget);

      // Switch to Bengali
      await LanguageProvider.instance.setLanguage('bn');
      await tester.pumpAndSettle();

      expect(find.text('গেট কমান্ড সেন্টার'), findsOneWidget);
      expect(find.text('মেস কার্যক্রম'), findsOneWidget);
      expect(find.text('উপস্থিতি শুরু করুন'), findsOneWidget);
      expect(find.text('প্রাতিষ্ঠানিক ওয়ার্ডেন'), findsOneWidget);
    });
  });
}
