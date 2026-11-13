import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/shared/widgets/dock/app_dock.dart';

void main() {
  group('AppDock Widget Tests', () {
    testWidgets('renders all navigation items correctly', (tester) async {
      int selected = 0;
      final items = [
        const AppDockItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
        ),
        const AppDockItem(
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet_rounded,
          label: 'Wallet',
        ),
        const AppDockItem(
          icon: Icons.inbox_outlined,
          activeIcon: Icons.inbox_rounded,
          label: 'Requests',
          hasDot: true,
        ),
        const AppDockItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppDock(
              items: items,
              currentIndex: selected,
              onTap: (idx) => selected = idx,
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Wallet'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(
        find.byIcon(Icons.account_balance_wallet_outlined),
        findsOneWidget,
      );
    });

    testWidgets('tapping an unselected item triggers onTap with corresponding index',
        (tester) async {
      int tappedIndex = -1;
      final items = [
        const AppDockItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
        ),
        const AppDockItem(
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet_rounded,
          label: 'Wallet',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppDock(
              items: items,
              currentIndex: 0,
              onTap: (idx) => tappedIndex = idx,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Wallet'));
      await tester.pumpAndSettle();

      expect(tappedIndex, equals(1));
    });

    testWidgets('tapping an already-selected tab still triggers onTap',
        (tester) async {
      int tapCount = 0;
      int lastIndex = -1;
      final items = [
        const AppDockItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
        ),
        const AppDockItem(
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet_rounded,
          label: 'Wallet',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppDock(
              items: items,
              currentIndex: 0,
              onTap: (idx) {
                tapCount++;
                lastIndex = idx;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(tapCount, equals(1));
      expect(lastIndex, equals(0));
    });

    testWidgets('renders notification dot and count badges', (tester) async {
      final items = [
        const AppDockItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
        ),
        const AppDockItem(
          icon: Icons.notifications_outlined,
          activeIcon: Icons.notifications_rounded,
          label: 'Alerts',
          hasDot: true,
          badgeCount: 5,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppDock(
              items: items,
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('provides correct button accessibility semantics',
        (tester) async {
      final items = [
        const AppDockItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
        ),
        const AppDockItem(
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet_rounded,
          label: 'Wallet',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppDock(
              items: items,
              currentIndex: 1,
              onTap: (_) {},
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('Wallet')),
        matchesSemantics(
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          label: 'Wallet',
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Home')),
        matchesSemantics(
          isButton: true,
          isSelected: false,
          hasSelectedState: true,
          label: 'Home',
          hasTapAction: true,
        ),
      );
    });
  });
}
