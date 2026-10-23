import '../support/orm_fixture.dart';

void main() {
  final fixture = OrmFixture()..install();
  test('persistent legacy database reopens; private path is opt-in', () async {
    await fixture.open(persist: true);
    await fixture.db.get<Rows>()!.insert({'name': 'old'});
    final path = fixture.db.database!.path;
    expect(path, '${fixture.directory.path}/test.db');
    await fixture.db.close();
    await fixture.open(persist: true);
    expect((await fixture.db.get<Rows>()!.first)!['name'], 'old');
    await fixture.db.close();
    await fixture.open(persist: true, privateStorage: true);
    expect(fixture.db.database!.path, contains('/.quickeydb/'));
  });
  test('asset import writes and opens the resolved custom database path',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await fixture.open(persist: true);
    await fixture.db.get<Rows>()!.insert({'name': 'asset row'});
    final path = fixture.db.database!.path;
    await fixture.db.close();
    final bytes = await File(path).readAsBytes();
    await File(path).rename('$path.fixture');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets',
        (message) async => ByteData.sublistView(Uint8List.fromList(bytes)));
    try {
      fixture.db = await QuickeyDB.initialize(
          dbName: 'test',
          dbVersion: 1,
          dbPath: fixture.directory.path,
          dataAccessObjects: [Rows()],
          importDB: true);
      expect(fixture.db.database!.path, path);
      expect((await fixture.db.get<Rows>()!.first)!['name'], 'asset row');
    } finally {
      messenger.setMockMessageHandler('flutter/assets', null);
    }
  });
  test('additive upgrade preserves rows indexes and triggers', () async {
    await fixture.open(persist: true);
    await fixture.db.get<Rows>()!.insert({'name': 'old'});
    await fixture.db.database!.execute('CREATE INDEX name_idx ON rows (name)');
    await fixture.db.database!.execute(
        'CREATE TRIGGER touch AFTER INSERT ON rows BEGIN UPDATE rows SET score=7 WHERE id=NEW.id; END');
    await fixture.db.close();
    final dao = Rows(
        sql:
            'CREATE TABLE rows (id INTEGER NOT NULL PRIMARY KEY, name TEXT NOT NULL UNIQUE, score REAL DEFAULT 0, note TEXT, added TEXT DEFAULT \'ok\')');
    await fixture.open(persist: true, version: 2, daos: [dao]);
    expect((await dao.first)!['added'], 'ok');
    expect(
        await fixture.db.database!.rawQuery(
            "SELECT name FROM sqlite_master WHERE name IN ('name_idx','touch')"),
        hasLength(2));
  });
  test('additive upgrade preserves deleted autoincrement high-water mark',
      () async {
    final first = Rows(
        sql:
            'CREATE TABLE rows (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)');
    await fixture.open(persist: true, daos: [first]);
    await first.insert({'id': 100, 'name': 'deleted'});
    await first.destroy(100);
    await fixture.db.close();
    final next = Rows(
        sql:
            'CREATE TABLE rows (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, added TEXT)');
    await fixture.open(persist: true, version: 2, daos: [next]);
    expect(await next.insert({'name': 'next'}), 101);
  });
  test('failed destructive upgrade rolls back and original file reopens',
      () async {
    await fixture.open(persist: true);
    await fixture.db.get<Rows>()!.insert({'name': 'old'});
    await fixture.db.close();
    await expectLater(
        fixture.open(persist: true, version: 2, daos: [
          Rows(sql: 'CREATE TABLE rows (id INTEGER PRIMARY KEY, name TEXT)')
        ]),
        throwsStateError);
    await fixture.open(persist: true);
    expect((await fixture.db.get<Rows>()!.first)!['name'], 'old');
  });
}
