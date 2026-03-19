import 'package:call_log/call_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_service.dart';

/// Holds information about one physical SIM slot retrieved from Android.
class SimInfo {
  final int subscriptionId;
  final int slotIndex;
  final String phoneNumber; // may be empty if carrier hides it
  final String displayName;
  final String iccId;

  SimInfo({
    required this.subscriptionId,
    required this.slotIndex,
    required this.phoneNumber,
    required this.displayName,
    required this.iccId,
  });

  @override
  String toString() =>
      'SimInfo(subId=$subscriptionId, slot=$slotIndex, number=$phoneNumber, name=$displayName)';
}

class CallLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const MethodChannel _simChannel =
      MethodChannel('com.maitexa.crm/sim_info');

  // ───────────────────────── Permissions ─────────────────────────

  static Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.phone,
      Permission.contacts,
    ].request();

    return statuses[Permission.phone]?.isGranted ?? false;
  }

  // ───────────────────────── SIM info from Android ───────────────

  /// Queries Android TelephonyManager via MethodChannel to get info about
  /// every active SIM installed on the device.
  /// Returns an empty list on iOS, web, or if permissions are denied.
  static Future<List<SimInfo>> getDeviceSimInfoList() async {
    if (!defaultTargetPlatform.toString().contains('android') &&
        defaultTargetPlatform != TargetPlatform.android) {
      return [];
    }
    try {
      final List<dynamic> raw =
          await _simChannel.invokeMethod('getSimPhoneNumbers');
      return raw.map((item) {
        final m = Map<String, dynamic>.from(item as Map);
        return SimInfo(
          subscriptionId: (m['subscriptionId'] as int?) ?? -1,
          slotIndex: (m['slotIndex'] as int?) ?? -1,
          phoneNumber: (m['phoneNumber'] as String?) ?? '',
          displayName: (m['displayName'] as String?) ?? 'SIM',
          iccId: (m['iccId'] as String?) ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('Error reading SIM info from platform: $e');
      return [];
    }
  }

  // ───────────────────────── Matching ────────────────────────────

  /// Given the user's registered phone number (with or without country code)
  /// and the list of SIMs on the device, tries to find the matching SIM.
  ///
  /// Matching strategy (ordered by reliability):
  ///   1. Last-10-digit suffix match of the SIM's phone number vs registered number.
  ///   2. If no SIM phone numbers are available (carrier restriction), fall back
  ///      to inspecting the call-log's `phoneAccountId` against subscription IDs.
  static SimInfo? findMatchingSim(
    List<SimInfo> sims,
    String registeredPhone,
  ) {
    if (sims.isEmpty || registeredPhone.isEmpty) return null;

    // Normalise registered phone to last 10 digits
    final regDigits = registeredPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final regShort = regDigits.length >= 10
        ? regDigits.substring(regDigits.length - 10)
        : regDigits;

    for (final sim in sims) {
      if (sim.phoneNumber.isEmpty) continue;
      final simDigits = sim.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (simDigits.endsWith(regShort)) {
        debugPrint('[SimMatch] Phone match → ${sim.displayName} (subId=${sim.subscriptionId})');
        return sim;
      }
    }

    debugPrint('[SimMatch] No phone number match found among ${sims.length} SIMs.');
    return null;
  }

  // ───────────────────────── Call log filtering ──────────────────

  /// Filters [allLogs] to only include entries that belong to [sim].
  ///
  /// On Android 14+, `phoneAccountId` in call logs is an internal slot ID
  /// (integer string "0" / "1") or a UUID — NOT the phone number.
  ///
  /// We match using two approaches:
  ///   1. If `phoneAccountId` is a small integer (0/1), map it to slot index.
  ///   2. Try to match the subscription ID string representation.
  ///   3. Fall back to matching `simDisplayName` vs the SIM's displayName.
  static Iterable<CallLogEntry> filterLogsBySim(
    Iterable<CallLogEntry> allLogs,
    SimInfo sim,
  ) {
    return allLogs.where((log) {
      // Only include answered / dialled calls
      final type = log.callType;
      if (type != CallType.incoming &&
          type != CallType.outgoing &&
          type != CallType.missed) {
        // include missed too so user sees full picture
      }

      final accountId = log.phoneAccountId?.trim() ?? '';
      final simName = log.simDisplayName?.trim() ?? '';

      // ── Strategy 1: phoneAccountId is a small integer (slot index) ──
      final maybeInt = int.tryParse(accountId);
      if (maybeInt != null && maybeInt >= 0 && maybeInt <= 5) {
        return maybeInt == sim.slotIndex;
      }

      // ── Strategy 2: phoneAccountId matches subscriptionId ──
      if (accountId == sim.subscriptionId.toString()) {
        return true;
      }

      // ── Strategy 3: simDisplayName matches (carrier name / "SIM 1" etc.) ──
      if (simName.isNotEmpty) {
        if (simName.toLowerCase() == sim.displayName.toLowerCase()) {
          return true;
        }
        // "SIM 1" / "slot1" etc.
        final slotLabel = 'SIM ${sim.slotIndex + 1}';
        if (simName == slotLabel) return true;
        // Some OEMs write slot index directly as sim display name
        if (simName == sim.slotIndex.toString()) return true;
      }

      // ── Strategy 4: If we only have ONE sim, include everything ──
      // (single-SIM device — all logs belong to that sim)
      // We intentionally don't do this here; caller decides.

      return false;
    });
  }

  // ───────────────────────── Helpers ─────────────────────────────

  static Future<Iterable<CallLogEntry>> getLocalCallLogs() async {
    return await CallLog.get();
  }

  /// Normalizes the SIM identifier into a human-readable label like "SIM 1" or "SIM 2".
  ///
  /// IMPORTANT: `phoneAccountId` on Android is an internal system account ID
  /// (slot index, ICCID, or UUID), NOT the SIM's phone number. We must never
  /// treat it as the registered phone number. We only use it to infer slot index.
  static String normalizeSimId(String? simDisplayName,
      {String? phoneAccountId}) {
    // Step 1: Try to parse a meaningful label from simDisplayName first
    if (simDisplayName != null && simDisplayName.trim().isNotEmpty) {
      final display = simDisplayName.trim();
      final lower = display.toLowerCase().replaceAll(' ', '');

      // Explicit SIM slot patterns in display name
      if (lower == 'sim1' ||
          lower == 'sim 1' ||
          lower.contains('sim1') ||
          lower.contains('slot1') ||
          lower.contains('slot 1')) {
        return 'SIM 1';
      }
      if (lower == 'sim2' ||
          lower == 'sim 2' ||
          lower.contains('sim2') ||
          lower.contains('slot2') ||
          lower.contains('slot 2')) {
        return 'SIM 2';
      }

      // If simDisplayName is a short index (some devices report '0' or '1')
      if (display == '0') return 'SIM 1';
      if (display == '1') return 'SIM 2';

      // If simDisplayName is a carrier/operator name or any reasonable label, use it as-is
      // but only if it doesn't look like a raw system ID (ICCID is 19-20 digits, UUID has dashes)
      final isLikelySystemId =
          RegExp(r'^[0-9a-f\-]{10,}$', caseSensitive: false)
              .hasMatch(display);
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
      // For anything else (ICCID, UUID, etc.), do NOT use as label — fall through
    }

    return 'Unknown SIM';
  }

  static Future<List<String>> getAvailableSims(
      {Iterable<CallLogEntry>? logs}) async {
    await requestPermissions();
    if (logs == null || logs.isEmpty) {
      return ['SIM 1', 'SIM 2'];
    }

    final Set<String> sims = {};
    for (var entry in logs) {
      sims.add(normalizeSimId(entry.simDisplayName,
          phoneAccountId: entry.phoneAccountId));
    }

    if (sims.isEmpty) return ['SIM 1', 'SIM 2'];
    final sortedSims = sims.toList()..sort();
    return sortedSims;
  }

  // ───────────────────────── Firebase sync ───────────────────────

  Future<void> syncCallLogs(String userId) async {
    final permissions = await requestPermissions();
    if (!permissions) return;

    final userDoc = await _firestore
        .collection(FirebaseService.usersCollection)
        .doc(userId)
        .get();
    String? userPhone = userDoc.exists
        ? (userDoc.data()?['phone'] as String?)
            ?.replaceAll(RegExp(r'\s+'), '')
        : null;

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

    String phoneNumber =
        entry.number!.replaceAll(RegExp(r'\s+'), '');

    // Normalize with +91 if needed
    if (phoneNumber.length == 10 &&
        RegExp(r'^[0-9]+$').hasMatch(phoneNumber)) {
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

    final existingLabel =
        await FirebaseService.getNumberCategory(phoneNumber);

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
      'timestamp':
          DateTime.fromMillisecondsSinceEpoch(entry.timestamp ?? 0),
      'duration': entry.duration ?? 0,
      'label': existingLabel ?? 'Unknown',
      'lead_id': leadId,
      'userId': userId,
      'user_id': userId,
      'createdBy': userId,
      'sim_name': entry.simDisplayName ?? 'Unknown',
      'notes': [],
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
      debugPrint('Error finding/creating lead: $e');
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
