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

      final dateStr = DateFormat('dd-MM-yyyy').format(dt);
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
      
      // Use \t (tab) prefix for number to prevent scientific notation in Excel
      csvRows.add('$dateStr,$timeStr,$type,"\t$number","$cleanLabel","$status",$duration,"$cleanName",$isHot,$isConverted,"$cleanFollowUp","$cleanFUStaff","$cleanFUNote","$cleanNotes"');
    }

    final String csvContent = csvRows.join('\r\n'); // Use CRLF for better Excel compatibility
    
    await FileSaver.saveAndShare(csvContent, '${fileName}.csv');
  }

  static Future<void> exportLeadLifecycleToCsv(List<Map<String, dynamic>> data, String fileName) async {
    if (data.isEmpty) return;

    final List<String> csvRows = [];
    
    // Header for Lead Lifecycle Report
    csvRows.add('Name,Phone,Label,Status,Organization,Created Date,Total Calls,Incoming,Outgoing,Missed,Last Call,Staff,Latest Note,Follow-Up,FU Note,FU Staff');

    for (var lead in data) {
      final name = lead['name'] ?? 'Unknown';
      final phone = (lead['phone'] ?? lead['phoneNumber'] ?? '').toString();
      final label = lead['label'] ?? '';
      final status = lead['status'] ?? '';
      final org = lead['organization'] ?? 'Acadeno CRM';
      
      final createdObj = lead['created_at'] ?? lead['createdAt'] ?? lead['timestamp'];
      DateTime createdDt = DateTime.now();
      if (createdObj is Timestamp) createdDt = createdObj.toDate();
      else if (createdObj is int) createdDt = DateTime.fromMillisecondsSinceEpoch(createdObj);
      else if (createdObj is DateTime) createdDt = createdObj;
      final createdStr = DateFormat('dd-MM-yyyy').format(createdDt);

      final totalCalls = lead['totalCalls'] ?? 0;
      final incoming = lead['incomingCalls'] ?? 0;
      final outgoing = lead['outgoingCalls'] ?? 0;
      final missed = lead['missedCalls'] ?? 0;
      final lastCall = lead['lastCallDate'] ?? 'None';
      final staff = lead['staffName'] ?? lead['userName'] ?? 'Unknown';
      
      final latestNote = (lead['latestNote'] ?? '').toString().replaceAll('"', '""').replaceAll(',', ';').replaceAll('\n', ' ');
      final fuDate = lead['followUpDate'] ?? 'None';
      final fuNote = (lead['followUpNote'] ?? '').toString().replaceAll('"', '""').replaceAll(',', ';').replaceAll('\n', ' ');
      final fuStaff = lead['followUpStaff'] ?? 'None';

      csvRows.add('"$name","\t$phone","$label","$status","$org",$createdStr,$totalCalls,$incoming,$outgoing,$missed,"$lastCall","$staff","$latestNote","$fuDate","$fuNote","$fuStaff"');
    }

    final String csvContent = csvRows.join('\r\n');
    await FileSaver.saveAndShare(csvContent, '${fileName}.csv');
  }
}

// Note: FileSaver must be provided by the platform-specific files imported above
