import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';

class DashboardProvider extends ChangeNotifier {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentEnquiries = [];
  List<Map<String, dynamic>> _recentVisits = [];
  List<Map<String, dynamic>> _recentFollowUps = [];
  bool _isLoading = false;
  String? _error;
  String? _currentUserId;

  Map<String, dynamic> get stats => _stats;
  List<Map<String, dynamic>> get recentEnquiries => _recentEnquiries;
  List<Map<String, dynamic>> get recentVisits => _recentVisits;
  List<Map<String, dynamic>> get recentFollowUps => _recentFollowUps;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setCurrentUser(String userId) {
    _currentUserId = userId;
    // Clear existing data when user changes
    _stats = {};
    _recentEnquiries = [];
    _recentVisits = [];
    _recentFollowUps = [];
    notifyListeners();
  }

  Future<void> loadDashboardData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // If no current user is set, try to load general data
      if (_currentUserId == null || _currentUserId == 'admin_001') {
        // Load general stats for admin or when no user is set
        await _loadGeneralData();
      } else {
        // Load user-specific data
        await _loadUserSpecificData();
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Method to update current user and reload data
  Future<void> updateCurrentUser(String? userId) async {
    if (userId != null && userId != _currentUserId) {
      setCurrentUser(userId);
      await loadDashboardData();
    } else if (userId == null && _currentUserId != null) {
      // Clear user and load general data
      _currentUserId = null;
      await _loadGeneralData();
    }
  }

  Future<void> _loadGeneralData() async {
    try {
      // Load dashboard statistics
      _stats = await FirebaseService.getDashboardStats();

      // Load recent data
      final enquiries = await FirebaseService.getEnquiries();
      _recentEnquiries = enquiries.take(5).toList();

      final visits = await FirebaseService.getCollegeVisits();
      _recentVisits = visits.take(5).toList();

      final followUps = await FirebaseService.getFollowUps();
      _recentFollowUps = followUps.take(5).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserSpecificData() async {
    try {
      // Load user-specific dashboard statistics
      _stats = await FirebaseService.getUserDashboardStats(_currentUserId!);

      // Load user-specific recent data
      final enquiries = await FirebaseService.getUserEnquiries(_currentUserId!);
      _recentEnquiries = enquiries.take(5).toList();

      final visits = await FirebaseService.getUserCollegeVisits(
        _currentUserId!,
      );
      _recentVisits = visits.take(5).toList();

      final followUps = await FirebaseService.getUserFollowUps(_currentUserId!);
      _recentFollowUps = followUps.take(5).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshData() async {
    await loadDashboardData();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Get today's follow-ups
  List<Map<String, dynamic>> get todayFollowUps {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _recentFollowUps.where((followUp) {
      final followUpDate = followUp['followUpDate'] as Timestamp?;
      if (followUpDate != null) {
        final date = followUpDate.toDate();
        return date.isAfter(today) || date.isAtSameMomentAs(today);
      }
      return false;
    }).toList();
  }

  // Get today's tasks
  List<Map<String, dynamic>> get todayTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _recentFollowUps.where((task) {
      final dueDate = task['dueDate'] as Timestamp?;
      if (dueDate != null) {
        final date = dueDate.toDate();
        return date.isAfter(today) || date.isAtSameMomentAs(today);
      }
      return false;
    }).toList();
  }
}
