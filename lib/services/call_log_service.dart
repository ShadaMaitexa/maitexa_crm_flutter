import 'package:call_log/call_log.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_service.dart';

class CallLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      // 2. Fetch Call Logs (Last 24 hours for efficiency or use a last sync timestamp)
      // For now, let's just fetch all and rely on deduplication or limit to recent.
      Iterable<CallLogEntry> entries = await CallLog.get();

      for (var entry in entries) {
        await _processCallLogEntry(entry);
      }
    }
  }

  Future<void> _processCallLogEntry(CallLogEntry entry) async {
    if (entry.number == null) return;

    String phoneNumber = entry.number!;
    // Clean phone number (remove spaces, etc. if needed)
    // For simplicity, we keep it as is or do basic cleaning
    phoneNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');

    // Check for duplicate call entry in Firestore
    // We can use a unique ID based on number and timestamp
    String callDocId = '${phoneNumber}_${entry.timestamp}';
    
    var doc = await _firestore.collection('calls').doc(callDocId).get();
    if (doc.exists) return; // Skip if already synced

    // Determine call type
    String callType = _getCallTypeString(entry.callType);

    // 1. Check if lead exists
    String? leadId = await _findOrCreateLead(phoneNumber);

    // 2. Record Call
    await _firestore.collection('calls').doc(callDocId).set({
      'phone_number': phoneNumber,
      'call_type': callType,
      'timestamp': DateTime.fromMillisecondsSinceEpoch(entry.timestamp ?? 0),
      'duration': entry.duration ?? 0,
      'label': 'Unknown', // Default label
      'lead_id': leadId,
    });
    
    // 3. Record Activity if lead exists
    if (leadId != null) {
      await recordActivity(leadId, callType, 'Call recorded from logs');
    }
  }

  Future<String?> _findOrCreateLead(String phoneNumber) async {
    try {
      var snapshot = await _firestore
          .collection('leads')
          .where('phone', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      } else {
        // Create new lead
        var docRef = await _firestore.collection('leads').add({
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

  Future<void> recordActivity(String leadId, String type, String desc) async {
     await _firestore.collection('lead_activities').add({
        'lead_id': leadId,
        'activity_type': type,
        'description': desc,
        'timestamp': FieldValue.serverTimestamp(),
      });
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
