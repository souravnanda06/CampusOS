import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../auth/services/auth_service.dart';
import '../../student/services/notice_service.dart';
import '../../student/widgets/requests/notice_detail_sheet.dart';
import '../../router/app_routes.dart';


class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static GlobalKey<NavigatorState>? navigatorKey;
  static bool _initialized = false;
  static String? _pendingNoticeId;

  static Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    if (navKey != null) {
      navigatorKey = navKey;
    }
    if (_initialized) return;

    try {
      // 1. Request notification permissions
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 2. Initialize local notifications with notification response handler
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            if (payload.startsWith('emergency:')) {
              handleEmergencyNotificationTap();
            } else {
              handleNoticeTap(payload);
            }
          }
        },
      );

      // 3. Create Android notification channels
      const AndroidNotificationChannel noticeChannel = AndroidNotificationChannel(
        'campusos_notices',
        'CampusOS Notices',
        description: 'Targeted institutional announcements and academic notices',
        importance: Importance.high,
      );

      const AndroidNotificationChannel attendanceChannel = AndroidNotificationChannel(
        'attendance_channel',
        'Attendance Notifications',
        description: 'Session start and live attendance alerts',
        importance: Importance.high,
      );

      const AndroidNotificationChannel emergencyChannel = AndroidNotificationChannel(
        'emergency_flares',
        'Emergency Disaster Flares',
        description: 'Offline BLE Mesh Life-Safety Emergency Alarms & Sirens',
        importance: Importance.max,
        enableLights: true,
        ledColor: Color(0xFFEF4444),
        enableVibration: true,
      );

      final androidImpl = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(noticeChannel);
        await androidImpl.createNotificationChannel(attendanceChannel);
        await androidImpl.createNotificationChannel(emergencyChannel);
      }

      // 4. Listen to foreground push messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 5. Listen to background message taps
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final noticeId = message.data['noticeId'];
        if (noticeId != null && noticeId.isNotEmpty) {
          handleNoticeTap(noticeId);
        }
      });

      // 6. Listen to token refresh events
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        final user = await AuthService().getUserDataFromStorage();
        if (user != null && newToken.isNotEmpty) {
          await NoticeService().registerDeviceToken(newToken, requesterId: user.id);
        }
      });

      _initialized = true;
      debugPrint('🔔 NotificationService fully initialized with Step 21E notice routing');
    } catch (e) {
      debugPrint('❌ Notification initialization error: $e');
    }
  }

  // Helper to generate consistent topics for BLE/attendance
  static String? _getTopic(String? course, String? branch, String? year) {
    if (course == null || year == null) return null;
    List<String> parts = [course, branch, year].whereType<String>().toList();
    List<String> cleanParts =
        parts.map((p) => p.replaceAll(' ', '').replaceAll('.', '')).toList();
    return cleanParts.join('_');
  }

  static Future<void> subscribeToTopic(
      String? course, String? branch, String? year) async {
    String? topic = _getTopic(course, branch, year);
    if (topic != null && topic.isNotEmpty) {
      try {
        await _firebaseMessaging.subscribeToTopic(topic);
        debugPrint('✅ [FRONTEND] Subscribed to topic: $topic');
      } catch (e) {
        debugPrint('❌ Failed to subscribe: $e');
      }
    }
  }

  static Future<void> unsubscribeFromTopic(
      String? course, String? branch, String? year) async {
    String? topic = _getTopic(course, branch, year);
    if (topic != null && topic.isNotEmpty) {
      try {
        await _firebaseMessaging.unsubscribeFromTopic(topic);
        debugPrint('✅ Unsubscribed from topic: $topic');
      } catch (e) {
        debugPrint('❌ Failed to unsubscribe: $e');
      }
    }
  }

  // --- DEVICE TOKEN MANAGEMENT ---

  static Future<String?> getDeviceToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      debugPrint('⚠️ Failed to obtain FCM token: $e');
      return null;
    }
  }

  static Future<void> syncDeviceTokenWithBackend({required String userId}) async {
    try {
      final token = await getDeviceToken();
      if (token != null && token.isNotEmpty) {
        final ok = await NoticeService().registerDeviceToken(token, requesterId: userId);
        if (ok) {
          debugPrint('✅ FCM token registered with backend for user: $userId');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to register FCM token with backend: $e');
    }
  }

  static Future<void> removeDeviceTokenFromBackend({required String userId}) async {
    try {
      final token = await getDeviceToken();
      if (token != null && token.isNotEmpty) {
        await NoticeService().removeDeviceToken(token, requesterId: userId);
        debugPrint('✅ FCM token removed on backend for user: $userId');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to remove FCM token from backend: $e');
    }
  }

  // --- FOREGROUND NOTIFICATION DISPATCH ---

  static void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final isNotice = data['notificationType'] == 'NOTICE' || data.containsKey('noticeId');
    final title = message.notification?.title ?? data['title'] ?? (isNotice ? 'CampusOS Notice' : 'Attendance Alert');
    final body = message.notification?.body ?? data['body'] ?? '';
    final noticeId = data['noticeId'] as String?;

    _showLocalNotification(
      title: title,
      body: body,
      payload: isNotice ? noticeId : null,
      channelId: isNotice ? 'campusos_notices' : 'attendance_channel',
      channelName: isNotice ? 'CampusOS Notices' : 'Attendance Notifications',
    );
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'campusos_notices',
    String channelName = 'CampusOS Notices',
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    final NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Displays an immediate high-priority local Android notification for offline emergency flares.
  /// Works 100% offline without internet, cloud servers, or Firebase.
  static Future<void> showOfflineEmergencyNotification({
    required String title,
    required String message,
    required bool isCritical,
    bool sirenEnabled = false,
    String? alertId,
  }) async {
    try {
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'emergency_flares',
        'Emergency Disaster Flares',
        channelDescription: 'Offline BLE Mesh Life-Safety Emergency Alarms & Sirens',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: (isCritical || sirenEnabled)
            ? Int64List.fromList([0, 500, 200, 500, 200, 800])
            : Int64List.fromList([0, 300, 150, 300]),
        enableLights: true,
        ledColor: const Color(0xFFEF4444),
        ledOnMs: 400,
        ledOffMs: 250,
        color: const Color(0xFFEF4444),
        colorized: true,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        ongoing: sirenEnabled && isCritical,
        fullScreenIntent: isCritical || sirenEnabled,
      );
      final NotificationDetails notificationDetails =
          NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        (alertId ?? title).hashCode & 0x7fffffff,
        title,
        message,
        notificationDetails,
        payload: 'emergency:${alertId ?? 'active'}',
      );
    } catch (e) {
      debugPrint('ℹ️ [NOTIFICATION_SERVICE] Offline emergency notification error: $e');
    }
  }

  static Future<void> cancelEmergencyNotification(String? alertId) async {
    try {
      if (alertId != null && alertId.isNotEmpty) {
        await _localNotifications.cancel(alertId.hashCode & 0x7fffffff);
      }
    } catch (_) {}
  }

  static Future<void> handleEmergencyNotificationTap() async {
    final nav = navigatorKey?.currentState;
    if (nav == null) return;
    try {
      final user = await AuthService().getUserDataFromStorage();
      if (user != null && user.role.toLowerCase() == 'student') {
        nav.pushNamed(AppRoutes.studentEmergency);
      } else {
        nav.pushNamed(AppRoutes.meshEmergency);
      }
    } catch (_) {
      nav.pushNamed(AppRoutes.meshEmergency);
    }
  }

  // --- NOTIFICATION TAP & ROUTING ---

  static Future<void> checkInitialMessage() async {
    try {
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        final noticeId = initialMessage.data['noticeId'] as String?;
        if (noticeId != null && noticeId.isNotEmpty) {
          _pendingNoticeId = noticeId;
          // Defer until navigation state is mounted
          Future.delayed(const Duration(milliseconds: 700), () {
            processPendingNotice();
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error checking initial FCM notification: $e');
    }
  }

  static void processPendingNotice() {
    if (_pendingNoticeId != null && _pendingNoticeId!.isNotEmpty) {
      final nid = _pendingNoticeId!;
      _pendingNoticeId = null;
      handleNoticeTap(nid);
    }
  }

  static Future<void> handleNoticeTap(String noticeId) async {
    final context = navigatorKey?.currentContext;
    if (context == null) {
      _pendingNoticeId = noticeId;
      return;
    }

    try {
      final user = await AuthService().getUserDataFromStorage();
      final notice = await NoticeService().getNotice(noticeId, requesterId: user?.id);

      if (!context.mounted) return;

      if (user != null && user.role == 'student') {
        // Show student NoticeDetailSheet (which tracks read asynchronously and supports safe actions)
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => NoticeDetailSheet(
            notice: notice,
            studentId: user.id,
          ),
        );
      } else if (user != null && (user.role == 'teacher' || user.role == 'admin' || user.role == 'staff')) {
        // Navigate to teacher/admin notice detail management screen
        navigatorKey?.currentState?.pushNamed(
          AppRoutes.noticeDetail,
          arguments: {'user': user, 'notice': notice},
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load notice on tap: $e');
    }
  }
}
