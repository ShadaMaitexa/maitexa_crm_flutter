import 'package:cloud_firestore/cloud_firestore.dart';

class NoteModel {
  final String id;
  final String leadId;
  final String note;
  final DateTime createdAt;

  NoteModel({
    required this.id,
    required this.leadId,
    required this.note,
    required this.createdAt,
  });

  factory NoteModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return NoteModel(
      id: doc.id,
      leadId: data['lead_id'] ?? '',
      note: data['note'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
