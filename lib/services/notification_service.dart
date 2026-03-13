import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked: ${response.payload}');
      },
    );

    // Request permissions for Android
    if (Platform.isAndroid) {
      await _requestPermissions();
    }

    _isInitialized = true;
  }

  Future<void> _requestPermissions() async {
    // Request notification permission (Android 13+)
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // Request exact alarm permission (Android 12+)
    // Note: In Android 14+, SCHEDULE_EXACT_ALARM is denied by default.
    // The user must manually enable it in settings if we request it this way,
    // or we can just check if we have it.
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (!_isInitialized) await initialize();

    if (scheduledTime.isBefore(DateTime.now())) return;

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders',
            'Task Reminders',
            channelDescription: 'Notifications for upcoming tasks',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Error scheduling exact alarm: $e');
      // Fallback to inexact if exact is not permitted
      if (e.toString().contains('exact_alarms_not_permitted')) {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(scheduledTime, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'task_reminders',
              'Task Reminders',
              channelDescription: 'Notifications for upcoming tasks',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> cancelReminder(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Returns the count of overdue notifications (follow-ups + college visits)
  /// that are still pending/scheduled for the given [userId].
  Future<int> getNotificationCount(String userId) async {
    try {
      final now = Timestamp.fromDate(DateTime.now());

      final followUpsQuery = FirebaseFirestore.instance
          .collection('follow_ups')
          .where('createdBy', isEqualTo: userId)
          .where('followUpDate', isLessThan: now)
          .where('status', whereIn: ['pending', 'scheduled']);

      final visitsQuery = FirebaseFirestore.instance
          .collection('college_visits')
          .where('createdBy', isEqualTo: userId)
          .where('visitDate', isLessThan: now)
          .where('status', whereIn: ['pending', 'scheduled']);

      final results = await Future.wait([
        followUpsQuery.get(),
        visitsQuery.get(),
      ]);

      return results[0].docs.length + results[1].docs.length;
    } catch (e) {
      debugPrint('getNotificationCount error: $e');
      return 0;
    }
  }
}
