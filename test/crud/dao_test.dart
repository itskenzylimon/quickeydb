import '../support/orm_fixture.dart';

void main() {
  final fixture = OrmFixture()..install();
  test('legacy fluent API, nullable-key converters, IDs and updates', () async {
    await fixture.open();
    final rows = fixture.db.get<Rows>()!;
    final input = <String?, dynamic>{'name': 'first', 'score': 1.5};
    final id = await rows.insert(input);
    expect(input['id'], id);
    expect(await rows.isEmpty, isFalse);
    final row = (await rows.find(id))!;
    row['name'] = 'changed';
    expect(await rows.update(row), 1);
    expect((await rows.find(id))!['name'], 'changed');
    expect(await rows.delete(row), 1);
    expect(await rows.isEmpty, isTrue);
  });
  test('scoped deletion is explicit; legacy destroyAll remains whole-table',
      () async {
    await fixture.open();
    final rows = fixture.db.get<Rows>()!;
    await rows.insertAll([
      {'id': 1, 'name': 'a'},
      {'id': 2, 'name': 'b'}
    ]);
    expect(() => rows.where({'id': 1}).destroyAll(), throwsStateError);
    expect(await rows.count(), 2);
    expect(await rows.where({'id': 1}).deleteWhere(), 1);
    expect(await rows.destroyAll(), 1);
  });
  test('legacy replacement policy is still available', () async {
    fixture.db = await QuickeyDB.initialize(
        dbName: 'test',
        dbVersion: 1,
        dbPath: fixture.directory.path,
        dataAccessObjects: [Rows()],
        persist: false);
    final rows = fixture.db.get<Rows>()!;
    await rows.insert({'id': 1, 'name': 'same'});
    await rows.insert({'id': 2, 'name': 'same'});
    expect(await rows.count(), 1);
    expect((await rows.first)!['id'], 2);
  });
}
