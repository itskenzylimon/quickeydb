import '../support/orm_fixture.dart';

void main() {
  final fixture = OrmFixture()..install();
  test('multiple includes group all children and match HasOne by FK', () async {
    await fixture.open(daos: [Parents(), Children(), Profiles()]);
    final parents = fixture.db.get<Parents>()!,
        children = fixture.db.get<Children>()!,
        profiles = fixture.db.get<Profiles>()!;
    await parents.insertAll([
      {'id': 1, 'name': 'one'},
      {'id': 2, 'name': 'two'}
    ]);
    await children.insertAll([
      {'id': 10, 'parent_id': 1},
      {'id': 11, 'parent_id': 1},
      {'id': 12, 'parent_id': 1},
      {'id': 20, 'parent_id': 2}
    ]);
    await profiles.insertAll([
      {'id': 99, 'parent_id': 1, 'note': 'p1'},
      {'id': 98, 'parent_id': 2, 'note': 'p2'}
    ]);
    final result = await parents
        .order(['id'], 'ASC').includes([Children, Profiles]).toMap();
    expect(result[0]['children'], hasLength(3));
    expect(result[1]['children'], hasLength(1));
    expect((result[0]['map<string?, dynamic>'] as Map?)?['note'], 'p1');
  });
  test('belongsTo includes and joins preserve nested relation conventions',
      () async {
    await fixture.open(daos: [Parents(), Children(), Profiles()]);
    await fixture.db.get<Parents>()!.insert({'id': 3, 'name': 'owner'});
    final children = fixture.db.get<Children>()!;
    await children.insert({'id': 22, 'parent_id': 3, 'name': 'child'});
    final included = (await children.includes([Parents]).toMap()).single;
    expect((included['map<string?, dynamic>'] as Map)['name'], 'owner');
    final joined = (await children.joins([Parents]).toMap()).single;
    expect((joined['map<string?, dynamic>'] as Map)['id'], 3);
    expect(joined['id'], 22);
  });
  test('unknown includes fail without leaving query state', () async {
    await fixture.open();
    final rows = fixture.db.get<Rows>()!;
    await rows.insert({'name': 'first'});
    await expectLater(rows.includes([Parents]).toMap(), throwsArgumentError);
    expect(await rows.count(), 1);
  });
  test('nested insert writes parent once and rolls back failed children',
      () async {
    await fixture
        .open(daos: [Parents(), Children(), Profiles()], foreignKeys: true);
    final parents = fixture.db.get<Parents>()!;
    await parents.insert({
      'id': 1,
      'name': 'one',
      'children': [
        {'id': 10, 'name': 'c'}
      ]
    });
    expect(await parents.count(), 1);
    expect(await fixture.db.get<Children>()!.count(), 1);
    await expectLater(
        parents.insert({
          'id': 2,
          'children': [
            {'id': 10}
          ]
        }),
        throwsA(anything));
    expect(await parents.count(), 1);
  });
}
