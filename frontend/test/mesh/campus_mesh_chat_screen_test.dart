import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/core/mesh/chat/mesh_chat_message.dart';
import 'package:attendance_app/shared/screens/campus_mesh_chat_screen.dart';

void main() {
  group('CampusOS Mesh — Premium Apple Telegram UI Tests', () {
    testWidgets('Screen 1: Channels list renders header, status card, and channel rows',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CampusMeshChatScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Header elements
      expect(find.text('CampusOS'), findsOneWidget);
      expect(find.text('Channels'), findsOneWidget);

      // 2. Mesh Status Card
      expect(find.text('Hybrid mesh active'), findsOneWidget);
      expect(find.textContaining('peer nearby'), findsOneWidget);
      expect(find.text('Bluetooth'), findsOneWidget);
      expect(find.text('Wi-Fi'), findsOneWidget);
      expect(find.text('Internet'), findsOneWidget);

      // 3. Section label & Channel rows
      expect(find.text('ALL CHANNELS'), findsOneWidget);
      expect(find.text('#general'), findsOneWidget);
      expect(find.text('#hostel-b'), findsOneWidget);
      expect(find.text('#study-group'), findsOneWidget);
      expect(find.text('#alerts'), findsOneWidget);

      // 4. Previews
      expect(find.text('You: gui'), findsOneWidget);
      expect(find.text('No messages yet'), findsNWidgets(3));
    });

    testWidgets('Tapping #general navigates to Screen 2: Chat screen',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CampusMeshChatScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap on #general
      await tester.tap(find.text('#general'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 50));

      // Header on Chat Screen
      expect(find.text('#general'), findsOneWidget);
      expect(find.textContaining('Hybrid mesh ·'), findsOneWidget);
      expect(find.text('Hybrid'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);

      // Today date chip
      expect(find.text('Today'), findsOneWidget);

      // Telegram-style role tags and messages
      expect(find.text('STUDENT'), findsWidgets);
      expect(find.text('Rahul Sharma'), findsWidgets);
      expect(find.text('Ananya Sen'), findsWidgets);
      expect(find.text('gui'), findsOneWidget);

      // Composer field & send button
      expect(find.text('Message the mesh'), findsOneWidget);
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('Sending a message in Chat screen appends outgoing message and clears draft',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CampusMeshChatScreen(
            initialChannelId: 'channel:general',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Enter text into Composer
      await tester.enterText(find.byType(TextField), 'Testing mesh packet transfer');
      await tester.pump();

      // Tap animated send button
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump(const Duration(milliseconds: 250));

      // Message is displayed as outgoing bubble
      expect(find.text('Testing mesh packet transfer'), findsOneWidget);
      expect(find.byIcon(Icons.done_all_rounded), findsWidgets);

      // TextField is cleared
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('Flagged message renders amber card and reveals text on tap',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CampusMeshChatScreen(
            initialChannelId: 'channel:general',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Warning card is visible
      expect(find.text('Hidden · abusive language'), findsOneWidget);
      expect(find.text('Tap to reveal message'), findsOneWidget);

      // Abusive text is initially hidden
      expect(find.textContaining('Claim free tokens'), findsNothing);

      // Tap warning card to reveal
      await tester.tap(find.text('Hidden · abusive language'));
      await tester.pump(const Duration(milliseconds: 300));

      // Now revealed
      expect(find.textContaining('Claim free tokens'), findsOneWidget);
      expect(find.text('Hide'), findsOneWidget);
    });

    testWidgets('Empty channel renders centered frosted empty state card',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CampusMeshChatScreen(
            initialChannelId: 'channel:hostel-b',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No messages yet'), findsOneWidget);
      expect(
        find.text(
            'Messages hop phone to phone over Bluetooth, and sync over the internet when it is available.'),
        findsOneWidget,
      );
    });

    testWidgets('Deliverable Widgets: GlassContainer renders with blur and border',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              child: Text('Glass Child'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Glass Child'), findsOneWidget);
      expect(find.byType(GlassContainer), findsOneWidget);
    });

    testWidgets('Deliverable Widgets: ChannelRow renders avatar and triggers tap',
        (tester) async {
      bool tapped = false;
      const summary = ChannelSummary(
        id: 'channel:test',
        name: '#test-channel',
        lastMessagePreview: 'Hello world',
        lastMessageTime: '12:00',
        initial: 'T',
        avatarGradient: [Colors.purple, Colors.deepPurple],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChannelRow(
              summary: summary,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('#test-channel'), findsOneWidget);
      expect(find.text('Hello world'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);
      expect(find.text('T'), findsOneWidget);

      await tester.tap(find.text('#test-channel'));
      expect(tapped, isTrue);
    });

    testWidgets('Deliverable Widgets: MessageBubble incoming and outgoing formatting',
        (tester) async {
      final inMsg = MeshChatMessage(
        messageId: 'in_1',
        senderDeviceId: 'peer_1',
        senderDisplayName: 'Peer User',
        senderRole: 'student',
        channelId: 'channel:general',
        text: 'Incoming test message',
        createdAt: DateTime(2026, 11, 13, 17, 5),
        hopCount: 1,
      );

      final outMsg = MeshChatMessage(
        messageId: 'out_1',
        senderDeviceId: 'local_user',
        senderDisplayName: 'You',
        senderRole: 'student',
        channelId: 'channel:general',
        text: 'Outgoing test message',
        createdAt: DateTime(2026, 11, 13, 17, 6),
        isOutgoing: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  MessageBubble(message: inMsg),
                  MessageBubble(message: outMsg),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Incoming test message'), findsOneWidget);
      expect(find.text('P2P · 1 hop · 17:05'), findsOneWidget);

      expect(find.text('Outgoing test message'), findsOneWidget);
      expect(find.text('17:06'), findsOneWidget);
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
    });

    testWidgets('Create new channel adds channel to list and navigates to it',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CampusMeshChatScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap "+" action button in header
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Choose "New Broadcast Channel"
      await tester.tap(find.text('New Broadcast Channel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Enter channel name
      expect(find.text('Create New Channel'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'robotics-lab');
      await tester.pump();

      // Tap Create Channel button
      await tester.tap(find.text('Create Channel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Now inside the newly created #robotics-lab chat screen
      expect(find.text('#robotics-lab'), findsOneWidget);
      expect(find.text('No messages yet'), findsOneWidget);
    });

    testWidgets('Tapping status card opens Nearby Peers sheet and starts Direct Message with peer',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CampusMeshChatScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the Mesh Status Card
      await tester.tap(find.text('Hybrid mesh active'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Sheet opens showing nearby peers
      expect(find.text('Nearby Mesh Peers'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);

      // Tap "Chat" on the first peer
      await tester.tap(find.text('Chat').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Navigates directly to the DM conversation
      expect(find.text('DM: Rahul Sharma'), findsOneWidget);
    });
  });
}
