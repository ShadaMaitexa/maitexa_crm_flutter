import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FileSaver {
  static Future<void> saveAndShare(String content, String fileName) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(content);
    
    await Share.shareXFiles([XFile(file.path)], text: 'Call Log Export');
  }
}
