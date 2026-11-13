import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/student/models/career_models.dart';
import 'package:attendance_app/student/screens/career_hub_screen.dart';

void main() {
  group('Career Models Test Suite', () {
    test('PlacementDriveModel parsing and eligibility', () {
      final json = {
        "id": "drive_001",
        "companyName": "Oracle Cloud",
        "roleTitle": "Cloud Engineer",
        "jobDescription": "Build distributed cloud systems.",
        "location": "Bhubaneswar",
        "ctcBreakdown": "₹14.5 LPA",
        "targetBatches": ["2026"],
        "eligibleBranches": ["CSE", "IT"],
        "minCgpa": 7.5,
        "maxActiveBacklogs": 0,
        "minAttendancePercent": 75.0,
        "driveDate": "2026-11-25",
        "registrationDeadline": "2026-11-20",
        "venue": "Main Hall",
        "status": "UPCOMING",
        "isEligible": true,
        "hasApplied": false
      };

      final model = PlacementDriveModel.fromJson(json);
      expect(model.id, "drive_001");
      expect(model.companyName, "Oracle Cloud");
      expect(model.isEligible, isTrue);
      expect(model.minCgpa, 7.5);
      expect(model.targetBatches, contains("2026"));
    });

    test('OpportunityListingModel parsing', () {
      final json = {
        "id": "opp_001",
        "sourceType": "EXTERNAL_REMOTIVE",
        "title": "Flutter Developer Intern",
        "companyName": "Remote Tech Labs",
        "location": "Remote",
        "workMode": "REMOTE",
        "employmentType": "INTERNSHIP",
        "experienceLevel": "INTERN",
        "skills": ["Flutter", "Dart", "REST API"],
        "salaryRange": "₹40,000 / month",
        "description": "Develop mobile UI with clean state management.",
        "applyUrl": "https://remotive.com",
        "status": "ACTIVE",
        "isTracked": true
      };

      final model = OpportunityListingModel.fromJson(json);
      expect(model.id, "opp_001");
      expect(model.title, "Flutter Developer Intern");
      expect(model.workMode, "REMOTE");
      expect(model.skills, contains("Flutter"));
      expect(model.isTracked, isTrue);
    });

    test('CareerHubSummaryModel parsing', () {
      final json = {
        "activeDrivesCount": 3,
        "externalOpportunitiesCount": 12,
        "studentAtsScore": 86,
        "applicationsCount": 2,
        "hasResume": true
      };

      final summary = CareerHubSummaryModel.fromJson(json);
      expect(summary.activeDrivesCount, 3);
      expect(summary.externalOpportunitiesCount, 12);
      expect(summary.studentAtsScore, 86);
      expect(summary.hasResume, isTrue);
    });
  });

  group('CareerHubScreen UI Rendering', () {
    testWidgets('Renders Segmented Tabs and Title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CareerHubScreen(initialTabIndex: 0),
        ),
      );
      await tester.pump();

      // Verify Screen Header
      expect(find.text("Career & Placements"), findsOneWidget);

      // Verify 3 Segmented Tabs
      expect(find.text("Campus Drives"), findsOneWidget);
      expect(find.text("Explore Jobs"), findsOneWidget);
      expect(find.text("Career Passport"), findsOneWidget);

      // Verify tab selection interaction
      await tester.tap(find.text("Career Passport"));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });
}
