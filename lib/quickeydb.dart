/// SQLite DAOs, scoped queries, relations and optional value encryption.
///
/// Register tables with [QuickeyDB.initialize], then use [DataAccessObject.query].
library quickeydb;

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';
import 'platform/storage_web.dart'
    if (dart.library.io) 'platform/storage_io.dart' as storage;
import 'configs/data_access_object.dart';
import 'configs/migration.dart';
import 'configs/query_logging.dart';
import 'security/value_encryption.dart';

export 'package:sqflite_common/sql.dart' show ConflictAlgorithm;
export 'configs/converter.dart';
export 'configs/query_logging.dart';
export 'configs/data_access_object.dart';
export 'configs/include.dart';
export 'configs/relations.dart';
export 'security/value_encryption.dart';
export 'codegen/sql_dao_generator.dart';
export 'memory/memory.dart';
part 'configs/quickey_impl.dart';

/// Platform-selected SQLite database. Existing paths and conflict defaults are preserved.
abstract class QuickeyDB {
  static QuickeyDBImpl? _getInstance;
  static Future<QuickeyDBImpl>? _opening;
  static QuickeyDBImpl? get getInstance => _getInstance;

  /// Uses the same resolved native path or browser namespace as initialize.
  static Future<bool> databaseExists(
      {required String dbName,
      String? dbPath,
      bool privateStorage = false,
      DatabaseFactory? factory}) async {
    final backend = factory ?? storage.defaultDatabaseFactory();
    final base = dbPath ??
        (privateStorage
            ? await storage.supportDirectory()
            : await backend.getDatabasesPath());
    final directory = privateStorage ? p.join(base, '.quickeydb') : base;
    return backend.databaseExists(p.join(directory, '$dbName.db'));
  }

  static Future<QuickeyDBImpl> initialize({
    required String dbName,
    required int dbVersion,
    required List<DataAccessObject>? dataAccessObjects,
    String? dbPath,
    bool debugging = false,
    QueryLogging? queryLogging,
    bool importDB = false,
    bool? persist = true,
    bool privateStorage = false,
    bool foreignKeys = false,
    DatabaseFactory? factory,
    List<int>? databaseKey,
    ValueEncryption? valueEncryption,
    ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace,
    Future<void> Function(Database db)? onConfigure,
    Future<void> Function(Database db, int from, int to)? onUpgrade,
    Future<void> Function(Database db, int from, int to)? onDowngrade,
  }) async {
    if (_opening != null) {
      throw StateError('Database initialization in progress.');
    }
    if (_getInstance?.database?.isOpen == true) {
      throw StateError(
          'Close the current database before initializing another.');
    }
    if (dbName.isEmpty ||
        p.basename(dbName) != dbName ||
        dbVersion < 1 ||
        dataAccessObjects == null ||
        dataAccessObjects.isEmpty ||
        persist == null) {
      throw ArgumentError('Supply a database name, positive version and DAOs.');
    }
    if (dataAccessObjects.any((d) => d.schema.table == '__quickey_security')) {
      throw ArgumentError('The __quickey_security table name is reserved.');
    }
    if (dataAccessObjects.map((d) => d.runtimeType).toSet().length !=
        dataAccessObjects.length) {
      throw ArgumentError('Duplicate DAO types.');
    }
    if (databaseKey != null &&
        (databaseKey.length != 32 ||
            databaseKey.any((v) => v < 0 || v > 255))) {
      throw ArgumentError('databaseKey requires 32 bytes.');
    }
    if (importDB && (!persist || databaseKey != null)) {
      throw ArgumentError(
          'Asset import requires persistent plaintext storage.');
    }
    Future<QuickeyDBImpl> open() async {
      final backend = factory ?? storage.defaultDatabaseFactory();
      final baseDirectory = !persist
          ? (dbPath ?? '.')
          : dbPath ??
              (privateStorage
                  ? await storage.supportDirectory()
                  : await backend.getDatabasesPath());
      final directory =
          privateStorage ? p.join(baseDirectory, '.quickeydb') : baseDirectory;
      final path =
          persist ? p.join(directory, '$dbName.db') : inMemoryDatabasePath;
      if (persist) {
        await storage.prepareDirectory(directory, private: privateStorage);
      }
      if (importDB && storage.isBrowser) {
        throw UnsupportedError('Asset import is currently native-only.');
      }
      if (importDB && !await backend.databaseExists(path)) {
        final data = await rootBundle.load('assets/$dbName.db');
        await storage.writeDatabase(path,
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      }
      final db = await backend.openDatabase(path,
          options: OpenDatabaseOptions(
            version: dbVersion,
            singleInstance: storage.isBrowser,
            onConfigure: (db) async {
              if (databaseKey != null) {
                final cipher = await db.rawQuery('PRAGMA cipher_version');
                if (cipher.isEmpty ||
                    cipher.first.values
                        .every((v) => v == null || v.toString().isEmpty)) {
                  throw UnsupportedError(
                      'databaseKey requires a SQLCipher-capable factory.');
                }
                final hex = databaseKey
                    .map((v) => v.toRadixString(16).padLeft(2, '0'))
                    .join();
                await db.execute('PRAGMA key = "x\'$hex\'"');
              }
              final metadata = await db.rawQuery(
                  "SELECT name FROM sqlite_master WHERE type='table' AND name='__quickey_security'");
              if (metadata.isNotEmpty) {
                final check = await db.query('__quickey_security',
                    where: 'id = ?', whereArgs: [1]);
                if (check.isNotEmpty) {
                  if (valueEncryption == null) {
                    throw StateError('This database requires valueEncryption.');
                  }
                  if (!valueEncryption.isEncrypted(check.single['verifier'])) {
                    throw StateError('Corrupt encryption key verifier.');
                  }
                  if (await valueEncryption.decrypt(check.single['verifier'],
                          context: 'quickeydb:key-check:v1') !=
                      'quickeydb-key-v1') {
                    throw StateError('Invalid encryption key.');
                  }
                }
              }
              if (valueEncryption != null) {
                await db.execute('PRAGMA secure_delete = ON');
              }
              // Configure before version-callback transactions, never inside them.
              await db.execute(
                  'PRAGMA foreign_keys = ${foreignKeys ? 'ON' : 'OFF'}');
              await onConfigure?.call(db);
            },
            onCreate: (db, _) async {
              for (final dao in dataAccessObjects) {
                await db.execute(dao.schema.sql);
              }
            },
            onUpgrade: onUpgrade ??
                (db, from, to) async {
                  final migration = Migration(database: db, logger: debugging);
                  for (final dao in dataAccessObjects) {
                    await migration.force(dao);
                  }
                },
            onDowngrade: onDowngrade ??
                (db, from, to) async {
                  throw StateError(
                      'Supply onDowngrade to explicitly migrate backwards.');
                },
          ));
      try {
        final hasMeta = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='__quickey_security'");
        if (hasMeta.isNotEmpty) {
          final check = await db
              .query('__quickey_security', where: 'id = ?', whereArgs: [1]);
          if (check.isNotEmpty) {
            if (valueEncryption == null) {
              throw StateError('This database requires valueEncryption.');
            }
            if (!valueEncryption.isEncrypted(check.single['verifier'])) {
              throw StateError('Corrupt encryption key verifier.');
            }
            final verified = await valueEncryption.decrypt(
                check.single['verifier'],
                context: 'quickeydb:key-check:v1');
            if (verified != 'quickeydb-key-v1') {
              throw StateError('Invalid encryption key.');
            }
          }
        }
        if (valueEncryption != null && hasMeta.isEmpty) {
          // Check existing protected data before installing the key marker.
          for (final dao in dataAccessObjects) {
            for (final column in dao.encryptedColumns) {
              final records =
                  await db.query(dao.schema.table!, columns: [column]);
              for (final record in records) {
                if (valueEncryption.isEncrypted(record[column])) {
                  await valueEncryption.decrypt(record[column],
                      context: '${dao.schema.table}.$column');
                }
              }
            }
          }
          await db.transaction((txn) async {
            await txn.execute(
                'CREATE TABLE __quickey_security (id INTEGER PRIMARY KEY, verifier TEXT NOT NULL)');
            await txn.insert('__quickey_security', {
              'id': 1,
              'verifier': await valueEncryption.encrypt('quickeydb-key-v1',
                  context: 'quickeydb:key-check:v1')
            });
          });
        }
      } catch (_) {
        await db.close();
        rethrow;
      }
      if (privateStorage && persist) {
        try {
          await storage.restrictDatabase(path);
        } catch (_) {
          await db.close();
          rethrow;
        }
      }
      return _getInstance = QuickeyDBImpl(
          database: db,
          logger: debugging,
          queryLogging: queryLogging,
          valueEncryption: valueEncryption,
          conflictAlgorithm: conflictAlgorithm,
          dataAccessObjects: {
            for (final dao in dataAccessObjects) dao.runtimeType: dao
          });
    }

    _opening = open();
    try {
      return await _opening!;
    } finally {
      _opening = null;
    }
  }
}
