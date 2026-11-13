import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

import 'router/app_router.dart';
import 'router/app_routes.dart';
import 'core/theme/campus_os_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/haptics/haptics_provider.dart';
import 'core/services/notification_service.dart';
import 'auth/providers/user_provider.dart';
import 'shared/providers/attendance_provider.dart';
import 'shared/providers/copilot_provider.dart';

import 'core/performance/performance.dart';
import 'core/localization/language_provider.dart';
import 'core/network/connectivity_service.dart';
import 'core/sync/sync_manager.dart';

// 1. Define the RouteObserver and NavigatorKey globally
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }

  // Initialize central Adaptive Performance Engine
  await PerformanceEngine.instance.initialize();

  // Initialize network monitoring and offline-first background sync engine
  ConnectivityService.instance;
  SyncManager.instance;

  await NotificationService.initialize(navKey: navigatorKey);
  NotificationService.checkInitialMessage();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: PerformanceEngine.instance),
        ChangeNotifierProvider(create: (_) => UserProvider()..loadUser()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => CopilotProvider()),
        ChangeNotifierProvider.value(value: LanguageProvider.instance),
        ChangeNotifierProvider.value(value: ThemeProvider.instance),
        ChangeNotifierProvider.value(value: HapticsProvider.instance),
      ],
      child: const MyApp(),
    ),
  );
}

/// Global Apple-grade scroll behavior ensuring fluid iOS spring bounce across all scrollables.
class AppleGlobalScrollBehavior extends MaterialScrollBehavior {
  const AppleGlobalScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LanguageProvider.instance,
        ThemeProvider.instance,
      ]),
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'CampusOS',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const AppleGlobalScrollBehavior(),
          theme: CampusOSTheme.lightTheme,
          darkTheme: CampusOSTheme.darkTheme,
          themeMode: ThemeProvider.instance.themeMode,
          locale: LanguageProvider.instance.currentLocale,
          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRouter.generateRoute,
          navigatorObservers: [routeObserver],
        );
      },
    );
  }
}
