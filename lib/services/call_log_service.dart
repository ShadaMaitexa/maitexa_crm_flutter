import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_service.dart';

class CallLogService {
  static Future<bool> requestPermissions() async {
    final status = await [
      Permission.phone,
      Permission.contacts,
      Permission.callLog,
    ].request();
    
    // In Android, READ_CALL_LOG is often tied to phone permission or separate
    final callLogStatus = await Permission.callLog.status;
    return callLogStatus.isGranted;
  }

  static Future<Iterable<CallLogEntry>> getLocalCallLogs() async {
    return await CallLog.get();
  }

  static Future<void> syncCallToFirebase(CallLogEntry entry, String category) async {
    await FirebaseService.recordCall({
      'number': entry.number,
      'name': entry.name,
      'duration': entry.duration,
      'timestamp': entry.timestamp,
      'type': entry.callType.toString(),
      'category': category,
    });
  }

  static String getCallTypeString(CallType? type) {
    if (type == null) return 'Unknown';
    switch (type) {
      case CallType.incoming:
        return 'Incoming';
      case CallType.outgoing:
        return 'Outgoing';
      case CallType.missed:
        return 'Missed';
      case CallType.voiceMail:
        return 'Voicemail';
      case CallType.rejected:
        return 'Rejected';
      case CallType.blocked:
        return 'Blocked';
      case CallType.answerExternally:
        return 'Answered Externally';
      case CallType.unknown:
        return 'Unknown';
      default:
        return 'Unknown';
    }
  }
}
