import 'package:cloud_firestore/cloud_firestore.dart';

class LeadModel {
  final String id;
  final String name;
  final String phone;
  final String source;
  final String label;
  final String status;
  final DateTime createdAt;
  final DateTime lastContacted;

  LeadModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.source,
    required this.label,
    required this.status,
    required this.createdAt,
    required this.lastContacted,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'source': source,
      'label': label,
      'status': status,
      'created_at': createdAt,
      'last_contacted': lastContacted,
    };
  }

  factory LeadModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return LeadModel(
      id: doc.id,
      name: data['name'] ?? 'Unknown',
      phone: data['phone'] ?? '',
      source: data['source'] ?? 'Incoming Call',
      label: data['label'] ?? 'Unknown',
      status: data['status'] ?? 'New Inquiry',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastContacted: (data['last_contacted'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
