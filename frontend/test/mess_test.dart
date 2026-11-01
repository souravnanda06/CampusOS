import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/core/network/api_client.dart';
import 'package:attendance_app/student/models/mess_model.dart';
import 'package:attendance_app/student/services/mess_service.dart';
import 'package:attendance_app/student/widgets/mess/meal_card.dart';
import 'package:attendance_app/student/widgets/mess/meal_detail_sheet.dart';
import 'package:attendance_app/student/widgets/mess/meal_feedback_sheet.dart';
import 'package:attendance_app/shared/screens/mess/mess_management_screen.dart';
import 'package:attendance_app/core/network/api_exception.dart';
import 'package:attendance_app/shared/screens/mess/mess_management_detail_screen.dart';
import 'package:attendance_app/shared/screens/mess/mess_composer_screen.dart';
import 'package:attendance_app/shared/screens/mess/mess_feedback_analytics_screen.dart';
import 'package:attendance_app/router/app_routes.dart';

void main() {
  group('MessModel Parsing & Integrity (Steps 22B & 22C)', () {
    test('1. MessMenu parses valid backend JSON', () {
      final jsonMap = {
        "id": "menu-uuid-001",
        "menuDate": "2026-10-01",
        "status": "PUBLISHED",
        "createdBy": "user-admin-1",
        "updatedBy": "user-admin-1",
        "createdAt": "2026-09-25T20:00:00.000",
        "updatedAt": "2026-09-25T20:30:00.000",
        "meals": [
          {
            "id": "meal-uuid-001",
            "menuId": "menu-uuid-001",
            "mealType": "BREAKFAST",
            "title": "Morning Breakfast",
            "description": "Hot breakfast served fresh",
            "items": ["Poha", "Boiled Egg", "Tea"],
            "availability": "AVAILABLE",
            "displayOrder": 1,
            "createdAt": "2026-09-25T20:00:00.000",
            "updatedAt": "2026-09-25T20:30:00.000"
          },
          {
            "id": "meal-uuid-002",
            "menuId": "menu-uuid-001",
            "mealType": "LUNCH",
            "title": "Wholesome Lunch",
            "description": "Standard nutritious meal",
            "items": ["Rice", "Dal", "Curd"],
            "availability": "LIMITED",
            "displayOrder": 2,
            "createdAt": "2026-09-25T20:00:00.000",
            "updatedAt": "2026-09-25T20:30:00.000"
          }
        ]
      };

      final menu = MessMenu.fromMap(jsonMap);

      expect(menu.id, equals('menu-uuid-001'));
      expect(menu.menuDate, equals('2026-10-01'));
      expect(menu.status, equals('PUBLISHED'));
      expect(menu.isPublished, isTrue);
      expect(menu.isDraft, isFalse);
      expect(menu.isArchived, isFalse);
      expect(menu.meals.length, equals(2));
      expect(menu.formattedDate, contains('2026'));
    });

    test('2. MessMeal parses valid backend JSON', () {
      final mealMap = {
        "id": "meal-101",
        "menuId": "menu-101",
        "mealType": "DINNER",
        "title": "Dinner Buffet",
        "description": "South Indian special",
        "items": ["Dosa", "Sambar", "Chutney"],
        "availability": "AVAILABLE",
        "displayOrder": 4,
      };

      final meal = MessMeal.fromMap(mealMap);

      expect(meal.id, equals('meal-101'));
      expect(meal.mealType, equals('DINNER'));
      expect(meal.isDinner, isTrue);
      expect(meal.isBreakfast, isFalse);
      expect(meal.isLunch, isFalse);
      expect(meal.isSnacks, isFalse);
      expect(meal.items, equals(["Dosa", "Sambar", "Chutney"]));
      expect(meal.isAvailable, isTrue);
      expect(meal.isLimited, isFalse);
      expect(meal.isUnavailable, isFalse);
    });

    test('3. Missing optional fields do not crash parsing', () {
      final minimalMap = {
        "id": "menu-min-001",
        "menuDate": "2026-10-02",
      };

      final menu = MessMenu.fromMap(minimalMap);

      expect(menu.id, equals('menu-min-001'));
      expect(menu.status, equals('DRAFT')); // Default fallback
      expect(menu.createdBy, isNull);
      expect(menu.updatedBy, isNull);
      expect(menu.createdAt, isNull);
      expect(menu.updatedAt, isNull);
      expect(menu.meals, isEmpty);

      final minimalMealMap = {
        "id": "meal-min-001",
        "mealType": "SNACKS",
      };

      final meal = MessMeal.fromMap(minimalMealMap);
      expect(meal.title, equals('Snacks'));
      expect(meal.items, isEmpty);
      expect(meal.description, isEmpty);
      expect(meal.availability, equals('AVAILABLE'));
      expect(meal.displayOrder, equals(1));
    });

    test('4. Availability values parse correctly', () {
      final availableMeal = MessMeal.fromMap({
        "id": "1",
        "mealType": "BREAKFAST",
        "availability": "AVAILABLE",
      });
      expect(availableMeal.isAvailable, isTrue);
      expect(availableMeal.isLimited, isFalse);
      expect(availableMeal.isUnavailable, isFalse);

      final limitedMeal = MessMeal.fromMap({
        "id": "2",
        "mealType": "LUNCH",
        "availability": "LIMITED",
      });
      expect(limitedMeal.isAvailable, isFalse);
      expect(limitedMeal.isLimited, isTrue);
      expect(limitedMeal.isUnavailable, isFalse);

      final unavailableMeal = MessMeal.fromMap({
        "id": "3",
        "mealType": "DINNER",
        "availability": "UNAVAILABLE",
      });
      expect(unavailableMeal.isAvailable, isFalse);
      expect(unavailableMeal.isLimited, isFalse);
      expect(unavailableMeal.isUnavailable, isTrue);
    });

    test('5. Empty meals and string-encoded items are handled safely', () {
      final jsonItemsMeal = MessMeal.fromMap({
        "id": "4",
        "mealType": "SNACKS",
        "items": '["Samosa", "Chai"]',
      });
      expect(jsonItemsMeal.items, equals(["Samosa", "Chai"]));

      final commaItemsMeal = MessMeal.fromMap({
        "id": "5",
        "mealType": "SNACKS",
        "items": "Biscuit, Coffee, Water",
      });
      expect(commaItemsMeal.items, equals(["Biscuit", "Coffee", "Water"]));

      final emptyItemsMeal = MessMeal.fromMap({
        "id": "6",
        "mealType": "BREAKFAST",
        "items": [],
      });
      expect(emptyItemsMeal.items, isEmpty);
    });

    test(
        '6. (Req 1) Mess management list model parsing handles multi-status array',
        () {
      final adminMenusJson = [
        {
          "id": "menu-draft-1",
          "menuDate": "2026-10-10",
          "status": "DRAFT",
          "createdBy": "admin-1",
          "meals": [
            {
              "id": "meal-1",
              "mealType": "BREAKFAST",
              "title": "Idli Sambar",
              "items": ["Idli", "Sambar"],
              "availability": "AVAILABLE"
            }
          ]
        },
        {
          "id": "menu-pub-1",
          "menuDate": "2026-10-11",
          "status": "PUBLISHED",
          "createdBy": "warden-1",
          "meals": [
            {
              "id": "meal-2",
              "mealType": "LUNCH",
              "title": "Rice Plate",
              "items": ["Rice", "Dal"],
              "availability": "LIMITED"
            }
          ]
        },
        {
          "id": "menu-arch-1",
          "menuDate": "2026-10-09",
          "status": "ARCHIVED",
          "createdBy": "staff-1",
          "meals": []
        }
      ];

      final menus = adminMenusJson.map((e) => MessMenu.fromMap(e)).toList();

      expect(menus.length, equals(3));
      expect(menus[0].isDraft, isTrue);
      expect(menus[0].meals.first.title, equals('Idli Sambar'));
      expect(menus[1].isPublished, isTrue);
      expect(menus[1].meals.first.isLimited, isTrue);
      expect(menus[2].isArchived, isTrue);
      expect(menus[2].meals, isEmpty);
    });
  });

  group('MessService Management API Calls & Payloads (Step 22C)', () {
    test(
        '7. (Req 2) Draft creation payload is correctly formatted and dispatched',
        () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.url.path, endsWith('/mess/menus'));
        expect(request.headers['X-User-Id'], equals('admin-user-007'));
        expect(request.headers['Content-Type'], contains('application/json'));

        final body = jsonDecode(request.body);
        expect(body['menuDate'], equals('2026-10-15'));
        expect(body['status'], equals('DRAFT'));
        expect(body['meals'], isA<List>());
        expect(body['meals'].length, equals(2));
        expect(body['meals'][0]['mealType'], equals('BREAKFAST'));
        expect(body['meals'][0]['items'], equals(['Poha', 'Tea']));
        expect(body['meals'][1]['mealType'], equals('LUNCH'));

        return http.Response(
          jsonEncode({
            "id": "menu-created-123",
            "menuDate": "2026-10-15",
            "status": "DRAFT",
            "createdBy": "admin-user-007",
            "meals": body['meals'],
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final messService = MessService(apiClient: apiClient);

      final result = await messService.createMenu(
        menuDate: '2026-10-15',
        status: 'DRAFT',
        requesterId: 'admin-user-007',
        meals: [
          {
            'mealType': 'BREAKFAST',
            'title': 'Breakfast',
            'description': '',
            'items': ['Poha', 'Tea'],
            'availability': 'AVAILABLE',
            'displayOrder': 1,
          },
          {
            'mealType': 'LUNCH',
            'title': 'Lunch',
            'description': '',
            'items': ['Rice', 'Dal'],
            'availability': 'AVAILABLE',
            'displayOrder': 2,
          },
        ],
      );

      expect(result.id, equals('menu-created-123'));
      expect(result.isDraft, isTrue);
      expect(result.menuDate, equals('2026-10-15'));
      expect(result.meals.length, equals(2));
    });

    test(
        '8. (Req 3) Draft update payload is correctly formatted and dispatched',
        () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('PUT'));
        expect(request.url.path, endsWith('/mess/menus/menu-edit-456'));
        expect(request.headers['X-User-Id'], equals('staff-user-001'));

        final body = jsonDecode(request.body);
        expect(body['menuDate'], equals('2026-10-16'));
        expect(body['status'], equals('DRAFT'));
        expect(body['meals'][0]['title'], equals('Updated Breakfast'));

        return http.Response(
          jsonEncode({
            "id": "menu-edit-456",
            "menuDate": "2026-10-16",
            "status": "DRAFT",
            "updatedBy": "staff-user-001",
            "meals": body['meals'],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final messService = MessService(apiClient: apiClient);

      final result = await messService.updateMenu(
        'menu-edit-456',
        menuDate: '2026-10-16',
        status: 'DRAFT',
        requesterId: 'staff-user-001',
        meals: [
          {
            'mealType': 'BREAKFAST',
            'title': 'Updated Breakfast',
            'description': 'More items added',
            'items': ['Upma', 'Chai', 'Banana'],
            'availability': 'AVAILABLE',
            'displayOrder': 1,
          }
        ],
      );

      expect(result.id, equals('menu-edit-456'));
      expect(result.menuDate, equals('2026-10-16'));
      expect(result.meals.first.title, equals('Updated Breakfast'));
    });

    test(
        '9. (Req 4) Publish action triggers POST /mess/menus/<id>/publish and parses PUBLISHED',
        () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.url.path, endsWith('/mess/menus/menu-pub-789/publish'));
        expect(request.headers['X-User-Id'], equals('warden-user-002'));

        return http.Response(
          jsonEncode({
            "id": "menu-pub-789",
            "menuDate": "2026-10-18",
            "status": "PUBLISHED",
            "updatedBy": "warden-user-002",
            "meals": [
              {
                "id": "meal-p-1",
                "mealType": "BREAKFAST",
                "title": "Published Breakfast",
                "items": ["Idli", "Vada"],
                "availability": "AVAILABLE"
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final messService = MessService(apiClient: apiClient);

      final result = await messService.publishMenu('menu-pub-789',
          requesterId: 'warden-user-002');

      expect(result.id, equals('menu-pub-789'));
      expect(result.isPublished, isTrue);
      expect(result.status, equals('PUBLISHED'));
    });

    test(
        '10. (Req 5) Archive action triggers POST /mess/menus/<id>/archive and parses ARCHIVED',
        () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.url.path, endsWith('/mess/menus/menu-arc-999/archive'));
        expect(request.headers['X-User-Id'], equals('admin-user-001'));

        return http.Response(
          jsonEncode({
            "id": "menu-arc-999",
            "menuDate": "2026-10-18",
            "status": "ARCHIVED",
            "updatedBy": "admin-user-001",
            "meals": [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final messService = MessService(apiClient: apiClient);

      final result = await messService.archiveMenu('menu-arc-999',
          requesterId: 'admin-user-001');

      expect(result.id, equals('menu-arc-999'));
      expect(result.isArchived, isTrue);
      expect(result.status, equals('ARCHIVED'));
    });

    test(
        '11. (Req 6) Backend error handling: 409 Conflict, 403 Forbidden, 400 Bad Request, 500 Server Error',
        () async {
      // 409 Conflict (e.g. duplicate published menu on same date)
      final conflictClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            "message":
                "A published menu already exists for date 2026-10-15. Archive or unpublish the existing menu first."
          }),
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      final conflictService =
          MessService(apiClient: ApiClient(client: conflictClient));

      expect(
        () async => await conflictService.publishMenu('menu-dup',
            requesterId: 'admin-1'),
        throwsA(contains('A published menu already exists')),
      );

      // 403 Forbidden (e.g. unauthorized teacher or student role)
      final forbiddenClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            "message": "Access forbidden: requires ADMIN, STAFF, or WARDEN role"
          }),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final forbiddenService =
          MessService(apiClient: ApiClient(client: forbiddenClient));

      expect(
        () async =>
            await forbiddenService.getAdminMenus(requesterId: 'teacher-1'),
        throwsA(contains('Access forbidden')),
      );

      // 400 Bad Request (validation failure)
      final badRequestClient = MockClient((request) async {
        return http.Response(
          jsonEncode(
              {"message": "Validation error: at least one meal is required"}),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final badRequestService =
          MessService(apiClient: ApiClient(client: badRequestClient));

      expect(
        () async => await badRequestService.createMenu(
          menuDate: '2026-10-20',
          requesterId: 'admin-1',
          meals: [],
        ),
        throwsA(contains('Validation error')),
      );
    });
  });

  group('Widget & Role Gating Tests (Step 22C)', () {
    testWidgets(
        '12. (Req 7) Empty management list renders "No Menus Found" empty state',
        (WidgetTester tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/mess/admin/menus')) {
          return http.Response(
            jsonEncode([]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final adminUser = UserModel(
        id: 'admin-test-01',
        email: 'admin@campus.edu',
        name: 'Chief Administrator',
        role: 'admin',
      );

      final service = MessService(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: MessManagementScreen(
            user: adminUser,
            messService: service,
          ),
        ),
      );

      await tester.pump(); // Start fetching
      await tester.pump(const Duration(milliseconds: 300)); // Finish loading

      expect(find.text("Mess Management"), findsOneWidget);
      expect(find.text("No Menus Found"), findsOneWidget);
    });

    testWidgets(
        '13. (Req 8) Status rendering: DRAFT, PUBLISHED, ARCHIVED badges display clearly',
        (WidgetTester tester) async {
      final sampleMenus = [
        {
          "id": "menu-draft-01",
          "menuDate": "2026-10-21",
          "status": "DRAFT",
          "createdBy": "admin-1",
          "meals": [
            {
              "id": "m1",
              "mealType": "BREAKFAST",
              "title": "Morning Upma",
              "items": ["Upma", "Chutney"],
              "availability": "AVAILABLE"
            }
          ]
        },
        {
          "id": "menu-pub-01",
          "menuDate": "2026-10-22",
          "status": "PUBLISHED",
          "createdBy": "admin-1",
          "meals": [
            {
              "id": "m2",
              "mealType": "LUNCH",
              "title": "Full Thali",
              "items": ["Rice", "Sambar"],
              "availability": "AVAILABLE"
            }
          ]
        },
        {
          "id": "menu-arch-01",
          "menuDate": "2026-10-20",
          "status": "ARCHIVED",
          "createdBy": "admin-1",
          "meals": []
        }
      ];

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/mess/admin/menus')) {
          return http.Response(
            jsonEncode(sampleMenus),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final adminUser = UserModel(
        id: 'admin-test-02',
        email: 'admin@campus.edu',
        name: 'Warden Smith',
        role: 'warden',
      );

      final service = MessService(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: MessManagementScreen(
            user: adminUser,
            messService: service,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The "All" tab should render all 3 menus with their badges
      // Note: TabBar also contains tabs "Published" and "Archived", so there are 2 widgets each
      expect(find.text("Draft"), findsOneWidget);
      expect(find.text("Published"), findsNWidgets(2));
      expect(find.text("Archived"), findsNWidgets(2));
    });

    testWidgets(
        '14. (Req 9) Composer validation: blocks empty submissions with SnackBar feedback',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final adminUser = UserModel(
        id: 'admin-test-03',
        email: 'admin@campus.edu',
        name: 'Staff Manager',
        role: 'staff',
      );

      // We mount composer with an empty menu (0 meals)
      final emptyMenu = MessMenu(
        id: 'menu-empty-draft',
        menuDate: '2026-10-25',
        status: 'DRAFT',
        meals: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessComposerScreen(
              user: adminUser,
              menu: emptyMenu,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "Save Draft" while all 4 meals are disabled in this emptyMenu
      final saveDraftButton = find.text("Save Draft");
      expect(saveDraftButton, findsOneWidget);

      await tester.tap(saveDraftButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Form validation should trigger SnackBar warning
      expect(
        find.text("At least one meal must be configured for the menu."),
        findsOneWidget,
      );
    });

    testWidgets(
        '15. (Req 10) Role-gated management visibility: blocks Teachers & Students',
        (WidgetTester tester) async {
      int apiCallCount = 0;
      final mockClient = MockClient((request) async {
        apiCallCount++;
        return http.Response(jsonEncode([]), 200,
            headers: {'content-type': 'application/json'});
      });

      final teacherUser = UserModel(
        id: 'teacher-001',
        email: 'prof.sharma@campus.edu',
        name: 'Prof. Sharma',
        role: 'teacher',
      );

      final service = MessService(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: MessManagementScreen(
            user: teacherUser,
            messService: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Teacher should be strictly blocked:
      expect(find.text("Access Restricted"), findsOneWidget);
      expect(find.text("Go Back"), findsOneWidget);
      expect(
        find.textContaining(
            "Mess management requires Staff, Warden, or Administrator"),
        findsOneWidget,
      );
      // Backend management API must NOT have been called
      expect(apiCallCount, equals(0));

      // Test Student user role restriction as well:
      final studentUser = UserModel(
        id: 'student-001',
        email: 'rahul@campus.edu',
        name: 'Rahul Student',
        role: 'student',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MessManagementScreen(
            user: studentUser,
            messService: service,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text("Access Restricted"), findsOneWidget);
      expect(apiCallCount, equals(0));
    });

    test(
        '16. (Req 11) Route constants: AppRoutes preserves studentMess and adds Step 22C routes',
        () {
      // Step 22B student route must remain intact:
      expect(AppRoutes.studentMess, equals('/student/mess'));

      // Step 22C management routes:
      expect(AppRoutes.messManagement, equals('/shared/mess/management'));
      expect(AppRoutes.messComposer, equals('/shared/mess/composer'));
      expect(AppRoutes.messDetail, equals('/shared/mess/detail'));

      // Core routes preserved:
      expect(AppRoutes.home, equals('/home'));
      expect(AppRoutes.adminDashboard, equals('/admin/dashboard'));
      expect(AppRoutes.teacherClasses, equals('/teacher/classes'));
      expect(AppRoutes.studentReady, equals('/student/ready'));
    });

    testWidgets(
        '17. Published meal renders correctly in MealCard (Step 22B regression)',
        (WidgetTester tester) async {
      final meal = MessMeal(
        id: "meal-w-1",
        menuId: "menu-w-1",
        mealType: "BREAKFAST",
        title: "Morning Delight",
        description: "Served hot with chutney",
        items: ["Poha", "Boiled Egg", "Tea"],
        availability: "AVAILABLE",
        displayOrder: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MealCard(meal: meal),
          ),
        ),
      );

      expect(find.text("BREAKFAST"), findsOneWidget);
      expect(find.text("Morning Delight"), findsOneWidget);
      expect(find.text("Served hot with chutney"), findsOneWidget);
      expect(find.text("Poha"), findsOneWidget);
      expect(find.text("Boiled Egg"), findsOneWidget);
      expect(find.text("Tea"), findsOneWidget);
      expect(find.text("Available"), findsOneWidget);
    });

    testWidgets(
        '18. MealDetailSheet opens and displays items checklist (Step 22B regression)',
        (WidgetTester tester) async {
      final meal = MessMeal(
        id: "meal-w-2",
        menuId: "menu-w-2",
        mealType: "LUNCH",
        title: "Executive Thali",
        description: "Chef's special preparation",
        items: ["Paneer Curry", "Roti", "Jeera Rice"],
        availability: "LIMITED",
        displayOrder: 2,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    MealDetailSheet.show(
                      context,
                      meal: meal,
                      menuDate: "2026-10-01",
                    );
                  },
                  child: const Text("Open Sheet"),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open Sheet"));
      await tester.pumpAndSettle();

      expect(find.text("Executive Thali"), findsOneWidget);
      expect(find.text("Chef's special preparation"), findsOneWidget);
      expect(find.text("Meal Items (3)"), findsOneWidget);
      expect(find.text("Paneer Curry"), findsOneWidget);
      expect(find.text("Limited Availability"), findsOneWidget);
      expect(find.text("Close"), findsOneWidget);

      await tester.tap(find.text("Close"));
      await tester.pumpAndSettle();
      expect(find.text("Meal Items (3)"), findsNothing);
    });
  });

  // ==============================================================================
  // STEP 22D: MESS FEEDBACK, RATINGS & ANALYTICS TESTS
  // ==============================================================================
  group('Step 22D: Mess Feedback, Ratings & Analytics', () {
    test(
        '19. MessFeedback parses valid backend JSON and formats category labels',
        () {
      final jsonMap = {
        "id": "fb-001",
        "menuId": "menu-101",
        "mealId": "meal-202",
        "studentId": "student-303",
        "rating": 4,
        "category": "FOOD_QUALITY",
        "comment": "Food was fresh and warm",
        "mealType": "LUNCH",
        "mealTitle": "Wholesome Lunch",
        "menuDate": "2026-10-01",
        "createdAt": "2026-10-01T12:00:00.000",
        "updatedAt": "2026-10-01T12:00:00.000"
      };

      final fb = MessFeedback.fromMap(jsonMap);

      expect(fb.id, equals('fb-001'));
      expect(fb.menuId, equals('menu-101'));
      expect(fb.mealId, equals('meal-202'));
      expect(fb.studentId, equals('student-303'));
      expect(fb.rating, equals(4));
      expect(fb.category, equals('FOOD_QUALITY'));
      expect(fb.categoryLabel, equals('Food Quality'));
      expect(fb.comment, equals('Food was fresh and warm'));
      expect(fb.mealType, equals('LUNCH'));
      expect(fb.mealTitle, equals('Wholesome Lunch'));
      expect(fb.menuDate, equals('2026-10-01'));
      expect(fb.createdAt, isNotNull);

      final map = fb.toMap();
      expect(map['rating'], equals(4));
      expect(map['category'], equals('FOOD_QUALITY'));
    });

    test(
        '20. FeedbackSummary correctly parses star distributions and meal breakdown',
        () {
      final summaryMap = {
        "totalRatings": 15,
        "feedbackCount": 15,
        "averageRating": 4.2,
        "totalComments": 8,
        "ratingDistribution": {"1": 1, "2": 1, "3": 2, "4": 5, "5": 6},
        "mealBreakdown": {
          "BREAKFAST": {"count": 4, "averageRating": 4.5},
          "LUNCH": {"count": 6, "averageRating": 3.8},
          "SNACKS": {"count": 2, "averageRating": 4.0},
          "DINNER": {"count": 3, "averageRating": 4.3}
        }
      };

      final summary = FeedbackSummary.fromMap(summaryMap);

      expect(summary.totalRatings, equals(15));
      expect(summary.feedbackCount, equals(15));
      expect(summary.averageRating, equals(4.2));
      expect(summary.totalComments, equals(8));
      expect(summary.ratingDistribution[5], equals(6));
      expect(summary.ratingDistribution[1], equals(1));
      expect(summary.mealBreakdown['BREAKFAST']?.count, equals(4));
      expect(summary.mealBreakdown['BREAKFAST']?.averageRating, equals(4.5));
      expect(summary.mealBreakdown['LUNCH']?.averageRating, equals(3.8));
    });

    test(
        '21. FeedbackSignal correctly identifies flagged categories with rule reason',
        () {
      final flaggedSignalMap = {
        "category": "CLEANLINESS",
        "feedbackCount": 4,
        "averageRating": 2.25,
        "negativeCount": 3,
        "negativePercentage": 75.0,
        "flagged": true,
        "flagReason":
            "High negative ratings (75.0% <= 2 stars), Average rating below 3.0 (2.25/5)"
      };

      final normalSignalMap = {
        "category": "TASTE",
        "feedbackCount": 5,
        "averageRating": 4.6,
        "negativeCount": 0,
        "negativePercentage": 0.0,
        "flagged": false,
        "flagReason": ""
      };

      final flaggedSig = FeedbackSignal.fromMap(flaggedSignalMap);
      expect(flaggedSig.category, equals('CLEANLINESS'));
      expect(flaggedSig.label, equals('Cleanliness'));
      expect(flaggedSig.flagged, isTrue);
      expect(flaggedSig.negativePercentage, equals(75.0));
      expect(flaggedSig.flagReason, contains('75.0%'));

      final normalSig = FeedbackSignal.fromMap(normalSignalMap);
      expect(normalSig.label, equals('Taste'));
      expect(normalSig.flagged, isFalse);
    });

    test(
        '22. MessService: submitFeedback issues POST /mess/feedback with payload',
        () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.url.path, endsWith('/mess/feedback'));
        expect(request.headers['X-User-Id'], equals('student-101'));

        final body = jsonDecode(request.body);
        expect(body['menuId'], equals('menu-uuid-1'));
        expect(body['mealId'], equals('meal-uuid-1'));
        expect(body['rating'], equals(5));
        expect(body['category'], equals('TASTE'));
        expect(body['comment'], equals('Great dessert!'));

        return http.Response(
          jsonEncode({
            "id": "fb-new-999",
            "menuId": body['menuId'],
            "mealId": body['mealId'],
            "studentId": "student-101",
            "rating": 5,
            "category": "TASTE",
            "comment": "Great dessert!",
            "createdAt": "2026-10-01T12:00:00.000",
            "updatedAt": "2026-10-01T12:00:00.000"
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final messService = MessService(apiClient: apiClient);

      final result = await messService.submitFeedback(
        menuId: 'menu-uuid-1',
        mealId: 'meal-uuid-1',
        rating: 5,
        category: 'TASTE',
        comment: 'Great dessert!',
        requesterId: 'student-101',
      );

      expect(result.id, equals('fb-new-999'));
      expect(result.rating, equals(5));
      expect(result.category, equals('TASTE'));
    });

    test('23. MessService: getMyFeedback fetches student feedback entries',
        () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('GET'));
        expect(request.url.path, endsWith('/mess/feedback/my'));
        expect(request.headers['X-User-Id'], equals('student-101'));

        return http.Response(
          jsonEncode([
            {
              "id": "fb-my-1",
              "menuId": "menu-1",
              "mealId": "meal-1",
              "rating": 4,
              "category": "PORTION",
              "comment": "Good portion",
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final messService = MessService(apiClient: apiClient);

      final myFeedback =
          await messService.getMyFeedback(requesterId: 'student-101');
      expect(myFeedback.length, equals(1));
      expect(myFeedback[0].id, equals('fb-my-1'));
      expect(myFeedback[0].rating, equals(4));
    });

    test('24. MessService: updateFeedback issues PUT /mess/feedback/<id>',
        () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('PUT'));
        expect(request.url.path, endsWith('/mess/feedback/fb-my-1'));
        expect(request.headers['X-User-Id'], equals('student-101'));

        final body = jsonDecode(request.body);
        expect(body['rating'], equals(3));
        expect(body['comment'], equals('Updated review comment'));

        return http.Response(
          jsonEncode({
            "id": "fb-my-1",
            "menuId": "menu-1",
            "mealId": "meal-1",
            "rating": 3,
            "category": "PORTION",
            "comment": "Updated review comment",
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final messService = MessService(apiClient: apiClient);

      final updated = await messService.updateFeedback(
        'fb-my-1',
        rating: 3,
        category: 'PORTION',
        comment: 'Updated review comment',
        requesterId: 'student-101',
      );

      expect(updated.rating, equals(3));
      expect(updated.comment, equals('Updated review comment'));
    });

    test(
        '25. MessService: getFeedbackSummary transmits filters to admin endpoint',
        () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('GET'));
        expect(request.url.path, endsWith('/mess/admin/feedback/summary'));
        expect(request.url.queryParameters['startDate'], equals('2026-10-01'));
        expect(request.url.queryParameters['endDate'], equals('2026-10-07'));
        expect(request.url.queryParameters['mealType'], equals('LUNCH'));
        expect(request.headers['X-User-Id'], equals('admin-user-01'));

        return http.Response(
          jsonEncode({
            "totalRatings": 10,
            "feedbackCount": 10,
            "averageRating": 4.1,
            "totalComments": 4,
            "ratingDistribution": {"1": 0, "2": 1, "3": 1, "4": 4, "5": 4},
            "mealBreakdown": {
              "LUNCH": {"count": 10, "averageRating": 4.1}
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final messService = MessService(apiClient: apiClient);

      final summary = await messService.getFeedbackSummary(
        startDate: '2026-10-01',
        endDate: '2026-10-07',
        mealType: 'LUNCH',
        requesterId: 'admin-user-01',
      );

      expect(summary.totalRatings, equals(10));
      expect(summary.averageRating, equals(4.1));
    });

    testWidgets(
        '26. MealFeedbackSheet renders interactive rating stars and submit button',
        (WidgetTester tester) async {
      final meal = MessMeal(
        id: "meal-fb-1",
        menuId: "menu-fb-1",
        mealType: "DINNER",
        title: "South Indian Dinner",
        description: "Served hot",
        items: ["Dosa", "Sambar"],
        availability: "AVAILABLE",
        displayOrder: 4,
      );

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            "id": "fb-new-999",
            "menuId": "menu-fb-1",
            "mealId": "meal-fb-1",
            "studentId": "student-101",
            "rating": 5,
            "category": "TASTE",
            "comment": "Delicious chutney and crisp dosa!",
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final messService = MessService(apiClient: ApiClient(client: mockClient));

      MessFeedback? savedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    MealFeedbackSheet.show(
                      context,
                      meal: meal,
                      menuDate: "2026-10-01",
                      requesterId: "student-101",
                      messService: messService,
                      onFeedbackSaved: (saved) {
                        savedResult = saved;
                      },
                    );
                  },
                  child: const Text("Rate Meal"),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text("Rate Meal"));
      await tester.pumpAndSettle();

      expect(find.text("Rate This Meal"), findsOneWidget);
      expect(find.text("DINNER • South Indian Dinner"), findsOneWidget);
      expect(find.text("Food Quality"), findsOneWidget);
      expect(find.text("Taste"), findsOneWidget);
      expect(find.text("Cleanliness"), findsOneWidget);
      expect(find.text("Submit Feedback"), findsOneWidget);

      // Select category chip "Taste"
      await tester.tap(find.text("Taste"));
      await tester.pumpAndSettle();

      // Enter comment
      await tester.enterText(
          find.byType(TextField), "Delicious chutney and crisp dosa!");
      await tester.pumpAndSettle();

      // Submit
      await tester.ensureVisible(find.text("Submit Feedback"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Submit Feedback"));
      await tester.pumpAndSettle();

      expect(savedResult, isNotNull);
      expect(savedResult?.rating, equals(5));
      expect(savedResult?.category, equals("TASTE"));
      expect(savedResult?.comment, equals("Delicious chutney and crisp dosa!"));
    });

    testWidgets(
        '27. MealFeedbackSheet edit mode shows existing rating and Update button',
        (WidgetTester tester) async {
      final meal = MessMeal(
        id: "meal-fb-2",
        menuId: "menu-fb-2",
        mealType: "BREAKFAST",
        title: "Morning Poha",
        description: "Freshly made",
        items: ["Poha", "Tea"],
        availability: "AVAILABLE",
        displayOrder: 1,
      );

      final existingFb = MessFeedback(
        id: "fb-exist-1",
        menuId: "menu-fb-2",
        mealId: "meal-fb-2",
        rating: 3,
        category: "PORTION",
        comment: "Portion size was small",
      );

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            "id": "fb-exist-1",
            "menuId": "menu-fb-2",
            "mealId": "meal-fb-2",
            "rating": 3,
            "category": "PORTION",
            "comment": "Portion size was small",
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final messService = MessService(apiClient: ApiClient(client: mockClient));

      MessFeedback? updatedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    MealFeedbackSheet.show(
                      context,
                      meal: meal,
                      menuDate: "2026-10-01",
                      requesterId: "student-101",
                      existingFeedback: existingFb,
                      messService: messService,
                      onFeedbackSaved: (saved) {
                        updatedResult = saved;
                      },
                    );
                  },
                  child: const Text("Show Sheet"),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text("Show Sheet"));
      await tester.pumpAndSettle();

      // Initially shows view mode
      expect(find.text("Your Meal Feedback"), findsOneWidget);
      expect(find.text("Edit"), findsOneWidget);

      // Tap Edit Feedback to enter edit mode
      await tester.tap(find.text("Edit"));
      await tester.pumpAndSettle();

      expect(find.text("Rate This Meal"), findsOneWidget);
      expect(find.text("BREAKFAST • Morning Poha"), findsOneWidget);
      expect(find.text("Update Feedback"), findsOneWidget);
      expect(find.text("Portion size was small"), findsOneWidget);

      await tester.ensureVisible(find.text("Update Feedback"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Update Feedback"));
      await tester.pumpAndSettle();

      expect(updatedResult, isNotNull);
      expect(updatedResult?.rating, equals(3));
      expect(updatedResult?.comment, equals("Portion size was small"));
    });

    testWidgets('28. MealCard displays user rating status badge',
        (WidgetTester tester) async {
      final meal = MessMeal(
        id: "meal-card-fb-1",
        menuId: "menu-1",
        mealType: "LUNCH",
        title: "Deluxe Lunch",
        description: "Nutritious meal",
        items: ["Rice", "Dal", "Paneer"],
        availability: "AVAILABLE",
        displayOrder: 2,
      );

      final userFb = MessFeedback(
        id: "fb-c-1",
        menuId: "menu-1",
        mealId: "meal-card-fb-1",
        rating: 4,
        category: "FOOD_QUALITY",
        comment: "Good taste",
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MealCard(
              meal: meal,
              feedback: userFb,
            ),
          ),
        ),
      );

      expect(find.text("4/5"), findsOneWidget);
      expect(find.text("Food Quality"), findsOneWidget);
    });

    testWidgets(
        '29. MessFeedbackAnalyticsScreen renders summary and distribution for authorized Admin',
        (WidgetTester tester) async {
      final adminUser = UserModel(
        id: 'admin-001',
        email: 'admin@campus.edu',
        name: 'System Admin',
        role: 'admin',
      );

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/mess/admin/feedback/summary')) {
          return http.Response(
            jsonEncode({
              "totalRatings": 20,
              "feedbackCount": 20,
              "averageRating": 4.3,
              "totalComments": 5,
              "ratingDistribution": {"1": 0, "2": 1, "3": 2, "4": 7, "5": 10},
              "mealBreakdown": {
                "BREAKFAST": {"count": 5, "averageRating": 4.6},
                "LUNCH": {"count": 8, "averageRating": 4.1},
                "SNACKS": {"count": 3, "averageRating": 4.0},
                "DINNER": {"count": 4, "averageRating": 4.5}
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('/mess/admin/feedback/trends')) {
          return http.Response(
            jsonEncode({"trends": []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path
            .contains('/mess/admin/feedback/categories')) {
          return http.Response(
            jsonEncode({"categories": [], "signals": []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('/mess/admin/feedback/comments')) {
          return http.Response(
            jsonEncode([]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      });

      final apiClient = ApiClient(client: mockClient);
      final messService = MessService(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: MessFeedbackAnalyticsScreen(
            user: adminUser,
            messService: messService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Feedback Analytics"), findsOneWidget);
      expect(find.text("Average Rating"), findsOneWidget);
      expect(find.text("4.3"), findsOneWidget);
      expect(find.text("Total Ratings"), findsOneWidget);
      expect(find.text("20"), findsNWidgets(2));
      expect(find.text("Rating Distribution"), findsOneWidget);

      await tester.drag(
          find.text("Rating Distribution"), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text("Meal Breakdown"), findsOneWidget);
      expect(find.text("Breakfast"), findsWidgets);
      expect(find.text("Lunch"), findsWidgets);
    });

    testWidgets(
        '30. MessFeedbackAnalyticsScreen blocks Student access with Access Restricted',
        (WidgetTester tester) async {
      final studentUser = UserModel(
        id: 'student-999',
        email: 'student@campus.edu',
        name: 'Student Consumer',
        role: 'student',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MessFeedbackAnalyticsScreen(
            user: studentUser,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Access Restricted"), findsOneWidget);
      expect(find.text("Go Back"), findsOneWidget);
    });

    test('31. AppRoutes includes messFeedback route constant', () {
      expect(AppRoutes.messFeedback, equals('/shared/mess/feedback'));
    });
  });

  group('Step 22E: Mess Integration, Hardening & Error Handling', () {
    test('32. MessService.sanitizeError formats standard error scenarios cleanly', () {
      expect(
        MessService.sanitizeError(const ApiException(
          message: 'A published menu already exists for date 2026-10-15',
          statusCode: 409,
        )),
        equals('Another published menu already exists for this date.'),
      );

      expect(
        MessService.sanitizeError(const ApiException(
          message: 'Access forbidden',
          statusCode: 403,
        )),
        equals("You don't have permission to perform this action."),
      );

      expect(
        MessService.sanitizeError(const ApiException(
          message: 'Menu not found',
          statusCode: 404,
        )),
        equals('Menu not found'),
      );

      expect(
        MessService.sanitizeError(const ApiException(
          message: 'Internal server error',
          statusCode: 500,
        )),
        equals('Unable to connect. Check your connection and try again.'),
      );

      expect(
        MessService.sanitizeError('SocketException: OS Error: Connection refused'),
        equals('Unable to connect. Check your connection and try again.'),
      );

      expect(
        MessService.sanitizeError('TimeoutException after 0:00:10.000000: Connection timed out'),
        equals('Unable to connect. Check your connection and try again.'),
      );
    });

    testWidgets('33. MealFeedbackSheet rating stars render semantic accessibility labels', (WidgetTester tester) async {
      final sampleMeal = MessMeal(
        id: 'meal-semantic-1',
        menuId: 'menu-semantic-1',
        mealType: 'BREAKFAST',
        title: 'Accessibility Poha',
        items: ['Poha', 'Chai'],
        availability: 'AVAILABLE',
        displayOrder: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MealFeedbackSheet(
              meal: sampleMeal,
              menuDate: '2026-10-15',
              requesterId: 'student-acc-1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('1 star'), findsOneWidget);
      expect(find.byTooltip('2 stars'), findsOneWidget);
      expect(find.byTooltip('3 stars'), findsOneWidget);
      expect(find.byTooltip('4 stars'), findsOneWidget);
      expect(find.byTooltip('5 stars'), findsOneWidget);
      expect(find.text("Rate This Meal"), findsOneWidget);
    });

    testWidgets('34. MealCard renders semantic labels for rate and edit actions', (WidgetTester tester) async {
      final testMeal = MessMeal(
        id: 'meal-card-1',
        menuId: 'menu-card-1',
        mealType: 'LUNCH',
        title: 'Veggie Thali',
        items: ['Rice', 'Dal', 'Roti'],
        availability: 'AVAILABLE',
        displayOrder: 2,
      );

      bool tappedRate = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MealCard(
              meal: testMeal,
              onRateTap: () {
                tappedRate = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Available"), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);

      final rateMealSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Rate meal for LUNCH Veggie Thali',
      );
      expect(rateMealSemantics, findsOneWidget);

      await tester.tap(find.text("Rate meal"));
      expect(tappedRate, isTrue);
    });

    testWidgets('35. MessManagementDetailScreen wraps Scaffold with PopScope for reliable back navigation', (WidgetTester tester) async {
      final adminUser = UserModel(
        id: 'admin-detail-1',
        email: 'admin@campus.edu',
        name: 'Mess Manager',
        role: 'admin',
      );

      final draftMenu = MessMenu(
        id: 'menu-detail-draft',
        menuDate: '2026-10-25',
        status: 'DRAFT',
        meals: [
          MessMeal(
            id: 'meal-d-1',
            menuId: 'menu-detail-draft',
            mealType: 'BREAKFAST',
            title: 'Paratha',
            items: ['Paratha', 'Dahi'],
            availability: 'AVAILABLE',
            displayOrder: 1,
          )
        ],
      );

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(draftMenu.toMap()), 200, headers: {'content-type': 'application/json'});
      });

      final apiClient = ApiClient(client: mockClient);
      final messService = MessService(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: MessManagementDetailScreen(
            user: adminUser,
            menu: draftMenu,
            messService: messService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((w) => w is PopScope), findsOneWidget);
      expect(find.text("Menu Detail"), findsOneWidget);
      expect(find.text("Draft"), findsOneWidget);
      expect(find.text("Publish"), findsOneWidget);
      expect(find.text("Archive Draft"), findsOneWidget);
    });

    testWidgets('36. MessManagementScreen initializes and fetches menus', (WidgetTester tester) async {
      final adminUser = UserModel(
        id: 'admin-reload-1',
        email: 'admin@campus.edu',
        name: 'Admin Reload',
        role: 'admin',
      );

      int fetchCount = 0;
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/mess/admin/menus')) {
          fetchCount++;
          return http.Response(jsonEncode([]), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      });

      final apiClient = ApiClient(client: mockClient);
      final messService = MessService(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: MessManagementScreen(
            user: adminUser,
            messService: messService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fetchCount, equals(1));
      expect(find.text("New Menu"), findsOneWidget);
    });
  });
}
