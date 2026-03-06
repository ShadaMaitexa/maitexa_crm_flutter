import 'package:cloud_firestore/cloud_firestore.dart';

class LabelModel {
  final String id;
  final String labelName;

  LabelModel({
    required this.id,
    required this.labelName,
  });

  factory LabelModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return LabelModel(
      id: doc.id,
      labelName: data['label_name'] ?? '',
    );
  }
}
