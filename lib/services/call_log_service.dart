import 'package:call_log/call_log.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_service.dart';

class CallLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<bool> requestPermissions() async {
    var status = await Permission.phone.status;
    if (!status.isGranted) {
      status = await Permission.phone.request();
    }
    var logStatus = await Permission.contacts.status;
    if (!logStatus.isGranted) {
      logStatus = await Permission.contacts.request();
    }
    return status.isGranted || logStatus.isGranted;
  }

  static Future<Iterable<CallLogEntry>> getLocalCallLogs() async {
    return await CallLog.get();
  }

  static String normalizeSimId(String? simId) {
    if (simId == null || simId.trim().isEmpty) return 'Unknown SIM';
    final trimmed = simId.trim();
    if (trimmed == '0') return 'SIM 1';
    if (trimmed == '1') return 'SIM 2';
    if (trimmed == '2') return 'SIM 3';
    
    final upper = trimmed.toUpperCase().replaceAll(' ', '');
    if (upper == 'SIM1') return 'SIM 1';
    if (upper == 'SIM2') return 'SIM 2';
    
    return trimmed;
  }

  static Future<List<String>> getAvailableSims() async {
    await requestPermissions(); // Ensure perms

    return ['SIM 1', 'SIM 2'];
  }

  Future<void> syncCallLogs() async {
    // 1. Request Permission
    var status = await Permission.phone.status;
    if (!status.isGranted) {
      status = await Permission.phone.request();
    }

    var logStatus = await Permission.contacts.status;
    if (!logStatus.isGranted) {
      logStatus = await Permission.contacts.request();
    }

    if (await Permission.phone.isGranted) {
      // 2. Fetch Call Logs (all available logs on device)
      // We process them to ensure they are persisted in our CRM (Firebase)
      Iterable<CallLogEntry> entries = await CallLog.get();

      // Sort by timestamp descending
      final listToProcess = entries.toList();
      listToProcess.sort(
        (a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0),
      );

      // Cache lead IDs during this sync session to avoid redundant Firestore lookups
      final Map<String, String?> leadIdCache = {};

      // Limit to 2000 most recent records to prevent indefinite syncing on very old devices
      // while still capturing effectively 'all' relevant history.
      for (var entry in listToProcess.take(2000)) {
        try {
          await _processCallLogEntry(entry, leadIdCache: leadIdCache);
        } catch (e) {
          debugPrint('Error syncing individual call log: $e');
        }
      }
    }
  }

  Future<void> _processCallLogEntry(
    CallLogEntry entry, {
    Map<String, String?>? leadIdCache,
  }) async {
    if (entry.number == null) return;

    String phoneNumber = entry.number!;
    // Clean phone number (remove spaces, etc. if needed)
    // For simplicity, we keep it as is or do basic cleaning
    phoneNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');

    // Check for duplicate call entry in Firestore
    // We can use a unique ID based on number and timestamp
    String callDocId = '${phoneNumber}_${entry.timestamp}';

    var doc = await _firestore
        .collection(FirebaseService.callsCollection)
        .doc(callDocId)
        .get();
    if (doc.exists) return; // Skip if already synced

    // Determine call type
    String callType = _getCallTypeString(entry.callType);

    // 1. Check if lead exists
    String? leadId = await _findOrCreateLead(
      phoneNumber,
      leadIdCache: leadIdCache,
    );

    // 2. Record Call
    await _firestore
        .collection(FirebaseService.callsCollection)
        .doc(callDocId)
        .set({
          'phone_number': phoneNumber,
          'call_type': callType,
          'timestamp': DateTime.fromMillisecondsSinceEpoch(
            entry.timestamp ?? 0,
          ),
          'duration': entry.duration ?? 0,
          'label': 'Unknown', // Default label
          'lead_id': leadId,
        });

    // 3. Record Activity if lead exists
    if (leadId != null) {
      await FirebaseService.addActivity(
        leadId,
        callType,
        'Call recorded from logs',
      );
    }
  }

  Future<String?> _findOrCreateLead(
    String phoneNumber, {
    Map<String, String?>? leadIdCache,
  }) async {
    if (leadIdCache != null && leadIdCache.containsKey(phoneNumber)) {
      return leadIdCache[phoneNumber];
    }

    try {
      var snapshot = await _firestore
          .collection(FirebaseService.leadsCollection)
          .where('phone', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final leadId = snapshot.docs.first.id;
        leadIdCache?[phoneNumber] = leadId;
        return leadId;
      } else {
        // Create new lead
        var docRef = await _firestore
            .collection(FirebaseService.leadsCollection)
            .add({
              'name': 'Unknown',
              'phone': phoneNumber,
              'source': 'Incoming Call',
              'label': 'Unknown',
              'status': 'New Inquiry',
              'created_at': FieldValue.serverTimestamp(),
              'last_contacted': FieldValue.serverTimestamp(),
            });
        return docRef.id;
      }
    } catch (e) {
      print('Error finding/creating lead: $e');
      return null;
    }
  }

  String _getCallTypeString(CallType? type) {
    switch (type) {
      case CallType.incoming:
        return 'incoming';
      case CallType.outgoing:
        return 'outgoing';
      case CallType.missed:
        return 'missed';
      case CallType.rejected:
        return 'missed';
      default:
        return 'missed';
    }
  }
}
