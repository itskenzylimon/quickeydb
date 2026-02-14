// lib/path_helper.dart
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

Future<String> getSafePath(String fileName) async {
  if (kIsWeb) {
    return fileName; // Web doesn't use file paths for IndexedDB
  }

  // This code only runs on Native platforms
  final directory = await getApplicationDocumentsDirectory();
  return join(directory.path, fileName);
}
