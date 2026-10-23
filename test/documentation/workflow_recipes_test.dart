@TestOn('vm')
library;

import '../support/orm_fixture.dart';
// Check the exact published recipe source rather than maintaining a test copy.
// ignore: avoid_relative_lib_imports
import '../../example/lib/workflow_recipes.dart';

void main() {
  final fixture = OrmFixture()..install();
  test('gallery workflow source stays identical to the tested recipe file', () {
    final source = File(
      'example/lib/workflow_recipes.dart',
    ).readAsStringSync().trim();
    expect(
      File('example/lib/recipes.dart').readAsStringSync(),
      contains(source),
    );
  });

  test(
    'keyset page avoids duplicates when a new row arrives; projection stays partial',
    () async {
      await fixture.open(daos: [WorkItems()]);
      final items = fixture.db.get<WorkItems>()!;
      await items.insertAll(List.generate(5, (i) => {'title': 'item $i'}));
      final first = await pageBefore(items, pageSize: 2);
      expect(first.map((r) => r['id']), [5, 4]);
      expect(
        first.every(
          (row) =>
              row.keys.toSet().containsAll(['id', 'title']) &&
              !row.containsKey('bucket'),
        ),
        isTrue,
      );
      await items.insert({'title': 'new item'});
      final second = await pageBefore(
        items,
        beforeId: first.last['id'] as int,
        pageSize: 2,
      );
      expect(second.map((r) => r['id']), [3, 2]);
      expect(await items.query().count(), 6);
      expect(() => pageBefore(items, pageSize: 0), throwsArgumentError);
    },
  );
  test(
    'failed inbox replacement rolls back deletion and preserves other buckets',
    () async {
      await fixture.open(daos: [WorkItems()]);
      final items = fixture.db.get<WorkItems>()!;
      await items.insertAll([
        {'id': 1, 'title': 'original inbox', 'bucket': 'inbox'},
        {'id': 2, 'title': 'keep', 'bucket': 'saved'},
      ]);
      await expectLater(
        replaceInbox(fixture.db, items, [
          {'id': 2, 'title': 'conflicts with saved', 'bucket': 'inbox'},
        ]),
        throwsA(anything),
      );
      expect((await items.query().find(1))!['title'], 'original inbox');
      expect((await items.query().find(2))!['title'], 'keep');
      await replaceInbox(fixture.db, items, [
        {'id': 3, 'title': 'replacement', 'bucket': 'inbox'},
      ]);
      expect(await items.query().find(1), isNull);
      expect((await items.query().find(2))!['title'], 'keep');
      expect(await items.query().count(), 2);
    },
  );
  test(
    'archive is scoped and does not leak its filters into the next read',
    () async {
      await fixture.open(daos: [WorkItems()]);
      final items = fixture.db.get<WorkItems>()!;
      await items.insertAll(List.generate(4, (i) => {'title': 'item $i'}));
      expect(await archiveBefore(items, 3), 2);
      expect((await pageBefore(items)).map((r) => r['id']), [4, 3]);
      expect(await items.query().count(), 4);
    },
  );
}
