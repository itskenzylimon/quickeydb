@TestOn('vm')
library;

import 'dart:convert';
import 'package:activity/activity.dart';
import 'package:example/gallery_controller.dart';
import 'package:example/console.dart';
import 'package:example/notes.dart';
import 'package:example/showcase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickeydb/quickeydb.dart';
import '../support/gallery_tester.dart';

Future<QuickeyDBImpl> start(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final db =
      (await tester.runAsync(
        () async => QuickeyDB.initialize(
          dbName: 'reactive_gallery',
          dbVersion: 1,
          persist: false,
          dataAccessObjects: [NotesDao()],
          queryLogging: QueryLogging(),
          valueEncryption: ValueEncryption(await ValueEncryption.generateKey()),
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

GalleryController modelOf(WidgetTester tester) =>
    Activity.getActivity<GalleryController>(
      tester.element(find.byType(NotesPage)),
    );
ActivityRouter routerOf(WidgetTester tester) =>
    ActivityRouter.of(tester.element(find.byType(NotesPage)));
Future<void> press(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await settleGallery(tester);
}

void main() {
  testWidgets('docked console logs redacted SQL and fits a phone', (
    tester,
  ) async {
    await start(tester);
    final model = modelOf(tester);
    await press(tester, find.byTooltip('Open database console'));
    expect(find.byType(DatabaseConsole), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => model.dao.query().where({'title': 'private-secret'}).toMap(),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(TextButton, 'SQL ${model.queries.value.length}'),
    );
    await tester.pumpAndSettle();
    final console = find.byType(DatabaseConsole);
    expect(
      find.descendant(of: console, matching: find.textContaining('WHERE')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: console,
        matching: find.textContaining('private-secret'),
      ),
      findsNothing,
    );
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byTooltip('Close console'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close console'));
    await tester.pumpAndSettle();
    expect(find.byType(DatabaseConsole), findsNothing);
  });

  testWidgets(
    'all-notes options, inline terminal and API/View/Model source work',
    (tester) async {
      await start(tester);
      final model = modelOf(tester);
      await tester.runAsync(
        () => model.dao.createAll([
          const Note(title: 'First', body: 'Private A'),
          const Note(title: 'Second', body: 'Private B'),
          const Note(title: 'Third', body: 'Private C'),
        ]),
      );
      routerOf(tester).go('/queries');
      await settleGallery(tester);
      await press(tester, find.byKey(const ValueKey('query-DESC')));
      await press(tester, find.text('Run query'));
      final descending = jsonDecode(model.terminals[2]!.output) as List;
      expect(descending.map((row) => row['id']), [3, 2, 1]);
      expect(find.text('Result terminal'), findsOneWidget);
      expect(find.byTooltip('Copy terminal output'), findsOneWidget);
      await press(tester, find.byTooltip('Show source code').first);
      expect(find.textContaining("order(['id'], 'ASC')"), findsOneWidget);
      expect(find.textContaining("order(['id'], 'DESC')"), findsOneWidget);
      await press(tester, find.widgetWithText(ChoiceChip, 'View code'));
      expect(find.textContaining('class AllNotesQueryView'), findsOneWidget);
      await press(tester, find.widgetWithText(ChoiceChip, 'Model / DAO'));
      expect(find.textContaining('class Note {'), findsOneWidget);
      model.publish(2, {'reactive': 'terminal updated'});
      await tester.pumpAndSettle();
      expect(find.textContaining('terminal updated'), findsOneWidget);
      expect(find.textContaining('class Note {'), findsOneWidget);
      await press(tester, find.byTooltip('Show live preview').first);
      await press(tester, find.byKey(const ValueKey('query-ASC')));
      await press(tester, find.text('Limit 3'));
      await press(tester, find.text('Metadata projection'));
      await press(tester, find.text('Run query'));
      final projection = jsonDecode(model.terminals[2]!.output) as List;
      expect(projection.map((row) => row['id']), [1, 2, 3]);
      expect(projection.first.keys, unorderedEquals(['id', 'title']));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Activity routes preserve drafts, return typed note results and validate sections',
    (tester) async {
      final db = await start(tester);
      final model = modelOf(tester), router = routerOf(tester);
      await tester.runAsync(
        () => model.dao.create(
          const Note(title: 'Linked note', body: 'Readable detail'),
        ),
      );
      await tester.runAsync(model.reload);
      await tester.pumpAndSettle();
      router.go('/crud');
      await settleGallery(tester);
      await tester.enterText(
        find.byKey(const Key('crud-title')),
        'Unsubmitted draft',
      );
      router.go('/queries');
      await settleGallery(tester);
      router.go('/crud');
      await settleGallery(tester);
      expect(find.text('Unsubmitted draft'), findsOneWidget);
      await press(tester, find.widgetWithText(ListTile, 'Linked note'));
      expect(find.text('Note #1'), findsOneWidget);
      expect(find.text('Readable detail'), findsOneWidget);
      expect(router.state.uri.path, '/crud/notes/1');
      await press(tester, find.text('Return note result'));
      expect(router.state.uri.path, '/crud');
      expect(find.textContaining('Viewed note #1'), findsOneWidget);
      router.go('/not-a-section');
      await settleGallery(tester);
      expect(router.state.uri.path, '/overview');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(model.isDisposed, isTrue);
      expect(
        db.database!.isOpen,
        isTrue,
        reason: 'The shared controller borrows the database handle.',
      );
    },
  );
}
