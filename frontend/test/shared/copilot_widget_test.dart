import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/shared/models/copilot_models.dart';
import 'package:attendance_app/shared/providers/copilot_provider.dart';
import 'package:attendance_app/shared/services/copilot_service.dart';
import 'package:attendance_app/shared/widgets/copilot/copilot_action_card.dart';
import 'package:attendance_app/shared/widgets/copilot/copilot_sheet.dart';
import 'package:attendance_app/shared/widgets/dock/app_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  UserModel makeUser(String role, String name) => UserModel(
        id: 'user_$role',
        email: '$role@campusos.test',
        name: name,
        role: role,
      );

  testWidgets('Raised center Campus AI button in AppDock opens role-scoped Campus AI sheet',
      (tester) async {
    for (final entry in [
      ('student', 'Campus AI · Student', 'Aarav'),
      ('teacher', 'Campus AI · Teacher', 'Prof. Rao'),
      ('admin', 'Campus AI · Admin', 'Dean Sharma'),
    ]) {
      final role = entry.$1;
      final expectedTitle = entry.$2;
      final name = entry.$3;

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => CopilotProvider(),
          child: MaterialApp(
            home: Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: Builder(
                builder: (ctx) => AppDock(
                  currentIndex: 0,
                  onTap: (_) {},
                  centerAction: AppDockCenterAction(
                    buttonKey: Key('campus_ai_dock_$role'),
                    label: 'Campus AI',
                    onTap: () => CopilotSheet.show(
                      ctx,
                      user: makeUser(role, name),
                      role: role,
                      screenContext: '${role}_home',
                    ),
                  ),
                  items: const [
                    AppDockItem(icon: Icons.home_outlined, label: 'Home'),
                    AppDockItem(icon: Icons.inbox_outlined, label: 'Tab 2'),
                    AppDockItem(icon: Icons.bar_chart_outlined, label: 'Tab 3'),
                    AppDockItem(icon: Icons.person_outline, label: 'Profile'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final aiBtnFinder = find.byKey(Key('campus_ai_dock_$role'));
      expect(aiBtnFinder, findsOneWidget);
      expect(find.text('Campus AI'), findsOneWidget);

      await tester.tap(aiBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text(expectedTitle), findsOneWidget);
      expect(find.text('TRY ASKING'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('CopilotActionCard confirms and updates status badge', (tester) async {
    final action = CopilotPendingAction(
      actionId: 'act_123',
      actionType: 'SUBMIT_LEAVE_REQUEST',
      title: 'Submit Leave Request',
      summary: 'HOME_VISIT from 2026-11-14 to 2026-11-15',
      payload: const {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return CopilotActionCard(
                action: action,
                onConfirm: () {
                  setState(() {
                    action.status = CopilotActionStatus.executed;
                    action.executionMessage = 'Leave request submitted.';
                  });
                },
                onDismiss: () {},
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Confirm & Execute'), findsOneWidget);
    await tester.tap(find.text('Confirm & Execute'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Leave request submitted.'), findsOneWidget);
  });

  test('CopilotService provides role-specific default suggestions', () {
    final svc = CopilotService.instance;
    expect(svc.defaultSuggestionsForRole('student').first.label, contains('75%'));
    expect(svc.defaultSuggestionsForRole('teacher').first.label, contains('Exam Paper'));
    expect(svc.defaultSuggestionsForRole('admin').first.label, contains('Executive Report'));
  });

  testWidgets('CopilotDocumentCard renders title, badges, and answer key toggle',
      (tester) async {
    const docCard = CopilotCardData(
      type: 'document',
      title: 'DBMS Mid-Sem Exam',
      subtitle: 'DBMS · MID SEM EXAM',
      badges: ['MID SEM EXAM', '30 Marks', '60 Mins'],
      content: 'Q1. Define 3NF.',
      answerKey: '3NF removes transitive dependencies.',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CopilotDocumentCard(card: docCard),
          ),
        ),
      ),
    );

    expect(find.text('DBMS Mid-Sem Exam'), findsOneWidget);
    expect(find.text('30 Marks'), findsOneWidget);
    expect(find.text('Q1. Define 3NF.'), findsOneWidget);
    expect(find.text('Show Answer Key & Rubric'), findsOneWidget);

    await tester.tap(find.text('Show Answer Key & Rubric'));
    await tester.pumpAndSettle();
    expect(find.text('3NF removes transitive dependencies.'), findsOneWidget);
  });
}
