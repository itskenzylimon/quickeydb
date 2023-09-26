import 'dart:convert';

import 'memorymodel.dart';
import 'package:quickeydb/quickeydb.dart'
    if (dart.library.html) 'package:quickeydb/quickeywebdb.dart';

/// Memory is a class that is used to store data in a file.
class Memory {
  final String _defaultMemoryKey = 'memory.db';
  final int _cipher = 254;

  QuickeyDBImpl? _quickeyDBImpl;

  Future<Memory> initMemory() async {
    Memory memory = Memory();
    memory._quickeyDBImpl = await QuickeyDB.initialize(
      dbName: _defaultMemoryKey,
      persist: false,
      debugging: true,
      dbVersion: 1,
      dataAccessObjects: [
        MapDataSchema(),
      ],
    );
    _quickeyDBImpl = memory._quickeyDBImpl;
    return memory;
  }

  Future<Memory> instance({String? memoryKey}) async {
    Memory memory = Memory();
    String dbName = memoryKey == null ? _defaultMemoryKey : '$_defaultMemoryKey.db';
    memory._quickeyDBImpl = await QuickeyDB.initialize(
      dbName: dbName,
      persist: true,
      debugging: false,
      dbVersion: 1,
      // dbPath: Directory.current.path,
      // dbPath: '/database/web',
      dataAccessObjects: [
        MapDataSchema(),
      ],
    );
    _quickeyDBImpl = memory._quickeyDBImpl;
    return memory;
  }

  /// Check if [Memory] is empty.
  Future<bool> isMemoryEmpty() async {
    int count = 0;
    if (isMemoryInitialized()) {
      count = await _quickeyDBImpl!<MapDataSchema>()?.count() ?? 0;
      return count >= 1 ? false : true;
    }
    return true;
  }

  /// Check if [Memory] is initialized.
  bool isMemoryInitialized() {
    if (_quickeyDBImpl == null) {
      return false;
    }
    return true;
  }

  /// Get all data from [Memory].
  ///
  /// Will return empty list if entries are not found
  Future<List<MemoryModel>> readMemories() async {
    List<MemoryModel?>? data = await _quickeyDBImpl!<MapDataSchema>()?.all;
    List<MemoryModel> dataList = [];
    if (data != null) {
      for (MemoryModel? memoryModel in data) {
        if (memoryModel != null) {
          dataList.add(memoryModel);
        }
      }
    }
    return dataList;
  }

  /// Get data from [Memory].
  ///
  /// [key] is the key of the entry you want to get, this is required and is
  /// used to represent the entry as the unique identifier.
  ///
  /// [value] is set to true by default. If you want to get the entire entry you
  /// can set this to false. This will return the entire entry as a Map. containing
  /// the [key], [value], [createdAt], [updatedAt] and [expiresAt].
  ///
  /// Will return [null] if entry is not found or Map if [value] is set to false.
  /// and the value if [value] is set to true.
  Future<MemoryModel?> readMemory(String name) async {
    try{
      MemoryModel? memoryModel =
      await _quickeyDBImpl!<MapDataSchema>()!.where({'name': name}).first;
      if (memoryModel == null) {
        return null;
      }
      memoryModel.data = _decrypt(memoryModel.data.toString(), _cipher);
      return memoryModel;
    } catch(e){
      return null;
    }
  }

  /// Performs a create when a [key] does not exist and an update when it does.
  ///
  /// This is a safer method to use when you are uncertain if a [key] exists.
  ///
  /// Out of the hood, this function performs a createMemory if the [key] does
  /// and updateMemory if it does.
  ///
  /// If a value exist it does an update in initialize.
  Future<bool> upsertMemory<T>(MemoryModel newMemory) async {

    MemoryModel? model = await readMemory(newMemory.name);
    if (model == null) {
      MemoryModel? model = MemoryModel(
          name: newMemory.name,
          data: _encrypt(newMemory.data, _cipher),
          type: newMemory.type,
        version: 1,
        createdAt: DateTime.now().microsecondsSinceEpoch.toString()
      );
      _quickeyDBImpl!<MapDataSchema>()!.create(model);
    } else {
      model.data = _encrypt(newMemory.data.toString(), _cipher);
      model.updatedAt = DateTime.now().microsecondsSinceEpoch.toString();
      model.version = (newMemory.version ?? 1) + 1;
          _quickeyDBImpl!<MapDataSchema>()!.update(model);
    }
    return true;
  }

  ///Set bool [setBool]
  Future<bool> setBool(String name, bool value) async {
    MemoryModel memoryModel = MemoryModel(
        name: name,
        data: value.toString(),
        type: 'bool');
    return await upsertMemory(memoryModel);
  }

  ///Get bool [getBool]
  Future<bool?> getBool(String name) async {
    try{
      MemoryModel? memoryModel = await _quickeyDBImpl!<MapDataSchema>()!
          .findBy({'name': name});
      if (memoryModel == null) {
        return null;
      }
      return bool.parse(_decrypt(memoryModel.data, _cipher));
    } catch (e){
      return null;
    }
  }

  ///Set String [setString]
  Future<bool> setString(String name, String value) async {
    MemoryModel memoryModel = MemoryModel(
        name: name,
        data: value,
        type: 'string');
    return await upsertMemory(memoryModel);
  }

  ///Get String [getString]
  Future<String?> getString(String name) async {
    try{
      MemoryModel? memoryModel = await _quickeyDBImpl!<MapDataSchema>()!
          .findBy({'name': name});
      if (memoryModel == null) {
        return null;
      }
      return _decrypt(memoryModel.data, _cipher);
    } catch (e){
      return null;
    }
  }

  ///Set Double [setDouble]
  Future<bool> setDouble(String name, double value) async {
    MemoryModel memoryModel = MemoryModel(
        name: name,
        data: value.toString(),
        type: 'double');
    return await upsertMemory(memoryModel);
  }

  ///Get Double [getDouble]
  Future<double?> getDouble(String name) async {
    try{
      MemoryModel? memoryModel = await _quickeyDBImpl!<MapDataSchema>()!
          .findBy({'name': name});
      if (memoryModel == null) {
        return null;
      }
      return double.parse(_decrypt(memoryModel.data, _cipher));
    } catch (e){
      return null;
    }
  }

  ///Set Int [setInt]
  Future<bool> setInt(String name, int value) async {
    MemoryModel memoryModel = MemoryModel(
        name: name,
        data: value.toString(),
        type: 'int');
    return await upsertMemory(memoryModel);
  }

  ///Get Int [getInt]
  Future<int?> getInt(String name) async {
    try{
      MemoryModel? memoryModel = await _quickeyDBImpl!<MapDataSchema>()!
          .findBy({'name': name});
      if (memoryModel == null) {
        return null;
      }
      return int.parse(_decrypt(memoryModel.data, _cipher));
    } catch (e){
      return null;
    }
  }

  ///Set Map [setMap]
  Future<bool> setMap(String name, Map value) async {
    MemoryModel memoryModel = MemoryModel(
        name: name,
        data: json.encode(value),
        type: 'int');
    return await upsertMemory(memoryModel);
  }

  ///Get Map [getMap]
  Future<Map?> getMap(String name) async {
    try{
      MemoryModel? memoryModel = await _quickeyDBImpl!<MapDataSchema>()!
          .findBy({'name': name});
      if (memoryModel == null) {
        return null;
      }
      return json.decode(_decrypt(memoryModel.data, _cipher));
    } catch (e){
      return null;
    }
  }

  /// Removes entry from [Memory].
  ///
  /// Checks if a key exists in [Memory] before removing entry
  Future<bool?> deleteMemory(String name) async {
    MemoryModel? memoryModel =
        await _quickeyDBImpl!<MapDataSchema>()!.findBy({'name': name});
    if (memoryModel == null) {
      return null;
    }
    _quickeyDBImpl!<MapDataSchema>()!.delete(memoryModel);
    return true;
  }

  /// Removes all values stored on [Memory]
  ///
  /// Clears every entry
  Future<void> clear() async {
    await _quickeyDBImpl!.database!.transaction((txn) async {
      await txn.delete(MapDataSchema().tableName);
    });
  }

  /// Checks if a key exists in Active Memory
  ///
  /// returns [true] if key is found.
  ///
  /// returns [false] if value does not exist.
  Future<bool> hasMemory(String name) async {
    try{
      MemoryModel? memoryModel =
      await _quickeyDBImpl!<MapDataSchema>()!.findBy({'name': name});
      if (memoryModel == null) {
        return false;
      }
      return true;
    } catch (e){
      return false;
    }
  }

  /// Encrypts a string.
  /// [plaintext] is the string to be encrypted.
  /// [key] is the key to be used for encryption.
  String _encrypt(String plaintext, int key) {
    StringBuffer ciphertext = StringBuffer();
    for (int i = 0; i < plaintext.length; i++) {
      int c = plaintext.codeUnitAt(i);
      c = (c + key) % 65536; // Add key and wrap around
      ciphertext.write(String.fromCharCode(c));
    }
    return ciphertext.toString();
  }

  /// Decrypts a string.
  /// [ciphertext] is the string to be decrypted.
  /// [key] is the key to be used for decryption.
  String _decrypt(String ciphertext, int key) {
    StringBuffer plaintext = StringBuffer();
    for (int i = 0; i < ciphertext.length; i++) {
      int c = ciphertext.codeUnitAt(i);
      c = (c - key) % 65536; // Subtract key and wrap around
      plaintext.write(String.fromCharCode(c));
    }
    return plaintext.toString();
  }
}
