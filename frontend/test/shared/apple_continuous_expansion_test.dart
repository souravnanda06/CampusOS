import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/shared/widgets/motion/apple_continuous_expansion.dart';
import 'package:attendance_app/shared/widgets/motion/apple_context_menu.dart';

void main() {
  group('AppleContinuousExpansionCard Tests', () {
    testWidgets('Renders compact child and expands on tap', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool expandedDismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 100,
                child: AppleContinuousExpansionCard(
                  cardRadius: 20,
                  expandedBuilder: (context, dismiss) {
                    return Container(
                      color: Colors.blue,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('EXPANDED_CONTENT_TEST'),
                            ElevatedButton(
                              onPressed: () {
                                expandedDismissed = true;
                                dismiss();
                              },
                              child: const Text('CUSTOM_CLOSE'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    color: Colors.red,
                    child: const Center(
                      child: Text('COMPACT_CARD_TEST'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // 1. Initially compact card is visible, expanded is not
      expect(find.text('COMPACT_CARD_TEST'), findsOneWidget);
      expect(find.text('EXPANDED_CONTENT_TEST'), findsNothing);

      // 2. Tap to expand
      await tester.tap(find.text('COMPACT_CARD_TEST'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 3. Expanded content is now visible
      expect(find.text('EXPANDED_CONTENT_TEST'), findsOneWidget);
      expect(find.text('CUSTOM_CLOSE'), findsOneWidget);

      // 4. Tap the close button to collapse
      await tester.tap(find.text('CUSTOM_CLOSE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(expandedDismissed, isTrue);
      expect(find.text('EXPANDED_CONTENT_TEST'), findsNothing);
      expect(find.text('COMPACT_CARD_TEST'), findsOneWidget);
    });

    testWidgets('Dismisses via top-right floating close button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 100,
                child: AppleContinuousExpansionCard(
                  expandedBuilder: (context, dismiss) {
                    return const Scaffold(
                      body: Center(child: Text('DETAIL_VIEW')),
                    );
                  },
                  child: const Text('TRIGGER_CARD'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('TRIGGER_CARD'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('DETAIL_VIEW'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap floating close icon
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('DETAIL_VIEW'), findsNothing);
      expect(find.text('TRIGGER_CARD'), findsOneWidget);
    });

    testWidgets('Expands seamlessly when child is an AppleContextMenu (resolves gesture arena collision)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 250,
                height: 120,
                child: AppleContinuousExpansionCard(
                  expandedBuilder: (context, dismiss) {
                    return const Scaffold(
                      body: Center(child: Text('CONTEXT_EXPANDED_VIEW')),
                    );
                  },
                  child: AppleContextMenu(
                    actions: [
                      AppleContextMenuItem(
                        title: 'Test Action',
                        icon: Icons.check,
                        onTap: () {},
                      ),
                    ],
                    child: Container(
                      color: Colors.purple,
                      child: const Center(
                        child: Text('CONTEXT_MENU_CARD'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('CONTEXT_MENU_CARD'), findsOneWidget);
      expect(find.text('CONTEXT_EXPANDED_VIEW'), findsNothing);

      // Tap on the card - AppleContextMenu's auto-delegation must trigger expansion!
      await tester.tap(find.text('CONTEXT_MENU_CARD'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('CONTEXT_EXPANDED_VIEW'), findsOneWidget);
    });
  });
}
