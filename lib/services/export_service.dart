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
    
    // Streamlined header (removed Duration, Status, FU Staff as they are often unrequired)
    csvRows.add('Date,Time,Type,Number,Label,Staff,Hot Deal,Converted,Follow-Up,Notes');

    for (var call in calls) {
      final dateObj = call['timestamp'] ?? call['created_at'] ?? call['createdAt'];
      DateTime dt = DateTime.now();
      if (dateObj is Timestamp) dt = dateObj.toDate();
      else if (dateObj is int) dt = DateTime.fromMillisecondsSinceEpoch(dateObj);
      else if (dateObj is DateTime) dt = dateObj;

      final dateStr = '\t${DateFormat('dd-MM-yyyy').format(dt)}';
      final timeStr = '\t${DateFormat('HH:mm').format(dt)}';
      String type = (call['call_type'] ?? call['type'] ?? 'Unknown').toString();
      if (type.contains('.')) type = type.split('.').last;
      
      final numberStr = '\t${call['phone_number'] ?? call['number'] ?? ''}';
      final label = call['label'] ?? '';
      final userName = call['userName'] ?? 'Unknown';
      final isHot = (call['isHot'] == true || label.toString().toLowerCase().contains('hot')) ? 'YES' : 'NO';
      final isConverted = (call['isConverted'] == true) ? 'YES' : 'NO';
      final followUp = call['followUpDate'] ?? 'None';
      
      // Combine and filter notes to show only the text
      List<String> notesList = [];
      
      void addCleanNote(dynamic n) {
        if (n == null) return;
        String noteText = '';
        
        if (n is Map) {
          noteText = (n['note'] ?? n['message'] ?? n['notes'] ?? '').toString().trim();
        } else {
          String s = n.toString().trim();
          // If the string is a raw metadata dump like "[{note: ...}]" or similar
          if (s.contains('note:')) {
            // Try to extract the part after 'note:' up to the next semicolon or closing bracket
            final regExp = RegExp(r'note:\s*([^;\]]+)');
            final match = regExp.firstMatch(s);
            if (match != null) {
              noteText = match.group(1)?.trim() ?? '';
            } else {
              noteText = s;
            }
          } else {
            noteText = s;
          }
        }
        
        if (noteText.isNotEmpty && !notesList.contains(noteText)) {
          notesList.add(noteText);
        }
      }

      if (call['notes'] is List) {
        for (var n in (call['notes'] as List)) addCleanNote(n);
      } else {
        addCleanNote(call['notes'] ?? call['note']);
      }
      
      if (call['followUpNote'] != null && call['followUpNote'].toString().isNotEmpty) {
        notesList.add('[FU]: ${call['followUpNote']}');
      }

      final notesStr = notesList.join(' | ');
      
      String _e(dynamic s) => '"${s.toString().replaceAll('"', '""').replaceAll('\n', ' ')}"';

      csvRows.add([
        _e(dateStr),
        _e(timeStr),
        _e(type),
        _e(numberStr),
        _e(label),
        _e(userName),
        _e(isHot),
        _e(isConverted),
        _e(followUp == 'None' ? 'None' : '\t$followUp'),
        _e(notesStr),
      ].join(','));
    }

    final String csvContent = csvRows.join('\r\n');
    await FileSaver.saveAndShare(csvContent, '${fileName}.csv');
  }

  static Future<void> exportLeadLifecycleToCsv(List<Map<String, dynamic>> data, String fileName) async {
    if (data.isEmpty) return;

    final List<String> csvRows = [];
    
    // Streamlined header (removed Organization, FU Staff)
    csvRows.add('Name,Phone,Label,Status,Created Date,Total Calls,In,Out,Missed,Last Call,Staff,Notes');

    for (var lead in data) {
      final name = lead['name'] ?? 'Unknown';
      final phone = (lead['phone'] ?? lead['phoneNumber'] ?? '').toString();
      final label = lead['label'] ?? '';
      final status = lead['status'] ?? '';
      
      final createdObj = lead['created_at'] ?? lead['createdAt'] ?? lead['timestamp'];
      DateTime createdDt = DateTime.now();
      if (createdObj is Timestamp) createdDt = createdObj.toDate();
      else if (createdObj is int) createdDt = DateTime.fromMillisecondsSinceEpoch(createdObj);
      else if (createdObj is DateTime) createdDt = createdObj;
      final createdStr = '\t${DateFormat('dd-MM-yyyy').format(createdDt)}';

      final totalCalls = lead['totalCalls'] ?? 0;
      final incoming = lead['incomingCalls'] ?? 0;
      final outgoing = lead['outgoingCalls'] ?? 0;
      final missed = lead['missedCalls'] ?? 0;
      final lastCall = lead['lastCallDate'] ?? 'None';
      final staff = lead['staffName'] ?? lead['userName'] ?? 'Unknown';
      
      // Clean up notes
      String cleanNote(dynamic n) {
        if (n == null) return '';
        String s = n.toString().trim();
        if (s.contains('note:')) {
           final regExp = RegExp(r'note:\s*([^;\]]+)');
           final match = regExp.firstMatch(s);
           return match?.group(1)?.trim() ?? s;
        }
        return s;
      }

      String notesCombined = cleanNote(lead['latestNote'] ?? '');
      final fuDate = (lead['followUpDate'] ?? 'None').toString();
      final fuNote = cleanNote(lead['followUpNote'] ?? '');

      if (fuNote.isNotEmpty) {
        notesCombined += (notesCombined.isEmpty ? '' : ' | ') + '[Next FU: $fuDate]: $fuNote';
      }

      String _e(dynamic s) => '"${s.toString().replaceAll('"', '""').replaceAll('\n', ' ')}"';

      csvRows.add([
        _e(name),
        _e('\t$phone'),
        _e(label),
        _e(status),
        _e(createdStr),
        _e(totalCalls),
        _e(incoming),
        _e(outgoing),
        _e(missed),
        _e(lastCall == 'None' ? 'None' : '\t$lastCall'),
        _e(staff),
        _e(notesCombined),
      ].join(','));
    }

    final String csvContent = csvRows.join('\r\n');
    await FileSaver.saveAndShare(csvContent, '${fileName}.csv');
  }
}

// Note: FileSaver must be provided by the platform-specific files imported above
