import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../services/notification_service.dart';

class TaskProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  
  List<TaskModel> _todaysTasks = [];
  bool _isLoading = false;

  List<TaskModel> get todaysTasks => _todaysTasks;
  bool get isLoading => _isLoading;

  Future<void> fetchTodaysTasks(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('tasks')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('date')
          .get();

      _todaysTasks = snapshot.docs
          .map((doc) => TaskModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching tasks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

      await fetchTodaysTasks(addedTask.userId);
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
      // update local
      final index = _todaysTasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _todaysTasks[index] = TaskModel(
          id: _todaysTasks[index].id,
          title: _todaysTasks[index].title,
          description: _todaysTasks[index].description,
          date: _todaysTasks[index].date,
          userId: _todaysTasks[index].userId,
          isCompleted: !currentStatus,
          reminderSet: _todaysTasks[index].reminderSet,
          notificationId: _todaysTasks[index].notificationId,
        );
        notifyListeners();
      }
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
      _todaysTasks.removeWhere((t) => t.id == task.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }
}
