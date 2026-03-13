import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../services/notification_service.dart';

class TaskProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  
  List<TaskModel> _todaysTasks = [];
  List<TaskModel> _allTasks = [];
  bool _isLoading = false;
  StreamSubscription? _tasksSubscription;

  List<TaskModel> get todaysTasks => _todaysTasks;
  List<TaskModel> get allTasks => _allTasks;
  bool get isLoading => _isLoading;

  void setupTaskListener(String userId) {
    _tasksSubscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _tasksSubscription = _firestore
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      _allTasks = snapshot.docs
          .map((doc) => TaskModel.fromMap(doc.data(), doc.id))
          .toList();
      
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
      
      _todaysTasks = _allTasks.where((task) {
        return task.date.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
               task.date.isBefore(endOfDay.add(const Duration(seconds: 1)));
      }).toList().reversed.toList(); // Keep original order (oldest first for today) or sort as needed
      
      // Secondary sort for Today's tasks by date ascending
      _todaysTasks.sort((a, b) => a.date.compareTo(b.date));

      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Error in task listener: $e');
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> fetchTodaysTasks(String userId) async {
    // If listener is active, it will handle updates. 
    // This method is kept for backward compatibility but calls setupTaskListener.
    setupTaskListener(userId);
  }

  Future<void> fetchAllTasks(String userId) async {
    // If listener is active, it will handle updates.
    setupTaskListener(userId);
  }

  Future<void> addTask(TaskModel task) async {
    try {
      final docRef = await _firestore.collection('tasks').add(task.toMap());
      final addedTask = TaskModel.fromMap(task.toMap(), docRef.id);
      
      // Schedule reminder 15 mins before if future date
      if (addedTask.reminderSet) {
        final reminderTime = addedTask.date.subtract(const Duration(minutes: 15));
        if (reminderTime.isAfter(DateTime.now())) {
          await _notificationService.scheduleReminder(
            id: addedTask.notificationId,
            title: 'Task Reminder',
            body: 'Upcoming: ${addedTask.title} in 15 minutes',
            scheduledTime: reminderTime,
          );
        }
      }
      // No need to manually refresh, the listener will pick it up
    } catch (e) {
      debugPrint('Error adding task: $e');
      rethrow;
    }
  }

  Future<void> toggleTaskCompletion(String taskId, bool currentStatus) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update({
        'isCompleted': !currentStatus,
      });
      // Listener will update local state
    } catch (e) {
      debugPrint('Error toggling task completion: $e');
    }
  }

  Future<void> deleteTask(TaskModel task) async {
    try {
      await _firestore.collection('tasks').doc(task.id).delete();
      if (task.reminderSet) {
        await _notificationService.cancelReminder(task.notificationId);
      }
      // Listener will update local state
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }

  @override
  void dispose() {
    _tasksSubscription?.cancel();
    super.dispose();
  }
}
