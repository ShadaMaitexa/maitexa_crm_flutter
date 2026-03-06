import 'package:cloud_firestore/cloud_firestore.dart';

class CallModel {
  final String id;
  final String phoneNumber;
  final String callType; // incoming / outgoing / missed
  final DateTime timestamp;
  final int duration;
  final String label;
  final String? leadId;

  CallModel({
    required this.id,
    required this.phoneNumber,
    required this.callType,
    required this.timestamp,
    required this.duration,
    required this.label,
    this.leadId,
  });

  Map<String, dynamic> toMap() {
    return {
      'phone_number': phoneNumber,
      'call_type': callType,
      'timestamp': timestamp,
      'duration': duration,
      'label': label,
      'lead_id': leadId,
    };
  }

  factory CallModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CallModel(
      id: doc.id,
      phoneNumber: data['phone_number'] ?? '',
      callType: data['call_type'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      duration: data['duration'] ?? 0,
      label: data['label'] ?? '',
      leadId: data['lead_id'],
    );
  }
}
