import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/shared/widgets/dock/apple_glass_dock.dart';

void main() {
  group('AppleGlassDock Widget Tests', () {
    testWidgets('renders all navigation items correctly', (tester) async {
      int selected = 0;
      final items = [
        const AppleDockItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
        ),
        const AppleDockItem(
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet_rounded,
          label: 'Wallet',
        ),
        const AppleDockItem(
          icon: Icons.inbox_outlined,
          activeIcon: Icons.inbox_rounded,
          label: 'Requests',
          hasDot: true,
        ),
        const AppleDockItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppleGlassDock(
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
      expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);
    });

    testWidgets('tapping an item triggers onTap with corresponding index', (tester) async {
      int tappedIndex = -1;
      final items = [
        const AppleDockItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
        ),
        const AppleDockItem(
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet_rounded,
          label: 'Wallet',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppleGlassDock(
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

    testWidgets('renders red notification dot and count badges', (tester) async {
      final items = [
        const AppleDockItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
        ),
        const AppleDockItem(
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
            bottomNavigationBar: AppleGlassDock(
              items: items,
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('renders custom avatar icon when provided', (tester) async {
      final items = [
        const AppleDockItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
        ),
        const AppleDockItem(
          icon: Icons.person,
          activeIcon: Icons.person,
          label: 'Jij',
          customIcon: CircleAvatar(
            radius: 11,
            key: ValueKey('test_avatar'),
          ),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppleGlassDock(
              items: items,
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('test_avatar')), findsOneWidget);
      expect(find.text('Jij'), findsOneWidget);
    });
  });
}

