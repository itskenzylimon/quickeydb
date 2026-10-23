import 'dart:convert';
import 'dart:async';
import 'package:idb_shim/idb.dart';
import 'package:quickeydb/memory/path_helper.dart';
import '../security/value_encryption.dart';
import 'idb_factory_web.dart' if (dart.library.io) 'idb_factory_io.dart';
import 'memorymodel.dart';

class Memory {
  static final Map<String, Future<Memory>> _instances = {};
  ValueEncryption? _encryption;
  String? _instanceKey;
  Future<void> _pendingSave = Future.value();
  final Set<String> _dirty = {}, _deleted = {};
  bool _closed = false;
  Future<void>? _closing;
  int _activeWrites = 0;
  Completer<void>? _drained;

  final String _defaultMemoryKey = 'memory';
  final int _cipher = 254;

  late String _fileName; // used as namespace prefix
  Map<String, dynamic> _store = {};
  bool _initialized = false;

  // IDB objects
  late IdbFactory _idbFactory;
  Database? _db;

// ───────────────────────────────────────────────────────────────
// Factory (unchanged)
// ───────────────────────────────────────────────────────────────
  Future<Memory> instance(
      {String? memoryKey,
      ValueEncryption? encryption,
      String? storagePath}) async {
    final key = memoryKey ?? _defaultMemoryKey;
    final pending = _instances.putIfAbsent(key, () async {
      final mem = Memory().._encryption = encryption;
      mem._instanceKey = key;
      await mem._init(key, storagePath);
      return mem;
    });
    try {
      final mem = await pending;
      if (storagePath != null && mem._fileName != storagePath) {
        throw StateError('Namespace already opened at a different path.');
      }
      if (!identical(mem._encryption, encryption) &&
          (mem._encryption == null ||
              encryption == null ||
              !await mem._encryption!.hasSameKey(encryption))) {
        throw StateError(
            'Namespace already opened with a different encryption configuration.');
      }
      return mem;
    } catch (_) {
      if (identical(_instances[key], pending)) {
        // Do not evict a successfully opened namespace on a key mismatch.
        final opened =
            await pending.then<Memory?>((v) => v, onError: (_) => null);
        if (opened == null) _instances.remove(key);
      }
      rethrow;
    }
  }

// ───────────────────────────────────────────────────────────────
// INIT (FULL CROSS-PLATFORM IDB: Web/WASM/Native)
// ───────────────────────────────────────────────────────────────
  Future<void> _init(String key, String? storagePath) async {
    // 1. Get the safe path using the helper
    final String safePath = storagePath ?? await getSafePath(key);
    _fileName = safePath;

    _idbFactory = memoryFactory(_fileName);

    _db = await _idbFactory.open(
      "quickey_memory_db",
      version: 1,
      onUpgradeNeeded: (VersionChangeEvent e) {
        final db = e.database;
        if (!db.objectStoreNames.contains("memory_store")) {
          db.createObjectStore("memory_store");
        }
      },
    );

    try {
      await _loadFromIDB();
      for (final entry in _store.values) {
        final model =
            MemoryModel.fromMap(Map<String, dynamic>.from(entry as Map));
        if (model.data.startsWith('qdb:aesgcm:')) {
          await _decode(model.data, model.name);
        }
      }
      _initialized = true;
    } catch (_) {
      _db?.close();
      rethrow;
    }
  }

  void _checkOpen() {
    if (!_initialized || _closed || _closing != null) {
      throw StateError('Memory is not open.');
    }
  }

  bool isMemoryInitialized() => _initialized && !_closed;
  Future<bool> isMemoryEmpty() async => _store.isEmpty;

// ───────────────────────────────────────────────────────────────
// LOAD FROM IDB
// ───────────────────────────────────────────────────────────────
  Future<void> _loadFromIDB() async {
    _store = {};

    final txn = _db!.transaction('memory_store', idbModeReadOnly);
    final storeObj = txn.objectStore('memory_store');

    final keys = await storeObj.getAllKeys();

    for (final k in keys) {
      if (k is String && k.startsWith("$_fileName:")) {
        final val = await storeObj.getObject(k);
        if (val is String) {
          final shortKey = k.substring(_fileName.length + 1);

          try {
            _store[shortKey] = jsonDecode(val);
          } catch (error) {
            throw FormatException('Corrupt Memory entry: $shortKey', error);
          }
        }
      }
    }

    await txn.completed;
  }

// ───────────────────────────────────────────────────────────────
// SAVE TO IDB
// ───────────────────────────────────────────────────────────────
  /// Completes only after pending values are durable in the IDB transaction.
  Future<void> flush() {
    if (_closed) throw StateError('Memory is closed.');
    final operation = _pendingSave.then((_) => _saveToIDB());
    _pendingSave =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  Future<void> _saveToIDB() async {
    if (_db == null || (_dirty.isEmpty && _deleted.isEmpty)) return;
    final changed = {for (final k in _dirty) k: jsonEncode(_store[k])};
    final deleted = Set<String>.from(_deleted);
    _dirty.clear();
    _deleted.clear();
    try {
      final txn = _db!.transaction('memory_store', idbModeReadWrite);
      final store = txn.objectStore('memory_store');
      for (final key in deleted) {
        await store.delete('$_fileName:$key');
      }
      for (final entry in changed.entries) {
        await store.put(entry.value, '$_fileName:${entry.key}');
      }
      await txn.completed;
    } catch (_) {
      for (final key in changed.keys) {
        if (_store.containsKey(key)) _dirty.add(key);
      }
      for (final key in deleted) {
        if (!_store.containsKey(key)) _deleted.add(key);
      }
      rethrow;
    }
  }

  Future<void> _delaySave() => flush();

  /// Rewrites legacy shifted values using the configured authenticated cipher.
  Future<void> encryptExisting() async {
    _checkOpen();
    if (_encryption == null) throw StateError('Encryption key required.');
    final entries = await readMemories();
    for (final entry in entries) {
      await upsertMemory(entry);
    }
    await flush();
  }

  Future<void> close() {
    if (_closed) return Future.value();
    return _closing ??= _finishClose().whenComplete(() {
      if (!_closed) _closing = null;
    });
  }

  Future<void> _finishClose() async {
    if (_activeWrites > 0) {
      _drained ??= Completer<void>();
      await _drained!.future;
    }
    await flush();
    _db?.close();
    _closed = true;
    _initialized = false;
    _instances.remove(_instanceKey);
  }

  Future<String> _encode(String data, String name) async => _encryption == null
      ? _encrypt(data, _cipher)
      : await _encryption!.encrypt(data, context: 'memory:$_fileName:$name');

  Future<String> _decode(String data, String name) async {
    if (data.startsWith('qdb:aesgcm:')) {
      final cipher =
          _encryption ?? (throw StateError('Encryption key required.'));
      return await cipher.decrypt(data, context: 'memory:$_fileName:$name')
          as String;
    }
    if (_encryption?.allowPlaintextReads == false) {
      throw StateError('Legacy Memory value requires migration permission.');
    }
    return _decrypt(data, _cipher);
  }

  // ───────────────────────────────────────────────────────────────
  // TTL (unchanged)
  // ───────────────────────────────────────────────────────────────
  bool _isExpired(MemoryModel model) {
    if (model.expiresAt == null) return false;
    final expiry = int.tryParse(model.expiresAt!);
    if (expiry == null) return false;
    return DateTime.now().microsecondsSinceEpoch > expiry;
  }

  Future<void> _removeIfExpired(String key, MemoryModel model) async {
    if (_isExpired(model)) {
      _store.remove(key);
      _dirty.remove(key);
      _deleted.add(key);
      await _delaySave();
    }
  }

  // ───────────────────────────────────────────────────────────────
  // CRUD (unchanged)
  // ───────────────────────────────────────────────────────────────
  Future<MemoryModel?> readMemory(String name) async {
    _checkOpen();
    if (!_store.containsKey(name)) return null;

    final model = MemoryModel.fromMap(_store[name]);

    await _removeIfExpired(name, model);
    if (!_store.containsKey(name)) return null;

    model.data = await _decode(model.data, model.name);
    return model;
  }

  Future<List<MemoryModel>> readMemories() async {
    _checkOpen();
    final list = <MemoryModel>[];

    for (final key in _store.keys.toList()) {
      final model = MemoryModel.fromMap(_store[key]);

      await _removeIfExpired(key, model);
      if (_store.containsKey(key)) {
        model.data = await _decode(model.data, model.name);
        list.add(model);
      }
    }

    return list;
  }

  Future<bool> upsertMemory(MemoryModel model) async {
    _checkOpen();
    _activeWrites++;
    try {
      MemoryModel newModel;

      final previous = _store[model.name];
      if (previous != null) {
        await _removeIfExpired(model.name, MemoryModel.fromMap(previous));
      }
      if (_store.containsKey(model.name)) {
        final old = MemoryModel.fromMap(_store[model.name]);

        await _removeIfExpired(model.name, old);

        old.data = await _encode(model.data, model.name);
        old.updatedAt = DateTime.now().microsecondsSinceEpoch.toString();
        old.version = (old.version ?? 1) + 1;
        old.expiresAt = model.expiresAt;

        newModel = old;
      } else {
        newModel = MemoryModel(
          name: model.name,
          data: await _encode(model.data, model.name),
          type: model.type,
          version: 1,
          createdAt: DateTime.now().microsecondsSinceEpoch.toString(),
          expiresAt: model.expiresAt,
        );
      }

      _store[model.name] = newModel.toMap();
      _dirty.add(model.name);
      _deleted.remove(model.name);
      await _delaySave();
      return true;
    } finally {
      _activeWrites--;
      if (_activeWrites == 0 && _drained != null) {
        _drained!.complete();
        _drained = null;
      }
    }
  }

  Future<bool?> deleteMemory(String name) async {
    _checkOpen();
    if (!_store.containsKey(name)) return null;
    _store.remove(name);
    _dirty.remove(name);
    _deleted.add(name);
    await _delaySave();
    return true;
  }

  Future<void> clear() async {
    _checkOpen();
    _deleted.addAll(_store.keys);
    _dirty.clear();
    _store.clear();
    await _delaySave();
  }

  Future<bool> hasMemory(String name) async {
    return (await readMemory(name)) != null;
  }

  // ───────────────────────────────────────────────────────────────
  // TYPE HELPERS (unchanged)
  // ───────────────────────────────────────────────────────────────

  Future<bool> setString(String name, String value, {Duration? ttl}) =>
      upsertMemory(_wrap(name, value, 'string', ttl));

  Future<String?> getString(String name) async =>
      (await readMemory(name))?.data;

  Future<bool> setInt(String name, int v, {Duration? ttl}) =>
      upsertMemory(_wrap(name, v.toString(), 'int', ttl));

  Future<int?> getInt(String name) async {
    final m = await readMemory(name);
    return m == null ? null : int.tryParse(m.data);
  }

  Future<bool> setBool(String name, bool v, {Duration? ttl}) =>
      upsertMemory(_wrap(name, v.toString(), 'bool', ttl));

  Future<bool?> getBool(String name) async {
    final model = await readMemory(name);
    return model == null ? null : model.data.toLowerCase() == 'true';
  }

  Future<bool> setDouble(String name, double v, {Duration? ttl}) =>
      upsertMemory(_wrap(name, v.toString(), 'double', ttl));

  Future<double?> getDouble(String name) async {
    final m = await readMemory(name);
    return m == null ? null : double.tryParse(m.data);
  }

  Future<bool> setDateTime(String name, DateTime v, {Duration? ttl}) =>
      upsertMemory(_wrap(name, v.toIso8601String(), 'datetime', ttl));

  Future<DateTime?> getDateTime(String name) async {
    final m = await readMemory(name);
    return m == null ? null : DateTime.tryParse(m.data);
  }

  Future<bool> setMap(String name, Map<String, dynamic> v, {Duration? ttl}) =>
      upsertMemory(_wrap(name, jsonEncode(v), 'map', ttl));

  Future<Map<String, dynamic>?> getMap(String name) async {
    final m = await readMemory(name);
    return m == null ? null : jsonDecode(m.data);
  }

  Future<bool> setList(String name, List v, {Duration? ttl}) =>
      upsertMemory(_wrap(name, jsonEncode(v), 'list', ttl));

  Future<List?> getList(String name) async {
    final m = await readMemory(name);
    return m == null ? null : jsonDecode(m.data);
  }

  // ───────────────────────────────────────────────────────────────
  // WRAP (unchanged)
  // ───────────────────────────────────────────────────────────────
  MemoryModel _wrap(String n, String d, String t, Duration? ttl) {
    return MemoryModel(
      name: n,
      data: d,
      type: t,
      expiresAt: ttl == null
          ? null
          : DateTime.now().add(ttl).microsecondsSinceEpoch.toString(),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // ENCRYPTION (unchanged)
  // ───────────────────────────────────────────────────────────────
  String _encrypt(String text, int key) =>
      String.fromCharCodes(text.codeUnits.map((c) => (c + key) % 65536));

  String _decrypt(String text, int key) =>
      String.fromCharCodes(text.codeUnits.map((c) => (c - key) % 65536));
}
