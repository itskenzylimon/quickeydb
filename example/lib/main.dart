import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'startup_help.dart';
import 'notes.dart';
import 'showcase.dart';
export 'notes.dart';
export 'showcase.dart' show NotesPage;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quickeydb/quickeydb.dart';

/// A separate demo database leaves existing Task/User example data intact.
Future<QuickeyDBImpl> openNotesDatabase() async {
  const storage = FlutterSecureStorage();
  const keyName = 'quickeydb.notes.aes256.v1';
  var encoded = await storage.read(key: keyName);
  if (encoded == null) {
    if (await QuickeyDB.databaseExists(
      dbName: 'private_notes',
      privateStorage: true,
    )) {
      throw StateError(
        'Existing database key is missing; restore it instead of generating a replacement.',
      );
    }
    encoded = base64Encode(await ValueEncryption.generateKey());
    await storage.write(key: keyName, value: encoded);
  }
  return QuickeyDB.initialize(
    dbName: 'private_notes',
    dbVersion: 1,
    dataAccessObjects: [NotesDao()],
    privateStorage: true,
    queryLogging: QueryLogging(enabled: kDebugMode),
    valueEncryption: ValueEncryption(base64Decode(encoded)),
    conflictAlgorithm: ConflictAlgorithm.abort,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final database = await openNotesDatabase();
    runApp(ShowcaseApp(database: database));
  } catch (error, stack) {
    debugPrint('QuickeyDB startup: $error\n$stack');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SelectableText(
                  'Cannot open notes: $error\n\n${startupHelp(isWeb: kIsWeb, platform: defaultTargetPlatform)}',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
