import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickeydb/memory/memory.dart';
import 'package:quickeydb/security/value_encryption.dart';

void main() {
  late Directory directory;
  final handles = <Memory>[];
  Future<Memory> open({ValueEncryption? cipher}) async {
    final memory = await Memory().instance(
        memoryKey: directory.path,
        storagePath: '${directory.path}/memory',
        encryption: cipher);
    handles.add(memory);
    return memory;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('quickey_memory_');
  });
  tearDown(() async {
    for (final m in handles) {
      await m.close();
    }
    handles.clear();
    await directory.delete(recursive: true);
  });
  test('legacy values, typed getters, durable writes and reopen', () async {
    var m = await open();
    expect(await m.getBool('missing'), isNull);
    await m.setString('name', 'legacy');
    await m.setBool('false', false);
    await m.setInt('n', 42);
    await m.setMap('map', {'a': 1});
    await m.close();
    m = await open();
    expect(await m.getString('name'), 'legacy');
    expect(await m.getBool('false'), isFalse);
    expect(await m.getInt('n'), 42);
    expect(await m.getMap('map'), {'a': 1});
  });
  test('concurrent first open shares one handle; encrypted storage reopens',
      () async {
    final cipher = ValueEncryption(await ValueEncryption.generateKey());
    final instances =
        await Future.wait([open(cipher: cipher), open(cipher: cipher)]);
    expect(identical(instances[0], instances[1]), isTrue);
    await instances[0].setString('private', 'needle-secret');
    await instances[0].close();
    final m = await open(cipher: cipher);
    expect(await m.getString('private'), 'needle-secret');
    await m.close();
    final bytes = <int>[];
    for (final file in directory.listSync(recursive: true).whereType<File>()) {
      bytes.addAll(file.readAsBytesSync());
    }
    expect(String.fromCharCodes(bytes), isNot(contains('needle-secret')));
    await expectLater(
        open(cipher: ValueEncryption(List.filled(32, 0))), throwsA(anything));
  });
  test('legacy namespace migration to AES and TTL expiry', () async {
    var m = await open();
    await m.setString('old', 'old data');
    await m.close();
    final cipher = ValueEncryption(await ValueEncryption.generateKey(),
        allowPlaintextReads: true);
    m = await open(cipher: cipher);
    expect(await m.getString('old'), 'old data');
    await m.encryptExisting();
    await m.setBool('expired', true, ttl: const Duration(milliseconds: -1));
    expect(await m.getBool('expired'), isNull);
    await m.close();
    m = await open(cipher: cipher);
    expect(await m.getString('old'), 'old data');
  });
  test('close drains in-flight encrypted writes and is concurrently idempotent',
      () async {
    final cipher = ValueEncryption(await ValueEncryption.generateKey());
    var memory = await open(cipher: cipher);
    final write = memory.setString('last', 'committed before close');
    await Future.wait([write, memory.close(), memory.close()]);
    memory = await open(cipher: cipher);
    expect(await memory.getString('last'), 'committed before close');
  });
  test('delete and clear persist and closed handles reject writes', () async {
    var m = await open();
    await m.setInt('n', 1);
    await m.deleteMemory('n');
    await m.setInt('other', 2);
    await m.clear();
    await m.close();
    await expectLater(m.setInt('closed', 3), throwsStateError);
    m = await open();
    expect(await m.isMemoryEmpty(), isTrue);
  });
  test('configuration mismatch preserves the active namespace and its data',
      () async {
    final key = await ValueEncryption.generateKey();
    final active = await open(cipher: ValueEncryption(key));
    await active.setString('keep', 'original');
    await expectLater(
        open(cipher: ValueEncryption(List.filled(32, 0))), throwsStateError);
    await expectLater(
        Memory().instance(
            memoryKey: directory.path,
            storagePath: '${directory.path}/different',
            encryption: ValueEncryption(key)),
        throwsStateError);
    final same = await open(cipher: ValueEncryption(key));
    expect(identical(active, same), isTrue);
    expect(await same.getString('keep'), 'original');
  });
  test('expired and deleted keys do not remove unrelated values', () async {
    final cipher = ValueEncryption(await ValueEncryption.generateKey());
    final store = await open(cipher: cipher);
    await store.setString('keep', 'durable');
    await store.setString('expired', 'temporary',
        ttl: const Duration(seconds: -1));
    expect(await store.getString('expired'), isNull);
    await store.deleteMemory('expired');
    await store.close();
    final reopened = await open(cipher: cipher);
    expect(await reopened.getString('keep'), 'durable');
    expect(await reopened.getString('expired'), isNull);
  });
}
