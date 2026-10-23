@TestOn('browser')
library;

import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickeydb/quickeydb.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void main() {
  test('browser worker encrypts, persists, reopens and rejects a wrong key',
      () async {
    final factory = createDatabaseFactoryFfiWeb(
        options: SqfliteFfiWebOptions(
      indexedDbName:
          'quickey_regression_${DateTime.now().microsecondsSinceEpoch}',
      sqlite3WasmUri: Uri.base.resolve('/.web-assets/sqlite3.wasm'),
      sharedWorkerUri: Uri.base.resolve('/.web-assets/sqflite_sw.js'),
    ));
    final key = await ValueEncryption.generateKey();
    Future<QuickeyDBImpl> open(List<int> key) => QuickeyDB.initialize(
        dbName: 'browser_test',
        dbVersion: 1,
        dataAccessObjects: [NotesDao()],
        factory: factory,
        privateStorage: true,
        valueEncryption: ValueEncryption(key));
    var db = await open(key);
    try {
      expect(db.database!.path, contains('.quickeydb'));
      await db
          .get<NotesDao>()!
          .create(const Note(title: 'Browser note', body: 'Protected body'));
      final raw = (await db.database!.query('notes')).single;
      expect(raw['body'], startsWith(ValueEncryption.prefix));
      expect(raw['body'], isNot(contains('Protected body')));
      await db.close();
      expect(
          await QuickeyDB.databaseExists(
              dbName: 'browser_test', factory: factory, privateStorage: true),
          isTrue);
      db = await open(key);
      final notes = await db.get<NotesDao>()!.all;
      expect(notes.single!.body, 'Protected body');
      await db.close();
      await expectLater(open(List.filled(32, 0)), throwsA(anything));
    } finally {
      await QuickeyDB.getInstance?.close();
    }
  });
}
