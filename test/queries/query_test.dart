import '../support/orm_fixture.dart';

void main() {
  final fixture = OrmFixture()..install();
  test('aggregates clear filters; real values and empty projections', () async {
    await fixture.open();
    final rows = fixture.db.get<Rows>()!;
    expect(await rows.pick(['name']), isEmpty);
    await rows.insertAll([
      {'id': 1, 'name': 'a', 'score': 1.5},
      {'id': 2, 'name': 'b', 'score': 2.5}
    ]);
    expect(await rows.where({'id': 1}).count(), 1);
    expect(await rows.toList(), hasLength(2));
    expect(await rows.maximum('score'), 2.5);
    expect(await rows.minimum('score'), 1.5);
    expect(await rows.sumNumber('score'), 4.0);
    expect(await rows.pick(['name']), ['a']);
    expect(await rows.pluck(['name']), ['a', 'b']);
    expect(await rows.select(['name']).toMap(), [
      {'name': 'a'},
      {'name': 'b'}
    ]);
  });
  test('independent query scopes and failures do not leak', () async {
    await fixture.open();
    final rows = fixture.db.get<Rows>()!;
    await rows.insertAll([
      {'id': 1, 'name': 'a'},
      {'id': 2, 'name': 'b'}
    ]);
    final first = rows.query().where({'id': 1});
    final second = rows.query().where({'id': 2});
    final results = await Future.wait([first.toList(), second.toList()]);
    expect(results[0].single!['id'], 1);
    expect(results[1].single!['id'], 2);
    await expectLater(rows.where({'missing': 1}).toList(), throwsA(anything));
    expect(await rows.count(), 2);
  });
  test('null equality, OR shorthand, NOT, bounds and diagnostic SQL', () async {
    await fixture.open();
    final rows = fixture.db.get<Rows>()!;
    await rows.insertAll([
      {'id': 1, 'name': 'a'},
      {'id': 2, 'name': 'b', 'note': 'x'}
    ]);
    expect(await rows.where({'note': null}).count(), 1);
    expect(await rows.where({'name': 'a'}).or({'name': 'b'}).count(), 2);
    expect(await rows.not({'name': 'a'}).count(), 1);
    expect(() => rows.limit(-1), throwsArgumentError);
    expect(rows.toSql(), contains('SELECT'));
    expect(await rows.count(), 2);
  });
}
