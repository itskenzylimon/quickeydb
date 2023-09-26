import 'package:quickeydb/builder/query_method.dart';
import 'package:quickeydb/quickeydb.dart';

class MemoryModel {
  int? id;
  int? version;
  String name;

  /// base 64 representation of data type
  String data;
  String type;
  String? createdAt;
  String? updatedAt;
  String? syncAt;
  String? expiryTime;

  MemoryModel({
    this.id,
    this.version,
    required this.name,
    required this.data,
    required this.type,
    this.createdAt,
    this.updatedAt,
    this.syncAt,
    this.expiryTime,
  });

  factory MemoryModel.fromMap(Map<String?, dynamic> map) {

    return MemoryModel(
        id: map['id'],
        version: map['version'],
        name: map['name'],
        data: map['data'],
        type: map['type'],
        createdAt: map['createdAt'],
        updatedAt: map['updatedAt'],
        syncAt: map['syncAt'],
        expiryTime: map['expiryTime']);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'version': version,
      'name': name,
      'data': data,
      'type': type,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'syncAt': syncAt,
      'expiryTime': expiryTime,
    };
  }

  Map<String, dynamic> toTableMap() {
    return {
      'id': id,
      'version': version,
      'name': name,
      'data': data,
      'type': type,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'syncAt': syncAt,
      'expiryTime': expiryTime,
    };
  }

}

class MapDataSchema extends DataAccessObject<MemoryModel> {

  String tableName = 'memory_data';

  MapDataSchema()
      : super(
          '''
          CREATE TABLE memory_model (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            version INTEGER NOT NULL,
            name TEXT NOT NULL UNIQUE,
            data TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT,
            syncAt TEXT,
            expiryTime TEXT,
            type TEXT NOT NULL
          )
          ''',
          relations: [],
          converter: Converter(
            encode: (memory) => MemoryModel.fromMap(memory),
            decode: (memory) => memory!.toMap(),
            decodeTable: (memory) => memory!.toTableMap(),
          ),
        );

  /// Here we have a subQuery for emailQuery *
  QueryMethod<MemoryModel?>? mapDataQueryName(
      QueryMethod<MemoryModel?>? queryMethod, String name) {
    return queryMethod?.where({'name': name});
  }

  QueryMethod<MemoryModel?>? mapDataQueryType(
      QueryMethod<MemoryModel?>? queryMethod, String name) {
    return queryMethod?.where({'name': name});
  }

  QueryMethod<MemoryModel?>? mapDataQueryCreatedAt(
      QueryMethod<MemoryModel?>? queryMethod, String name) {
    return queryMethod?.where({'name': name});
  }

  QueryMethod<MemoryModel?>? mapDataQueryUpdatedAt(
      QueryMethod<MemoryModel?>? queryMethod, String name) {
    return queryMethod?.where({'name': name});
  }

  QueryMethod<MemoryModel?>? mapDataQueryID(
      QueryMethod<MemoryModel?>? queryMethod, String name) {
    return queryMethod?.where({'name': name});
  }
}
