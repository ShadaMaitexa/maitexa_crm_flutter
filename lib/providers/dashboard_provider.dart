import 'dart:async';
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

  StreamSubscription? _enquiriesSubscription;
  StreamSubscription? _visitsSubscription;
  StreamSubscription? _followUpsSubscription;

  Map<String, dynamic> get stats => _stats;
  List<Map<String, dynamic>> get recentEnquiries => _recentEnquiries;
  List<Map<String, dynamic>> get recentVisits => _recentVisits;
  List<Map<String, dynamic>> get recentFollowUps => _recentFollowUps;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setCurrentUser(String userId) {
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    // Clear existing data when user changes
    _stats = {};
    _recentEnquiries = [];
    _recentVisits = [];
    _recentFollowUps = [];
    
    _setupListeners();
    notifyListeners();
  }

  void _setupListeners() {
    _enquiriesSubscription?.cancel();
    _visitsSubscription?.cancel();
    _followUpsSubscription?.cancel();

    // Setup listeners to automatically refresh dashboard data when Firestore changes
    _enquiriesSubscription = FirebaseService.getEnquiriesStream().listen((_) {
      loadDashboardData(silent: true);
    });
    _visitsSubscription = FirebaseService.getCollegeVisitsStream().listen((_) {
      loadDashboardData(silent: true);
    });
    _followUpsSubscription = FirebaseService.getFollowUpsStream().listen((_) {
      loadDashboardData(silent: true);
    });
  }

  Future<void> loadDashboardData({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      // 1. Get base dashboard stats
      if (_currentUserId == null || _currentUserId == 'admin_001') {
        _stats = await FirebaseService.getDashboardStats();
      } else {
        _stats = await FirebaseService.getUserDashboardStats(_currentUserId!);
      }

      // 2. Get Sales Analytics and merge/override
      final salesStats = await FirebaseService.getSalesAnalytics();
      _stats.addAll({
        'todayCalls': salesStats['todayTotalCallsCount'], 
        'incomingCalls': salesStats['todayIncomingCount'],
        'outgoingCalls': salesStats['todayOutgoingCount'],
        'missedCalls': salesStats['missedCallsCount'],
        'convertedLeads': salesStats['convertedLeadsCount'],
        'pendingFollowUps': salesStats['pendingFollowUpsCount'],
      });

      // 3. Load recent data based on user role
      if (_currentUserId == null || _currentUserId == 'admin_001') {
        _recentEnquiries = await FirebaseService.getEnquiries();
        _recentVisits = await FirebaseService.getCollegeVisits();
        _recentFollowUps = await FirebaseService.getFollowUps();
      } else {
        _recentEnquiries = await FirebaseService.getUserEnquiries(_currentUserId!);
        _recentVisits = await FirebaseService.getUserCollegeVisits(_currentUserId!);
        _recentFollowUps = await FirebaseService.getUserFollowUps(_currentUserId!);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (!silent) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      }
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
    final tomorrow = today.add(const Duration(days: 1));

    return _recentFollowUps.where((followUp) {
      final followUpDate = followUp['followUpDate'] as Timestamp?;
      if (followUpDate != null) {
        final date = followUpDate.toDate();
        // Return if date is today (between start of today and start of tomorrow)
        return date.isAfter(today.subtract(const Duration(seconds: 1))) && 
               date.isBefore(tomorrow);
      }
      return false;
    }).toList();
  }

  // Get today's tasks
  List<Map<String, dynamic>> get todayTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return _recentFollowUps.where((task) {
      final dueDate = task['dueDate'] as Timestamp?;
      if (dueDate != null) {
        final date = dueDate.toDate();
        return date.isAfter(today.subtract(const Duration(seconds: 1))) && 
               date.isBefore(tomorrow);
      }
      return false;
    }).toList();
  }

  @override
  void dispose() {
    _enquiriesSubscription?.cancel();
    _visitsSubscription?.cancel();
    _followUpsSubscription?.cancel();
    super.dispose();
  }
}
