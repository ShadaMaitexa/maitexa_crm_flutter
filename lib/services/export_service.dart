import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Conditional imports for Web vs Mobile
import 'export_stub.dart'
    if (dart.library.html) 'export_web.dart'
    if (dart.library.io) 'export_mobile.dart';

class ExportService {
  static Future<void> exportCallsToCsv(List<Map<String, dynamic>> calls, String fileName) async {
    if (calls.isEmpty) return;

    final List<String> csvRows = [];
    
    // Header
    csvRows.add('Date,Time,Type,Number,Label,Duration(s),User,Notes');

    for (var call in calls) {
      final dateObj = call['timestamp'] ?? call['created_at'];
      DateTime dt = DateTime.now();
      if (dateObj is Timestamp) dt = dateObj.toDate();
      else if (dateObj is int) dt = DateTime.fromMillisecondsSinceEpoch(dateObj);
      else if (dateObj is DateTime) dt = dateObj;

      final dateStr = DateFormat('yyyy-MM-dd').format(dt);
      final timeStr = DateFormat('HH:mm').format(dt);
      final type = call['call_type'] ?? 'Unknown';
      final number = call['phone_number'] ?? call['number'] ?? '';
      final label = call['label'] ?? '';
      final duration = call['duration'] ?? 0;
      final userName = call['userName'] ?? 'Unknown';
      
      // Combine notes
      String notesStr = '';
      if (call['notes'] is List) {
        notesStr = (call['notes'] as List).map((n) => n['note']?.toString() ?? '').join(' | ');
      }
      
      // Escape commas for CSV
      final escapedNotes = notesStr.replaceAll(',', ';');
      
      csvRows.add('$dateStr,$timeStr,$type,$number,$label,$duration,$userName,"$escapedNotes"');
    }

    final String csvContent = csvRows.join('\n');
    
    await FileSaver.saveAndShare(csvContent, '${fileName}.csv');
  }
}

abstract class FileSaver {
  static Future<void> saveAndShare(String content, String fileName) async {
    throw UnimplementedError('saveAndShare must be implemented in platform specific files');
  }
}
