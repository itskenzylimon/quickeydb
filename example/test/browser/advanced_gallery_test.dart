@TestOn('browser')
library;

import 'package:activity/activity.dart';
import 'package:example/notes.dart';
import 'package:example/showcase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickeydb/quickeydb.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../support/gallery_tester.dart';

void main() {
  reportBrowserWidgetFailures();
  testWidgets(
    'worker gallery pages paginate and roll back conflict/bulk probes',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final queryEvents = <QueryLogEvent>[];
      final factory = createDatabaseFactoryFfiWeb(
        options: SqfliteFfiWebOptions(
          indexedDbName: 'advanced_${DateTime.now().microsecondsSinceEpoch}',
          sqlite3WasmUri: Uri.base.resolve('/.web-assets/sqlite3.wasm'),
          sharedWorkerUri: Uri.base.resolve('/.web-assets/sqflite_sw.js'),
        ),
      );
      final db =
          (await tester.runAsync(
            () async => QuickeyDB.initialize(
              dbName: 'advanced',
              queryLogging: QueryLogging(
                includeSql: true,
                onQuery: queryEvents.add,
              ),
              dbVersion: 1,
              factory: factory,
              dataAccessObjects: [NotesDao()],
              valueEncryption: ValueEncryption(
                await ValueEncryption.generateKey(),
              ),
              conflictAlgorithm: ConflictAlgorithm.abort,
            ),
          ))!;
      Future<void> navigate(String name) async {
        await tester.enterText(find.byKey(const Key('nav-search')), name);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, name));
        await settleGallery(tester);
      }

      Future<void> press(String text) async {
        await tester.ensureVisible(find.text(text));
        await tester.pumpAndSettle();
        await tester.tap(find.text(text));
        await settleGallery(tester);
      }

      try {
        await tester.pumpWidget(ShowcaseApp(database: db));
        await settleGallery(tester);
        await navigate('Pagination');
        await press('Add six paging notes');
        await press('Next page');
        expect(find.textContaining('"page": 2'), findsOneWidget);
        await navigate('Aggregates & projections');
        await press('Calculate result');
        expect(find.textContaining('"count": 6'), findsOneWidget);
        await navigate('Conflicts & bulk writes');
        for (final policy in ['Abort', 'Ignore', 'Replace']) {
          await tester.ensureVisible(find.text(policy));
          await tester.pumpAndSettle();
          await tester.tap(find.text(policy));
          await tester.pumpAndSettle();
          await press('Run conflict probe');
          expect(find.textContaining('"rolledBack": true'), findsOneWidget);
          expect(
            await tester.runAsync(() => db.get<NotesDao>()!.query().count()),
            6,
          );
        }
        await press('Run bulk probe');
        expect(find.textContaining('"updated": 2'), findsOneWidget);
        expect(
          await tester.runAsync(() => db.get<NotesDao>()!.query().count()),
          6,
        );
        await navigate('Migrations & indexes');
        await press('Generate migration plan');
        expect(find.textContaining('dbVersion: 2'), findsOneWidget);
        final columns = await tester.runAsync(
          () => db.database!.rawQuery('PRAGMA table_info(notes)'),
        );
        expect(columns!.map((row) => row['name']), ['id', 'title', 'body']);
        final router = ActivityRouter.of(
          tester.element(find.byType(NotesPage)),
        );
        router.go('/queries');
        await settleGallery(tester);
        await press('Descending');
        await press('Run query');
        expect(find.text('Result terminal'), findsOneWidget);
        await tester.ensureVisible(find.byTooltip('Show source code').first);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Show source code').first);
        await tester.pumpAndSettle();
        expect(find.textContaining("order(['id'], 'ASC')"), findsOneWidget);
        expect(find.textContaining("order(['id'], 'DESC')"), findsOneWidget);
        await press('View code');
        expect(find.textContaining('class AllNotesQueryView'), findsOneWidget);
        await press('Model / DAO');
        expect(find.textContaining('class Note {'), findsOneWidget);
        router.go('/crud');
        await settleGallery(tester);
        final row = find.widgetWithText(ListTile, 'Paging sample 1');
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await settleGallery(tester);
        expect(router.state.uri.path, '/crud/notes/1');
        await press('Return note result');
        expect(find.textContaining('Viewed note #1'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(queryEvents.any((event) => event.operation == 'INSERT'), isTrue);
        expect(queryEvents.any((event) => event.operation == 'SELECT'), isTrue);
        expect(queryEvents.where((event) => event.sql != null), isNotEmpty);
        expect(queryEvents.join(), isNot(contains('Paging sample 1')));
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(db.close);
      }
    },
  );
}
