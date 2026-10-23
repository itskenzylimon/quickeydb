import 'dart:typed_data';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

const isBrowser = true;
DatabaseFactory defaultDatabaseFactory() => databaseFactoryFfiWeb;
Future<String> supportDirectory() async => '.';
// Browser paths are virtual SQLite/IndexedDB namespaces, not OS directories.
Future<void> prepareDirectory(String path, {required bool private}) async {}
Future<void> restrictDatabase(String path) async {}
Future<void> writeDatabase(String path, Uint8List bytes) async =>
    throw UnsupportedError('Asset database import is currently native-only.');
