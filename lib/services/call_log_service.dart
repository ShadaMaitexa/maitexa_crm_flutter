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

  /// Normalizes the SIM identifier into a human-readable label like "SIM 1" or "SIM 2".
  /// 
  /// IMPORTANT: `phoneAccountId` on Android is an internal system account ID
  /// (slot index, ICCID, or UUID), NOT the SIM's phone number. We must never
  /// treat it as the registered phone number. We only use it to infer slot index.
  static String normalizeSimId(String? simDisplayName, {String? phoneAccountId}) {
    // Step 1: Try to parse a meaningful label from simDisplayName first
    if (simDisplayName != null && simDisplayName.trim().isNotEmpty) {
      final display = simDisplayName.trim();
      final lower = display.toLowerCase().replaceAll(' ', '');

      // Explicit SIM slot patterns in display name
      if (lower == 'sim1' || lower == 'sim 1' || lower.contains('sim1') || lower.contains('slot1') || lower.contains('slot 1')) {
        return 'SIM 1';
      }
      if (lower == 'sim2' || lower == 'sim 2' || lower.contains('sim2') || lower.contains('slot2') || lower.contains('slot 2')) {
        return 'SIM 2';
      }

      // If simDisplayName is a short index (some devices report '0' or '1')
      if (display == '0') return 'SIM 1';
      if (display == '1') return 'SIM 2';

      // If simDisplayName is a carrier/operator name or any reasonable label, use it as-is
      // but only if it doesn't look like a raw system ID (ICCID is 19-20 digits, UUID has dashes)
      final isLikelySystemId = RegExp(r'^[0-9a-f\-]{10,}$', caseSensitive: false).hasMatch(display);
      if (!isLikelySystemId) {
        return display; // e.g. "Airtel", "Jio", "BSNL"
      }
    }

    // Step 2: Fall back to phoneAccountId only to infer the slot index
    if (phoneAccountId != null && phoneAccountId.trim().isNotEmpty) {
      final accId = phoneAccountId.trim();
      // Some devices use '0' / '1' as phoneAccountId for slot index
      if (accId == '0') return 'SIM 1';
      if (accId == '1') return 'SIM 2';
      // Some use 'SIM1'/'SIM2' style
      final lower = accId.toLowerCase().replaceAll(' ', '');
      if (lower.contains('sim1') || lower.contains('slot1')) return 'SIM 1';
      if (lower.contains('sim2') || lower.contains('slot2')) return 'SIM 2';
      // For anything else (ICCID, UUID, etc.), do NOT use as label — fall through to Unknown
    }

    return 'Unknown SIM';
  }

  static Future<List<String>> getAvailableSims({Iterable<CallLogEntry>? logs}) async {
    await requestPermissions();
    if (logs == null || logs.isEmpty) {
      return ['SIM 1', 'SIM 2'];
    }

    final Set<String> sims = {};
    for (var entry in logs) {
      sims.add(normalizeSimId(entry.simDisplayName, phoneAccountId: entry.phoneAccountId));
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
