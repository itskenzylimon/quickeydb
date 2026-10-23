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
  testWidgets(
    'gallery supports CRUD, queries, rollback and mobile navigation',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final factory = createDatabaseFactoryFfiWeb(
        options: SqfliteFfiWebOptions(
          indexedDbName: 'gallery_${DateTime.now().microsecondsSinceEpoch}',
          sqlite3WasmUri: Uri.base.resolve('/.web-assets/sqlite3.wasm'),
          sharedWorkerUri: Uri.base.resolve('/.web-assets/sqflite_sw.js'),
        ),
      );
      final db =
          (await tester.runAsync(
            () async => QuickeyDB.initialize(
              dbName: 'gallery_test',
              dbVersion: 1,
              factory: factory,
              dataAccessObjects: [NotesDao()],
              valueEncryption: ValueEncryption(
                await ValueEncryption.generateKey(),
              ),
            ),
          ))!;
      Future<void> settle() => settleGallery(tester);

      try {
        await tester.pumpWidget(MaterialApp(home: NotesPage(database: db)));
        await settle();
        await tester.tap(find.widgetWithText(ListTile, 'CRUD studio'));
        await settle();
        await tester.enterText(
          find.byKey(const Key('crud-title')),
          'Gallery note',
        );
        await tester.enterText(
          find.byKey(const Key('crud-body')),
          'Secret body',
        );
        await tester.tap(find.text('Save note'));
        await settle();
        expect(find.text('Gallery note'), findsOneWidget);
        await tester.ensureVisible(find.byTooltip('Edit Gallery note'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Edit Gallery note'));
        await settle();
        await tester.enterText(
          find.byKey(const Key('crud-title')),
          'Edited gallery',
        );
        await tester.tap(find.text('Update note'));
        await settle();
        expect(find.text('Edited gallery'), findsOneWidget);
        await tester.tap(find.widgetWithText(ListTile, 'Query playground'));
        await settle();
        await tester.tap(find.text('Run query'));
        await settle();
        expect(find.textContaining('Edited gallery'), findsOneWidget);
        await tester.tap(find.widgetWithText(ListTile, 'Transactions'));
        await settle();
        await Scrollable.ensureVisible(
          tester.element(find.text('Test rollback')),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Test rollback'));
        await settle();
        expect(
          await tester.runAsync(() => db.get<NotesDao>()!.query().count()),
          1,
        );
        await tester.tap(find.widgetWithText(ListTile, 'CRUD studio'));
        await settle();
        await Scrollable.ensureVisible(
          tester.element(find.byTooltip('Delete Edited gallery')),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Delete Edited gallery'));
        await settle();
        expect(
          await tester.runAsync(() => db.get<NotesDao>()!.query().count()),
          0,
        );
        tester.view.physicalSize = const Size(420, 900);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('nav-search')),
          'Encryption',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Encryption'));
        await tester.pumpAndSettle();
        expect(
          find.text('Application values → protected storage'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(db.close);
      }
    },
  );
}
