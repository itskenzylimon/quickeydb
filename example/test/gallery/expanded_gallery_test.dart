@TestOn('vm')
library;

import 'package:example/notes.dart';
import 'package:example/showcase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickeydb/quickeydb.dart';
import '../support/gallery_tester.dart';

const sections = [
  'Overview',
  'CRUD studio',
  'Query playground',
  'Transactions',
  'Encryption',
  'API cookbook',
  'Memory',
  'SQL to DAO',
  'Tips & points',
  'Start here',
  'Schema explorer',
  'Storage & lifecycle',
  'Pagination',
  'Aggregates & projections',
  'Conflicts & bulk writes',
  'Relations',
  'Migrations & indexes',
  'Application recipes',
  'Appearance',
];

Future<QuickeyDBImpl> openGallery(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final db =
      (await tester.runAsync(
        () async => QuickeyDB.initialize(
          dbName: 'expanded_gallery',
          dbVersion: 1,
          persist: false,
          dataAccessObjects: [NotesDao()],
          valueEncryption: ValueEncryption(await ValueEncryption.generateKey()),
          conflictAlgorithm: ConflictAlgorithm.abort,
        ),
      ))!;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
  await tester.pumpWidget(ShowcaseApp(database: db));
  await settleGallery(tester);
  return db;
}

Future<void> navigate(WidgetTester tester, String name) async {
  final menu = find.byTooltip('Open navigation menu');
  if (menu.evaluate().isNotEmpty) {
    await tester.tap(menu);
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byKey(const Key('nav-search')), name);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, name));
  await settleGallery(tester);
}

Future<void> press(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await settleGallery(tester);
}

void main() {
  testWidgets('all 19 sections render at desktop and phone widths', (
    tester,
  ) async {
    await openGallery(tester);
    for (final size in [const Size(1440, 1100), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      for (final section in sections) {
        await navigate(tester, section);
        expect(tester.takeException(), isNull, reason: '$section at $size');
      }
    }
  });

  testWidgets('pagination and aggregates query real encrypted notes', (
    tester,
  ) async {
    final db = await openGallery(tester);
    await navigate(tester, 'Pagination');
    await press(tester, 'Add six paging notes');
    expect(await tester.runAsync(() => db.get<NotesDao>()!.query().count()), 6);
    expect(find.textContaining('"page": 1'), findsOneWidget);
    await press(tester, 'Next page');
    expect(find.textContaining('"page": 2'), findsOneWidget);
    expect(find.textContaining('Paging sample 6'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Show source code'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show source code'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('.offset((current - 1) * pageSize)'),
      findsOneWidget,
    );
    await navigate(tester, 'Aggregates & projections');
    await press(tester, 'Calculate result');
    expect(find.textContaining('"count": 6'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('aggregate-title')),
      'Paging sample 1',
    );
    await press(tester, 'Calculate result');
    expect(find.textContaining('"count": 1'), findsOneWidget);
    final raw = await tester.runAsync(() => db.database!.query('notes'));
    expect(
      raw!.every(
        (row) => (row['body'] as String).startsWith(ValueEncryption.prefix),
      ),
      isTrue,
    );
  });

  testWidgets('conflict policies and bulk probes always roll back their rows', (
    tester,
  ) async {
    final db = await openGallery(tester);
    await tester.runAsync(
      () => db.get<NotesDao>()!.create(
        const Note(title: 'Keep me', body: 'Unchanged'),
      ),
    );
    await navigate(tester, 'Conflicts & bulk writes');
    for (final policy in ['Abort', 'Ignore', 'Replace']) {
      final chip = find.widgetWithText(ChoiceChip, policy);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await press(tester, 'Run conflict probe');
      expect(find.textContaining('"rolledBack": true'), findsOneWidget);
      expect(
        find.textContaining(
          policy == 'Abort' ? 'Duplicate rejected' : 'Duplicate accepted',
        ),
        findsOneWidget,
      );
      final notes = await tester.runAsync(
        () => db.get<NotesDao>()!.query().toList(),
      );
      expect(notes!.single!.title, 'Keep me');
      expect(notes.single!.body, 'Unchanged');
    }
    await press(tester, 'Run bulk probe');
    expect(find.textContaining('"updated": 2'), findsOneWidget);
    expect(find.textContaining('"deleted": 1'), findsOneWidget);
    expect(await tester.runAsync(() => db.get<NotesDao>()!.query().count()), 1);
  });

  testWidgets(
    'migration plans are read-only and checklist/theme selections update',
    (tester) async {
      final db = await openGallery(tester);
      await navigate(tester, 'Migrations & indexes');
      await press(tester, 'Generate migration plan');
      expect(find.textContaining('dbVersion: 2'), findsOneWidget);
      final columns = await tester.runAsync(
        () => db.database!.rawQuery('PRAGMA table_info(notes)'),
      );
      expect(columns!.map((row) => row['name']), ['id', 'title', 'body']);
      await tester.enterText(find.byKey(const Key('migration-version')), '1');
      await press(tester, 'Generate migration plan');
      expect(
        find.textContaining('greater than the current version'),
        findsWidgets,
      );
      await navigate(tester, 'Tips & points');
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      expect(find.text('1 of 12 complete'), findsOneWidget);
      await navigate(tester, 'Appearance');
      await press(tester, 'Dark');
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.dark,
      );
      await tester.tap(find.byTooltip('Yellow'));
      await tester.pumpAndSettle();
      await navigate(tester, 'Tips & points');
      expect(find.text('1 of 12 complete'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
