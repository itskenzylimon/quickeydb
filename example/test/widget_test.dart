@TestOn('vm')
library;

import 'package:example/notes.dart';
import 'package:example/showcase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickeydb/quickeydb.dart';
import 'support/gallery_tester.dart';

// Retain a real smoke test here so flutter create cannot regenerate a counter
// test referring to MyApp when refreshing the native platform projects.
void main() {
  testWidgets('overview refreshes database stats and supports dark mode',
      (tester) async {
    final database = (await tester.runAsync(() async => QuickeyDB.initialize(
          dbName: 'overview_test',
          dbVersion: 1,
          persist: false,
          dataAccessObjects: [NotesDao()],
          valueEncryption: ValueEncryption(await ValueEncryption.generateKey()),
        )))!;
    try {
      await tester.pumpWidget(ShowcaseApp(database: database));
      await settleGallery(tester);
      expect(find.text('Local data.\nPractical possibilities.'), findsOneWidget);
      expect(find.text('0 notes'), findsOneWidget);
      await tester.runAsync(() => database
          .get<NotesDao>()!
          .create(const Note(title: 'External write', body: 'Protected')));
      await tester.tap(find.byTooltip('Refresh database stats'));
      await settleGallery(tester);
      expect(find.text('1 note'), findsOneWidget);
      await tester.tap(find.byTooltip('Toggle theme'));
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
          Brightness.dark);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(database.close);
    }
  });
}
