import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const isBrowser = false;
DatabaseFactory defaultDatabaseFactory() {
  if (Platform.isAndroid || Platform.isIOS) return mobile.databaseFactory;
  sqfliteFfiInit();
  return databaseFactoryFfi;
}

Future<String> supportDirectory() async =>
    (await getApplicationSupportDirectory()).path;
Future<void> prepareDirectory(String path, {required bool private}) async {
  await Directory(path).create(recursive: true);
  if (private && (Platform.isMacOS || Platform.isLinux)) {
    final permission = await Process.run('chmod', ['700', path]);
    if (permission.exitCode != 0) {
      throw FileSystemException('Unable to restrict private directory', path);
    }
  }
}

Future<void> writeDatabase(String path, Uint8List bytes) async {
  await File(path).writeAsBytes(bytes, flush: true);
}

Future<void> restrictDatabase(String path) async {
  if (Platform.isMacOS || Platform.isLinux) {
    final result = await Process.run('chmod', ['600', path]);
    if (result.exitCode != 0) {
      throw FileSystemException(
          'Unable to restrict database permissions', path);
    }
  }
}
