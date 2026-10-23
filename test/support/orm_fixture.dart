import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickeydb/quickeydb.dart';
export 'dart:io';
export 'dart:typed_data';
export 'package:flutter/services.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:quickeydb/quickeydb.dart';
export 'package:quickeydb/types/schema.dart';

typedef Row = Map<String?, dynamic>;
Converter<Row?> get rowsConverter => Converter<Row?>(
    encode: (r) => r,
    decode: (r) => Map<String?, dynamic>.from(r!),
    decodeTable: (r) => Map<String?, dynamic>.from(r!));

class Rows extends DataAccessObject<Row> {
  Rows({String? sql, Set<String> encrypted = const {}})
      : super(
            sql ??
                '''
CREATE TABLE rows (
 id INTEGER NOT NULL PRIMARY KEY,
 name TEXT NOT NULL UNIQUE,
 score REAL DEFAULT 0,
 note TEXT
)
''',
            converter: rowsConverter,
            encryptedColumns: encrypted);
}

class Parents extends DataAccessObject<Row> {
  Parents()
      : super('CREATE TABLE parents (id INTEGER PRIMARY KEY, name TEXT)',
            converter: rowsConverter,
            relations: [const HasMany<Children>(), const HasOne<Profiles>()]);
}

class Children extends DataAccessObject<Row> {
  Children()
      : super(
            'CREATE TABLE children (id INTEGER PRIMARY KEY, parent_id INTEGER, name TEXT, FOREIGN KEY (parent_id) REFERENCES parents (id))',
            converter: rowsConverter,
            relations: [const BelongsTo<Parents>()]);
}

class Profiles extends DataAccessObject<Row> {
  Profiles()
      : super(
            'CREATE TABLE profiles (id INTEGER PRIMARY KEY, parent_id INTEGER, note TEXT, FOREIGN KEY (parent_id) REFERENCES parents (id))',
            converter: rowsConverter);
}

class OrmFixture {
  late Directory directory;
  late QuickeyDBImpl db;
  Future<QuickeyDBImpl> open(
      {List<DataAccessObject>? daos,
      int version = 1,
      bool persist = false,
      ValueEncryption? cipher,
      bool privateStorage = false,
      List<int>? databaseKey,
      bool foreignKeys = false}) async {
    return db = await QuickeyDB.initialize(
        dbName: 'test',
        dbVersion: version,
        dbPath: directory.path,
        dataAccessObjects: daos ?? [Rows()],
        persist: persist,
        valueEncryption: cipher,
        privateStorage: privateStorage,
        databaseKey: databaseKey,
        foreignKeys: foreignKeys,
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  void install() {
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('quickey_test_');
    });
    tearDown(() async {
      await QuickeyDB.getInstance?.close();
      await directory.delete(recursive: true);
    });
  }
}
