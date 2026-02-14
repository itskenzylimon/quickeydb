import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:idb_shim/idb.dart';
import 'package:quickeydb/memory/path_helper.dart';
// import 'package:idb_shim/idb_browser.dart' as idb_browser;
// import 'package:idb_shim/idb_io.dart' as idb_io;
import 'memorymodel.dart';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart' as idb_browser;
import 'package:idb_shim/idb_io.dart' as idb_io;
import 'package:flutter/foundation.dart';


class Memory {
  static final Map<String, Memory> _instances = {};

  final String _defaultMemoryKey = 'memory';
  final int _cipher = 254;

  late String _fileName; // used as namespace prefix
  Map<String, dynamic> _store = {};
  bool _initialized = false;

  // IDB objects
  late IdbFactory _idbFactory;
  Database? _db;

  Timer? _saveDebounce;

// ───────────────────────────────────────────────────────────────
// Factory (unchanged)
// ───────────────────────────────────────────────────────────────
  Future<Memory> instance({String? memoryKey}) async {
    final key = memoryKey ?? _defaultMemoryKey;

    if (_instances.containsKey(key)) {
      return _instances[key]!;
    }

    final mem = Memory();
    await mem._init(key);
    _instances[key] = mem;
    return mem;
  }

// ───────────────────────────────────────────────────────────────
// INIT (FULL CROSS-PLATFORM IDB: Web/WASM/Native)
// ───────────────────────────────────────────────────────────────
  Future<void> _init(String key) async {
    // 1. Get the safe path using the helper
    final String safePath = await getSafePath(key);
    _fileName = safePath;

    if (kIsWeb) {
      // Web / WASM uses browser IndexedDB
      _idbFactory = idb_browser.getIdbFactory()!;
    } else {
      // Native (Android/iOS/macOS/Windows/Linux)
      // Now _fileName contains the full absolute path
      _idbFactory = idb_io.getIdbFactoryPersistent(_fileName);
    }

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

    await _loadFromIDB();
    _initialized = true;
  }


  bool isMemoryInitialized() => _initialized;
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
          } catch (_) {}
        }
      }
    }

    await txn.completed;
  }

// ───────────────────────────────────────────────────────────────
// SAVE TO IDB
// ───────────────────────────────────────────────────────────────
  Future<void> _saveToIDB() async {
    if (_db == null) return;

    final txn = _db!.transaction('memory_store', idbModeReadWrite);
    final storeObj = txn.objectStore('memory_store');

    // Delete old keys for this namespace
    final keys = await storeObj.getAllKeys();
    for (final k in keys) {
      if (k is String && k.startsWith("$_fileName:")) {
        await storeObj.delete(k);
      }
    }

    // Write new values
    for (final entry in _store.entries) {
      final fullKey = "$_fileName:${entry.key}";
      await storeObj.put(jsonEncode(entry.value), fullKey);
    }

    await txn.completed;
  }

  Future<void> _delaySave() async {
    _saveDebounce?.cancel();
    _saveDebounce =
        Timer(const Duration(milliseconds: 300), () => _saveToIDB());
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
      await _delaySave();
    }
  }

  // ───────────────────────────────────────────────────────────────
  // CRUD (unchanged)
  // ───────────────────────────────────────────────────────────────
  Future<MemoryModel?> readMemory(String name) async {
    if (!_store.containsKey(name)) return null;

    final model = MemoryModel.fromMap(_store[name]);

    await _removeIfExpired(name, model);
    if (!_store.containsKey(name)) return null;

    model.data = _decrypt(model.data, _cipher);
    return model;
  }

  Future<List<MemoryModel>> readMemories() async {
    final list = <MemoryModel>[];

    for (final key in _store.keys.toList()) {
      final model = MemoryModel.fromMap(_store[key]);

      await _removeIfExpired(key, model);
      if (_store.containsKey(key)) {
        model.data = _decrypt(model.data, _cipher);
        list.add(model);
      }
    }

    return list;
  }

  Future<bool> upsertMemory(MemoryModel model) async {
    MemoryModel newModel;

    if (_store.containsKey(model.name)) {
      final old = MemoryModel.fromMap(_store[model.name]);

      await _removeIfExpired(model.name, old);

      old.data = _encrypt(model.data, _cipher);
      old.updatedAt = DateTime.now().microsecondsSinceEpoch.toString();
      old.version = (old.version ?? 1) + 1;
      old.expiresAt = model.expiresAt;

      newModel = old;
    } else {
      newModel = MemoryModel(
        name: model.name,
        data: _encrypt(model.data, _cipher),
        type: model.type,
        version: 1,
        createdAt: DateTime.now().microsecondsSinceEpoch.toString(),
        expiresAt: model.expiresAt,
      );
    }

    _store[model.name] = newModel.toMap();
    await _delaySave();
    return true;
  }

  Future<bool?> deleteMemory(String name) async {
    if (!_store.containsKey(name)) return null;
    _store.remove(name);
    await _delaySave();
    return true;
  }

  Future<void> clear() async {
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

  Future<bool?> getBool(String name) async =>
      (await readMemory(name))?.data.toLowerCase() == 'true';

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

  Future<bool> setMap(String name, Map<String, dynamic> v,
      {Duration? ttl}) =>
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
          : DateTime.now()
          .add(ttl)
          .microsecondsSinceEpoch
          .toString(),
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
