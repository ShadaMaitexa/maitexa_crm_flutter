import 'package:flutter/material.dart';
import '../services/call_log_service.dart';
import '../services/firebase_service.dart';

class CallProvider with ChangeNotifier {
  final CallLogService _callLogService = CallLogService();
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  Future<void> syncCalls(String userId) async {
    _isSyncing = true;
    notifyListeners();
    try {
      await _callLogService.syncCallLogs(userId);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> updateCallLabel(String callId, String label) async {
    await FirebaseService.updateCallLabel(callId, label);
  }
}
