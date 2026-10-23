@TestOn('vm')
library;

import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickeydb/quickeydb.dart';
import '../support/gallery_tester.dart';

void main() {
  testWidgets('encrypted notes page saves and reloads without exposing keys', (
    tester,
  ) async {
    final database =
        (await tester.runAsync(
          () async => QuickeyDB.initialize(
            dbName: 'widget_test',
            dbVersion: 1,
            persist: false,
            dataAccessObjects: [NotesDao()],
            valueEncryption: ValueEncryption(
              await ValueEncryption.generateKey(),
            ),
          ),
        ))!;
    try {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(1400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: NotesPage(database: database)));
      await settleGallery(tester);
      await tester.tap(find.widgetWithText(ListTile, 'CRUD studio'));
      await settleGallery(tester);
      await tester.enterText(find.byKey(const Key('crud-title')), 'A note');
      await tester.enterText(
        find.byKey(const Key('crud-body')),
        'Private body',
      );
      await tester.tap(find.text('Save note'));
      await settleGallery(tester);
      expect(find.text('A note'), findsOneWidget);
      expect(find.text('Private body'), findsOneWidget);
      final stored = await tester.runAsync(
        () => database.database!.query('notes'),
      );
      expect(stored!.single['body'], startsWith(ValueEncryption.prefix));
      await tester.ensureVisible(find.byTooltip('Edit A note'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit A note'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('crud-title')),
        'Edited note',
      );
      await tester.tap(find.text('Update note'));
      await settleGallery(tester);
      expect(find.text('Edited note'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Query playground'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Run query'));
      await settleGallery(tester);
      expect(find.textContaining('Edited note'), findsWidgets);
      await tester.tap(find.widgetWithText(ListTile, 'Transactions'));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Test rollback')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test rollback'));
      await settleGallery(tester);
      expect(
        await tester.runAsync(() => database.get<NotesDao>()!.query().count()),
        1,
      );
      await tester.tap(find.widgetWithText(ListTile, 'CRUD studio'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Delete Edited note'));
      await tester.tap(find.byTooltip('Delete Edited note'));
      await settleGallery(tester);
      expect(
        find.text('No notes yet. Create your first note above.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(database.close);
    }
  });
}
