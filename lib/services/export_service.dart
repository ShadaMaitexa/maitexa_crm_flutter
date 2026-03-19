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
    
    // Intelligence-rich Header for business reporting
    csvRows.add('Date,Time,Type,Number,Label,Status,Duration(s),Staff,Hot Deal,Converted,Follow-Up,FU Staff,FU Note,Notes');

    for (var call in calls) {
      final dateObj = call['timestamp'] ?? call['created_at'] ?? call['createdAt'];
      DateTime dt = DateTime.now();
      if (dateObj is Timestamp) dt = dateObj.toDate();
      else if (dateObj is int) dt = DateTime.fromMillisecondsSinceEpoch(dateObj);
      else if (dateObj is DateTime) dt = dateObj;

      final dateStr = DateFormat('yyyy-MM-dd').format(dt);
      final timeStr = DateFormat('HH:mm').format(dt);
      final type = call['call_type'] ?? call['type'] ?? 'Unknown';
      final number = call['phone_number'] ?? call['number'] ?? '';
      final label = call['label'] ?? '';
      final status = call['status'] ?? '';
      final duration = call['duration'] ?? 0;
      final userName = call['userName'] ?? 'Unknown';
      final isHot = (call['isHot'] == true || label.toString().toLowerCase().contains('hot')) ? 'YES' : 'NO';
      final isConverted = (call['isConverted'] == true) ? 'YES' : 'NO';
      final followUp = call['followUpDate'] ?? 'None';
      final fuStaff = call['followUpStaff'] ?? 'None';
      final fuNote = call['followUpNote'] ?? '';
      
      // Combine notes
      String notesStr = '';
      if (call['notes'] is List) {
        notesStr = (call['notes'] as List).map((n) {
          if (n is Map) return (n['note'] ?? n['message'] ?? '').toString();
          return n.toString();
        }).join(' | ');
      } else if (call['note'] != null) {
        notesStr = call['note'].toString();
      }
      
      // Escape for CSV (commas and quotes)
      final cleanNotes = notesStr.replaceAll('"', '""').replaceAll(',', ';').replaceAll('\n', ' ');
      final cleanLabel = label.toString().replaceAll('"', '""').replaceAll(',', ';');
      final cleanName = userName.toString().replaceAll('"', '""').replaceAll(',', ';');
      final cleanFollowUp = followUp.toString().replaceAll('"', '""').replaceAll(',', ';');
      final cleanFUStaff = fuStaff.toString().replaceAll('"', '""').replaceAll(',', ';');
      final cleanFUNote = fuNote.toString().replaceAll('"', '""').replaceAll(',', ';');
      
      csvRows.add('$dateStr,$timeStr,$type,$number,"$cleanLabel","$status",$duration,"$cleanName",$isHot,$isConverted,"$cleanFollowUp","$cleanFUStaff","$cleanFUNote","$cleanNotes"');
    }

    final String csvContent = csvRows.join('\r\n'); // Use CRLF for better Excel compatibility
    
    await FileSaver.saveAndShare(csvContent, '${fileName}.csv');
  }
}

abstract class FileSaver {
  static Future<void> saveAndShare(String content, String fileName) async {
    throw UnimplementedError('saveAndShare must be implemented in platform specific files');
  }
}
