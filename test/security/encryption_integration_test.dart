import '../support/orm_fixture.dart';

void main() {
  final fixture = OrmFixture()..install();
  test('AES values hide plaintext, authenticate keys and survive reopen',
      () async {
    final key = await ValueEncryption.generateKey();
    final cipher = ValueEncryption(key);
    await fixture.open(persist: true, cipher: cipher, daos: [
      Rows(encrypted: {'note'})
    ]);
    final rows = fixture.db.get<Rows>()!;
    await rows.insert({'name': 'public', 'note': 'private needle'});
    final raw = (await fixture.db.database!.query('rows')).single['note'];
    expect(raw, startsWith(ValueEncryption.prefix));
    expect((await rows.first)!['note'], 'private needle');
    final path = fixture.db.database!.path;
    await fixture.db.close();
    expect(String.fromCharCodes(await File(path).readAsBytes()),
        isNot(contains('private needle')));
    await fixture.open(persist: true, cipher: ValueEncryption(key), daos: [
      Rows(encrypted: {'note'})
    ]);
    expect((await fixture.db.get<Rows>()!.first)!['note'], 'private needle');
    await fixture.db.close();
    await expectLater(
        fixture.open(
            persist: true,
            cipher: ValueEncryption(List.filled(32, 0)),
            daos: [
              Rows(encrypted: {'note'})
            ]),
        throwsA(anything));
    await expectLater(
        fixture.open(persist: true, daos: [Rows()]), throwsStateError);
  });
  test('legacy plaintext encryption migration and tamper rejection', () async {
    final cipher = ValueEncryption(await ValueEncryption.generateKey(),
        allowPlaintextReads: true);
    await fixture.open(persist: true, cipher: cipher, daos: [
      Rows(encrypted: {'note'})
    ]);
    final rows = fixture.db.get<Rows>()!;
    await fixture.db.database!
        .insert('rows', {'name': 'legacy', 'note': 'legacy secret'});
    expect((await rows.first)!['note'], 'legacy secret');
    await rows.encryptExisting();
    await rows.encryptExisting();
    expect((await rows.first)!['note'], 'legacy secret');
    expect(
        String.fromCharCodes(
            await File(fixture.db.database!.path).readAsBytes()),
        isNot(contains('legacy secret')));
    expect(() => rows.where({'note': 'secret'}), throwsUnsupportedError);
    expect(() => rows.order(['note'], 'ASC'), throwsUnsupportedError);
    expect(() => rows.group(['note']), throwsUnsupportedError);
    await fixture.db.database!
        .update('rows', {'note': '${ValueEncryption.prefix}broken'});
    await expectLater(rows.first, throwsA(anything));
  });
  test('cipher randomizes equal values and binds the context', () async {
    final cipher = ValueEncryption(await ValueEncryption.generateKey());
    final a = await cipher.encrypt('same', context: 'table.column');
    final b = await cipher.encrypt('same', context: 'table.column');
    expect(a, isNot(b));
    await expectLater(
        cipher.decrypt(a, context: 'other.column'), throwsA(anything));
  });
  test('full-file encryption fails closed on ordinary SQLite', () async {
    await expectLater(
        fixture.open(databaseKey: List.filled(32, 1)), throwsUnsupportedError);
  });
}
