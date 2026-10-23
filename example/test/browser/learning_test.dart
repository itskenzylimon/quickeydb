@TestOn('browser')
library;

import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickeydb/quickeydb.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../support/gallery_tester.dart';

void main() {
  reportBrowserWidgetFailures();
  testWidgets('learning pages, live stats, SQL generation and encrypted Memory',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final namespace = 'learning_${DateTime.now().microsecondsSinceEpoch}';
    final factory = createDatabaseFactoryFfiWeb(
        options: SqfliteFfiWebOptions(
      indexedDbName: namespace,
      sqlite3WasmUri: Uri.base.resolve('/.web-assets/sqlite3.wasm'),
      sharedWorkerUri: Uri.base.resolve('/.web-assets/sqflite_sw.js'),
    ));
    final db = (await tester.runAsync(() async => QuickeyDB.initialize(
          dbName: 'learning',
          dbVersion: 1,
          factory: factory,
          dataAccessObjects: [NotesDao()],
          valueEncryption: ValueEncryption(await ValueEncryption.generateKey()),
        )))!;
    Memory? memory;
    Future<void> settle() => settleGallery(tester);

    Future<void> navigate(String name) async {
      await tester.enterText(find.byKey(const Key('nav-search')), name);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, name));
      await settle();
      await tester.enterText(find.byKey(const Key('nav-search')), '');
      await tester.pumpAndSettle();
    }

    try {
      await tester.pumpWidget(MaterialApp(
          home: NotesPage(database: db, memoryNamespace: namespace)));
      await settle();
      expect(find.text('1 table'), findsOneWidget);
      expect(find.text('0 notes'), findsOneWidget);
      expect(find.text('1 encrypted field'), findsOneWidget);
      await navigate('Start here');
      expect(find.text('1. What is a database?'), findsOneWidget);
      await navigate('SQL to DAO');
      await tester.ensureVisible(find.text('Generate DAOs'));
      await tester.tap(find.text('Generate DAOs'));
      await settle();
      expect(find.textContaining('class ProjectsDao extends'), findsOneWidget);
      expect(
          await tester.runAsync(() => db.database!.rawQuery(
              "SELECT name FROM sqlite_master WHERE name = 'projects'")),
          isEmpty);
      await tester.enterText(find.byKey(const Key('sql-input')), 'SELECT 1;');
      await tester.ensureVisible(find.text('Generate DAOs'));
      await tester.tap(find.text('Generate DAOs'));
      await settle();
      expect(find.textContaining('FormatException'), findsOneWidget);
      expect(find.textContaining('class ProjectsDao extends'), findsNothing);
      await navigate('Memory');
      await tester.enterText(
          find.byKey(const Key('memory-value')), 'Browser draft');
      await tester.tap(find.text('Save memory'));
      await settle();
      await tester.tap(find.text('Read memory'));
      await settle();
      expect(find.text('Stored draft: Browser draft'), findsOneWidget);
      memory = await tester.runAsync(() => Memory()
          .instance(memoryKey: namespace, encryption: db.valueEncryption));
      expect(await tester.runAsync(() => memory!.getString('draft')),
          'Browser draft');
      await tester.tap(find.text('Delete draft'));
      await settle();
      await tester.tap(find.text('Read memory'));
      await settle();
      expect(find.text('No draft found (missing or expired).'), findsOneWidget);
      await navigate('Schema explorer');
      expect(find.textContaining('CREATE TABLE notes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      if (memory != null) await tester.runAsync(memory.close);
      await tester.runAsync(db.close);
    }
  });
}
