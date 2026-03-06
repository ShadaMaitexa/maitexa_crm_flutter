import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityModel {
  final String id;
  final String leadId;
  final String activityType;
  final String description;
  final DateTime timestamp;

  ActivityModel({
    required this.id,
    required this.leadId,
    required this.activityType,
    required this.description,
    required this.timestamp,
  });

  factory ActivityModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ActivityModel(
      id: doc.id,
      leadId: data['lead_id'] ?? '',
      activityType: data['activity_type'] ?? '',
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
