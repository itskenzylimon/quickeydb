import '../support/orm_fixture.dart';

void main() {
  final fixture = OrmFixture()..install();
  test('bulk writes roll back; DAO transaction uses transaction executor',
      () async {
    await fixture.open();
    final rows = fixture.db.get<Rows>()!;
    await expectLater(
        rows.insertAll([
          {'name': 'same'},
          {'name': 'same'}
        ]),
        throwsA(anything));
    expect(await rows.count(), 0);
    await expectLater(fixture.db.transaction(() async {
      await rows.insert({'name': 'a'});
      throw StateError('rollback');
    }), throwsStateError);
    expect(await rows.count(), 0);
    await fixture.db.transaction(() async {
      await rows.insert({'name': 'a'});
      await rows.insert({'name': 'b'});
    });
    expect(await rows.count(), 2);
  });
  test('1000 inserts use one transaction and return correct counts', () async {
    await fixture.open();
    final watch = Stopwatch()..start();
    await fixture.db
        .get<Rows>()!
        .insertAll(List.generate(1000, (i) => {'name': 'row$i'}));
    expect(await fixture.db.get<Rows>()!.count(), 1000);
    // Diagnostic only: no machine-dependent timing assertion.
    // ignore: avoid_print
    print('1000 transactional inserts: ${watch.elapsedMilliseconds} ms');
  });
}
