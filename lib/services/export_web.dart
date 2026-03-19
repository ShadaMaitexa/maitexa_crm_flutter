import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class FileSaver {
  static Future<void> saveAndShare(String content, String fileName) async {
    // Add UTF-8 BOM for Excel compatibility
    final List<int> bom = [0xEF, 0xBB, 0xBF];
    final List<int> bytes = utf8.encode(content);
    final List<int> allBytes = [...bom, ...bytes];
    
    // Convert to Uint8List so the browser treats it as binary data
    final blob = html.Blob([Uint8List.fromList(allBytes)], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
      
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    
    // Delay revocation to ensure the browser has processed the download request
    Future.delayed(const Duration(seconds: 1), () => html.Url.revokeObjectUrl(url));
    
    debugPrint('CSV Exported: $fileName (Web)');
  }
}
