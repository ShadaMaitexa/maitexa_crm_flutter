import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Request permission for iOS
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android 13+ requires runtime notification permission
    try {
      final status = await Permission.notification.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        await Permission.notification.request();
      }
    } catch (_) {}

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  Future<void> syncToken(String userId) async {
    try {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update(
          {
            'fcmToken': token,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          },
        );
      }

      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        await FirebaseFirestore.instance.collection('users').doc(userId).update(
          {
            'fcmToken': newToken,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          },
        );
      });
    } catch (_) {}
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // In foreground, rely on in-app UI or badges.
    // Optionally surface a snackbar/dialog from the listening UI layer.
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    // Handle notification tap - navigate to specific screens based on type
    print('Notification tapped: ${message.data}');

    final data = message.data;
    final type = data['type'];
    final itemId = data['itemId'];

    // Use GetX for navigation (since you have get package)
    switch (type) {
      case 'follow_up':
      case 'daily_follow_up':
        if (itemId != null) {
          Get.toNamed('/follow-ups', arguments: {'highlightId': itemId});
        } else {
          Get.toNamed('/follow-ups');
        }
        break;
      case 'college_visit':
        if (itemId != null) {
          Get.toNamed('/college-visits', arguments: {'highlightId': itemId});
        } else {
          Get.toNamed('/college-visits');
        }
        break;
      case 'overdue_follow_up':
        Get.toNamed('/follow-ups', arguments: {'filter': 'overdue'});
        break;
      case 'overdue_college_visit':
        Get.toNamed('/college-visits', arguments: {'filter': 'overdue'});
        break;
      default:
        // Navigate to dashboard or show a general notification screen
        Get.toNamed('/dashboard');
    }
  }

  Future<void> scheduleFollowUpReminder({
    required String id,
    required String title,
    required String body,
    required DateTime followUpDate,
    required String contactName,
    required String userId,
  }) async {
    // Schedule notification 1 hour before follow-up
    final oneHourBefore = followUpDate.subtract(const Duration(hours: 1));

    // Schedule morning reminder on the same day
    final morningReminder = DateTime(
      followUpDate.year,
      followUpDate.month,
      followUpDate.day,
      9, // 9 AM
      0,
    );

    // Only schedule if the time hasn't passed
    if (oneHourBefore.isAfter(DateTime.now())) {
      await _scheduleFirebaseNotification(
        id: '1$id', // Prefix with 1 for follow-up 1 hour before
        title: 'Follow-up Reminder',
        body: 'Call $contactName in 1 hour',
        scheduledTime: oneHourBefore,
        userId: userId,
        type: 'follow_up',
        data: {
          'contactName': contactName,
          'followUpDate': followUpDate.toIso8601String(),
          'itemId': id,
        },
      );
    }

    // Schedule morning reminder if it's today and hasn't passed
    if (morningReminder.isAfter(DateTime.now()) &&
        morningReminder.day == DateTime.now().day) {
      await _scheduleFirebaseNotification(
        id: '2$id', // Prefix with 2 for morning reminder
        title: 'Today\'s Follow-ups',
        body: 'You have a follow-up with $contactName today',
        scheduledTime: morningReminder,
        userId: userId,
        type: 'daily_follow_up',
        data: {
          'contactName': contactName,
          'followUpDate': followUpDate.toIso8601String(),
          'itemId': id,
        },
      );
    }
  }

  Future<void> scheduleCollegeVisitReminder({
    required String id,
    required String title,
    required String body,
    required DateTime visitDate,
    required String collegeName,
    required String userId,
  }) async {
    // Schedule notification 1 day before visit
    final oneDayBefore = visitDate.subtract(const Duration(days: 1));
    final morningReminder = DateTime(
      oneDayBefore.year,
      oneDayBefore.month,
      oneDayBefore.day,
      9, // 9 AM
      0,
    );

    // Only schedule if the time hasn't passed
    if (morningReminder.isAfter(DateTime.now())) {
      await _scheduleFirebaseNotification(
        id: '3$id', // Prefix with 3 for college visit reminder
        title: 'College Visit Tomorrow',
        body: 'Visit to $collegeName tomorrow',
        scheduledTime: morningReminder,
        userId: userId,
        type: 'college_visit',
        data: {
          'collegeName': collegeName,
          'visitDate': visitDate.toIso8601String(),
          'itemId': id,
        },
      );
    }
  }

  Future<void> _scheduleFirebaseNotification({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String userId,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    // Store notification in Firestore for scheduling
    await FirebaseFirestore.instance.collection('scheduled_notifications').add({
      'id': id,
      'title': title,
      'body': body,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'userId': userId,
      'type': type,
      'data': data,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelNotification(String id) async {
    // Cancel from Firestore
    final querySnapshot = await FirebaseFirestore.instance
        .collection('scheduled_notifications')
        .where('id', isEqualTo: id)
        .get();

    for (var doc in querySnapshot.docs) {
      await doc.reference.update({'status': 'cancelled'});
    }
  }

  Future<void> cancelAllNotifications() async {
    // Cancel all pending notifications
    final querySnapshot = await FirebaseFirestore.instance
        .collection('scheduled_notifications')
        .where('status', isEqualTo: 'pending')
        .get();

    for (var doc in querySnapshot.docs) {
      await doc.reference.update({'status': 'cancelled'});
    }
  }

  Future<List<Map<String, dynamic>>> getPendingNotifications() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('scheduled_notifications')
        .where('status', isEqualTo: 'pending')
        .orderBy('scheduledTime')
        .get();

    return querySnapshot.docs.map((doc) => doc.data()).toList();
  }

  // Check for overdue items and schedule overdue notifications
  Future<void> checkAndScheduleOverdueNotifications(String userId) async {
    final now = DateTime.now();

    // Check overdue follow-ups
    final overdueFollowUps = await FirebaseFirestore.instance
        .collection('follow_ups')
        .where('followUpDate', isLessThan: Timestamp.fromDate(now))
        .where('status', whereIn: ['pending', 'scheduled'])
        .get();

    for (var doc in overdueFollowUps.docs) {
      final data = doc.data();
      await _scheduleFirebaseNotification(
        id: 'overdue_follow_${doc.id}',
        title: 'Overdue Follow-up',
        body: 'Follow-up with ${data['contactName']} is overdue',
        scheduledTime: now,
        userId: userId,
        type: 'overdue_follow_up',
        data: {
          'contactName': data['contactName'],
          'followUpDate': data['followUpDate'].toDate().toIso8601String(),
          'itemId': doc.id,
        },
      );
    }

    // Check overdue college visits
    final overdueVisits = await FirebaseFirestore.instance
        .collection('college_visits')
        .where('visitDate', isLessThan: Timestamp.fromDate(now))
        .where('status', whereIn: ['pending', 'scheduled'])
        .get();

    for (var doc in overdueVisits.docs) {
      final data = doc.data();
      await _scheduleFirebaseNotification(
        id: 'overdue_visit_${doc.id}',
        title: 'Overdue College Visit',
        body: 'Visit to ${data['collegeName']} is overdue',
        scheduledTime: now,
        userId: userId,
        type: 'overdue_college_visit',
        data: {
          'collegeName': data['collegeName'],
          'visitDate': data['visitDate'].toDate().toIso8601String(),
          'itemId': doc.id,
        },
      );
    }
  }

  // Get notification count for badge
  Future<int> getNotificationCount(String userId) async {
    final now = DateTime.now();

    // Count overdue follow-ups
    final overdueFollowUps = await FirebaseFirestore.instance
        .collection('follow_ups')
        .where('followUpDate', isLessThan: Timestamp.fromDate(now))
        .where('status', whereIn: ['pending', 'scheduled'])
        .count()
        .get();

    // Count overdue college visits
    final overdueVisits = await FirebaseFirestore.instance
        .collection('college_visits')
        .where('visitDate', isLessThan: Timestamp.fromDate(now))
        .where('status', whereIn: ['pending', 'scheduled'])
        .count()
        .get();

    // Count pending scheduled notifications
    final pendingNotifications = await FirebaseFirestore.instance
        .collection('scheduled_notifications')
        .where('status', isEqualTo: 'pending')
        .where('scheduledTime', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .count()
        .get();

    return (overdueFollowUps.count ?? 0) +
        (overdueVisits.count ?? 0) +
        (pendingNotifications.count ?? 0);
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages here
  print('Handling background message: ${message.messageId}');
}
