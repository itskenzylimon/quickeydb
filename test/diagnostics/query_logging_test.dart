import '../support/orm_fixture.dart';

void main() {
  final fixture = OrmFixture()..install();
  test('diagnostics trace CRUD, redact values, and preserve errors', () async {
    final events = <QueryLogEvent>[];
    final logging = QueryLogging(includeSql: true, onQuery: events.add);
    final db = await QuickeyDB.initialize(
        dbName: 'logs',
        dbVersion: 1,
        dbPath: fixture.directory.path,
        persist: false,
        dataAccessObjects: [Rows()],
        queryLogging: logging,
        conflictAlgorithm: ConflictAlgorithm.abort);
    final dao = db.get<Rows>()!;
    await dao.insert({'id': 1, 'name': 'private-secret'});
    await dao.query().where({'name': 'private-secret'}).toMap();
    await dao.query().where({'id': 1}).updateAll({'name': 'another-secret'});
    await expectLater(
        dao.insert({'id': 2, 'name': 'another-secret'}), throwsA(anything));
    await dao.destroy(1);
    expect(events.map((e) => e.operation),
        ['INSERT', 'SELECT', 'UPDATE', 'INSERT', 'DELETE']);
    expect(events[1].sql, contains('?'));
    expect(events[1].parameterCount, 1);
    expect(events[1].rowCount, 1);
    expect(events.first.rowCount, isNull); // Generated row ID is not a count.
    expect(events[3].succeeded, isFalse);
    expect(events[3].errorType, isNotNull);
    expect(events.join(), isNot(contains('private-secret')));
    expect(events.join(), isNot(contains('another-secret')));
    logging.enabled = false;
    await dao.count();
    expect(events, hasLength(5));
  });
  test('SQL is opt-in and observer exceptions cannot break database work',
      () async {
    final events = <QueryLogEvent>[];
    final logging = QueryLogging(onQuery: (_) => throw StateError('observer'));
    logging.addListener(events.add);
    final db = await QuickeyDB.initialize(
        dbName: 'logs',
        dbVersion: 1,
        dbPath: fixture.directory.path,
        persist: false,
        dataAccessObjects: [Rows()],
        queryLogging: logging);
    final dao = db.get<Rows>()!;
    await dao.insert({'name': 'ok'});
    expect(await dao.count(), 1);
    expect(events.every((e) => e.sql == null), isTrue);
    logging.removeListener(events.add);
    await dao.count();
    expect(events, hasLength(2));
  });
}
