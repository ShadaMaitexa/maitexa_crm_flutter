import 'package:call_log/call_log.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_service.dart';

class CallLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.phone,
      Permission.contacts,
    ].request();

    return statuses[Permission.phone]?.isGranted ?? false;
  }

  static Future<Iterable<CallLogEntry>> getLocalCallLogs() async {
    return await CallLog.get();
  }

  static String normalizeSimId(String? simId) {
    if (simId == null || simId.trim().isEmpty) return 'Unknown SIM';
    final trimmed = simId.trim();
    if (trimmed == '0') return 'SIM 1';
    if (trimmed == '1') return 'SIM 2';
    final lower = trimmed.toLowerCase().replaceAll(' ', '');
    if (lower.contains('sim0') || lower.contains('sim1')) return 'SIM 1';
    if (lower.contains('sim2')) return 'SIM 2';
    return trimmed;
  }

  static Future<List<String>> getAvailableSims({Iterable<CallLogEntry>? logs}) async {
    await requestPermissions();
    if (logs == null || logs.isEmpty) {
      return ['SIM 1', 'SIM 2'];
    }

    final Set<String> sims = {};
    for (var entry in logs) {
      if (entry.simDisplayName != null && entry.simDisplayName!.isNotEmpty) {
        sims.add(normalizeSimId(entry.simDisplayName));
      }
    }

    if (sims.isEmpty) return ['SIM 1', 'SIM 2'];
    final sortedSims = sims.toList()..sort();
    return sortedSims;
  }

  Future<void> syncCallLogs(String userId) async {
    final permissions = await requestPermissions();
    if (!permissions) return;

    final userDoc = await _firestore.collection(FirebaseService.usersCollection).doc(userId).get();
    String? userPhone = userDoc.exists ? (userDoc.data()?['phone'] as String?)?.replaceAll(RegExp(r'\s+'), '') : null;
    
    String? userPhoneShort = userPhone;
    if (userPhoneShort != null && userPhoneShort.length > 10) {
      userPhoneShort = userPhoneShort.substring(userPhoneShort.length - 10);
    }

    if (await Permission.phone.isGranted) {
      Iterable<CallLogEntry> entries = await CallLog.get();
      final listToProcess = entries.toList();
      listToProcess.sort(
        (a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0),
      );

      final Map<String, String?> leadIdCache = {};

      for (var entry in listToProcess.take(2000)) {
        try {
          // Log only from registered SIM if possible
          if (userPhoneShort != null && entry.simDisplayName != null) {
             // We can log specific SIM name for transparency
          }
          await _processCallLogEntry(entry, userId, leadIdCache: leadIdCache);
        } catch (e) {
          debugPrint('Error syncing individual call log: $e');
        }
      }
    }
  }

  Future<void> _processCallLogEntry(
    CallLogEntry entry,
    String userId, {
    Map<String, String?>? leadIdCache,
  }) async {
    if (entry.number == null) return;

    String phoneNumber = entry.number!.replaceAll(RegExp(r'\s+'), '');
    
    // Normalize with +91 if needed
    if (phoneNumber.length == 10 && RegExp(r'^[0-9]+$').hasMatch(phoneNumber)) {
      phoneNumber = '+91$phoneNumber';
    } else if (phoneNumber.length == 12 && phoneNumber.startsWith('91')) {
      phoneNumber = '+$phoneNumber';
    }

    String callDocId = '${phoneNumber}_${entry.timestamp}';

    var doc = await _firestore
        .collection(FirebaseService.callsCollection)
        .doc(callDocId)
        .get();
    if (doc.exists) return;

    String callType = _getCallTypeString(entry.callType);
    
    final existingLabel = await FirebaseService.getNumberCategory(phoneNumber);

    String? leadId = await _findOrCreateLead(
      phoneNumber,
      userId,
      leadIdCache: leadIdCache,
    );

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
          'label': existingLabel ?? 'Unknown',
          'lead_id': leadId,
          'userId': userId,
          'user_id': userId,
          'createdBy': userId,
          'sim_name': entry.simDisplayName ?? 'Unknown',
          'notes': [], // Unified storage
        });

    if (leadId != null) {
      await FirebaseService.addActivity(
        leadId,
        callType,
        'Call recorded from logs',
      );
    }
  }

  Future<String?> _findOrCreateLead(
    String phoneNumber,
    String userId, {
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
              'createdBy': userId,
              'user_id': userId,
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
