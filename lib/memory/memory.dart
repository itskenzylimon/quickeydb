import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'memorymodel.dart';
import 'web_storage.dart';
import 'dart:async';

class Memory {
  static final Map<String, Memory> _instances = {};

  final String _defaultMemoryKey = 'memory.json';
  final int _cipher = 254;

  late String _fileName;
  Map<String, dynamic> _store = {};
  bool _initialized = false;

  // Fast I/O: debounce saving (write at most once per 300 ms)
  Timer? _saveDebounce;

  // ───────────────────────────────────────────────────────────────
  // Backward-compatible factory
  // ───────────────────────────────────────────────────────────────
  Future<Memory> instance({String? memoryKey}) async {
    final key = memoryKey ?? _defaultMemoryKey;

    // Cached instance
    if (_instances.containsKey(key)) {
      return _instances[key]!;
    }

    final mem = Memory();
    await mem._init(key);
    _instances[key] = mem;
    return mem;
  }

  Future<void> _delaySave() async {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), () async {
      await _persist();
    });
  }

  // ───────────────────────────────────────────────────────────────
  // Initialization
  // ───────────────────────────────────────────────────────────────
  Future<void> _init(String key) async {
    _fileName = key;

    if (kIsWeb) {
      _loadFromWeb();
    } else {
      await _loadFromFile();
    }

    _initialized = true;
  }

  bool isMemoryInitialized() => _initialized;
  Future<bool> isMemoryEmpty() async => _store.isEmpty;

  // ───────────────────────────────────────────────────────────────
  // Web storage
  // ───────────────────────────────────────────────────────────────
  void _loadFromWeb() {
    final raw = WebStorage.getItem(_fileName);
    if (raw != null) {
      try {
        _store = jsonDecode(raw);
      } catch (_) {
        _store = {};
      }
    }
  }

  Future<void> _saveWeb() async {
    WebStorage.setItem(_fileName, jsonEncode(_store));
  }

  // ───────────────────────────────────────────────────────────────
  // Native file storage
  // ───────────────────────────────────────────────────────────────
  Future<void> _loadFromFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');

      if (await file.exists()) {
        _store = jsonDecode(await file.readAsString());
      } else {
        _store = {};
      }
    } catch (_) {
      _store = {};
    }
  }

  Future<void> _saveFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_fileName');
    await file.writeAsString(jsonEncode(_store));
  }

  Future<void> _persist() async {
    if (kIsWeb) {
      await _saveWeb();
    } else {
      await _saveFile();
    }
  }

  // ───────────────────────────────────────────────────────────────
  // TTL Handling
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
  // CRUD
  // ───────────────────────────────────────────────────────────────
  Future<MemoryModel?> readMemory(String name) async {
    if (!_store.containsKey(name)) return null;

    final model = MemoryModel.fromMap(_store[name]);

    // TTL auto remove
    await _removeIfExpired(name, model);
    if (!_store.containsKey(name)) return null;

    model.data = _decrypt(model.data, _cipher);
    return model;
  }

  Future<List<MemoryModel>> readMemories() async {
    final results = <MemoryModel>[];

    for (final key in _store.keys.toList()) {
      final model = MemoryModel.fromMap(_store[key]);
      await _removeIfExpired(key, model);

      if (_store.containsKey(key)) {
        model.data = _decrypt(model.data, _cipher);
        results.add(model);
      }
    }

    return results;
  }

  Future<bool> upsertMemory(MemoryModel model) async {
    MemoryModel newModel;

    if (_store.containsKey(model.name)) {
      final old = MemoryModel.fromMap(_store[model.name]);

      // TTL check
      await _removeIfExpired(model.name, old);
      if (!_store.containsKey(model.name)) {
        // will be treated as new
      }

      old.data = _encrypt(model.data.toString(), _cipher);
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
  // TYPE HELPERS WITH TTL SUPPORT
  // ───────────────────────────────────────────────────────────────

  Future<bool> setString(String name, String value, {Duration? ttl}) async {
    return upsertMemory(MemoryModel(
      name: name,
      data: value,
      type: 'string',
      expiresAt: ttl == null
          ? null
          : (DateTime.now().add(ttl).microsecondsSinceEpoch.toString()),
    ));
  }

  Future<String?> getString(String name) async {
    final m = await readMemory(name);
    return m?.data;
  }

  Future<bool> setInt(String name, int value, {Duration? ttl}) async =>
      upsertMemory(MemoryModel(
        name: name,
        data: value.toString(),
        type: 'int',
        expiresAt: ttl == null
            ? null
            : (DateTime.now().add(ttl).microsecondsSinceEpoch.toString()),
      ));

  Future<int?> getInt(String name) async {
    final m = await readMemory(name);
    return m == null ? null : int.parse(m.data);
  }

  Future<bool> setBool(String name, bool value, {Duration? ttl}) async =>
      upsertMemory(MemoryModel(
        name: name,
        data: value.toString(),
        type: 'bool',
        expiresAt: ttl == null
            ? null
            : (DateTime.now().add(ttl).microsecondsSinceEpoch.toString()),
      ));

  Future<bool?> getBool(String name) async {
    final m = await readMemory(name);
    return m?.data.toLowerCase() == 'true';
  }

  Future<bool> setDouble(String name, double value, {Duration? ttl}) async =>
      upsertMemory(MemoryModel(
        name: name,
        data: value.toString(),
        type: 'double',
        expiresAt: ttl == null
            ? null
            : (DateTime.now().add(ttl).microsecondsSinceEpoch.toString()),
      ));

  Future<double?> getDouble(String name) async {
    final m = await readMemory(name);
    return m == null ? null : double.parse(m.data);
  }

  Future<bool> setDateTime(String name, DateTime value, {Duration? ttl}) async =>
      upsertMemory(MemoryModel(
        name: name,
        data: value.toIso8601String(),
        type: 'datetime',
        expiresAt: ttl == null
            ? null
            : (DateTime.now().add(ttl).microsecondsSinceEpoch.toString()),
      ));

  Future<DateTime?> getDateTime(String name) async {
    final m = await readMemory(name);
    return m == null ? null : DateTime.parse(m.data);
  }

  Future<bool> setMap(String name, Map<String, dynamic> value,
      {Duration? ttl}) async =>
      upsertMemory(MemoryModel(
        name: name,
        data: jsonEncode(value),
        type: 'map',
        expiresAt: ttl == null
            ? null
            : (DateTime.now().add(ttl).microsecondsSinceEpoch.toString()),
      ));

  Future<Map<String, dynamic>?> getMap(String name) async {
    final m = await readMemory(name);
    return m == null ? null : jsonDecode(m.data);
  }

  Future<bool> setList(String name, List value, {Duration? ttl}) async =>
      upsertMemory(MemoryModel(
        name: name,
        data: jsonEncode(value),
        type: 'list',
        expiresAt: ttl == null
            ? null
            : (DateTime.now().add(ttl).microsecondsSinceEpoch.toString()),
      ));

  Future<List?> getList(String name) async {
    final m = await readMemory(name);
    return m == null ? null : jsonDecode(m.data);
  }

  // ───────────────────────────────────────────────────────────────
  // ENCRYPT / DECRYPT
  // ───────────────────────────────────────────────────────────────
  String _encrypt(String text, int key) =>
      String.fromCharCodes(text.codeUnits.map((c) => (c + key) % 65536));

  String _decrypt(String text, int key) =>
      String.fromCharCodes(text.codeUnits.map((c) => (c - key) % 65536));
}