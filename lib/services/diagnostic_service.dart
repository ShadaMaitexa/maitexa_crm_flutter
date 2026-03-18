import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DiagnosticService {
  static Future<void> debugUserData() async {
    final firestore = FirebaseFirestore.instance;
    debugPrint('--- SERVER DIAGNOSTIC START ---');
    
    try {
      // Force read from Server only to avoid cache confusion
      final calls = await firestore.collection('calls').limit(10).get(const GetOptions(source: Source.server));
      debugPrint('SERVER: Found ${calls.docs.length} calls');
      for (var doc in calls.docs) {
        final data = doc.data();
        debugPrint('SERVER SAMPLE: ID=${doc.id}, userId=${data['userId']}');
      }

      final users = await firestore.collection('users').get(const GetOptions(source: Source.server));
      debugPrint('SERVER: Found ${users.docs.length} users in total');
      for (var doc in users.docs) {
        debugPrint('SERVER USER: ID=${doc.id}, Name=${doc.data()['name']}');
      }
    } catch (e) {
      debugPrint('DIAGNOSTIC ERROR: $e');
    }
    
    debugPrint('--- SERVER DIAGNOSTIC END ---');
  }
}
