library quickeydb;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quickeydb/configs/data_access_object.dart';
import 'package:quickeydb/configs/migration.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
export 'package:sqflite_common/sql.dart' show ConflictAlgorithm;

export 'configs/converter.dart';
export 'configs/data_access_object.dart';
export 'configs/include.dart';

export 'configs/relations.dart';

part 'configs/quickey_impl.dart';

/// Insert/Update conflict resolver
// enum ConflictActions {
//   /// When a constraint violation occurs, an immediate ROLLBACK occurs,
//   /// thus ending the current transaction, and the command aborts with a
//   /// return code of SQLITE_CONSTRAINT. If no transaction is active
//   /// (other than the implied transaction that is created on every command)
//   /// then this algorithm works the same as ABORT.
//   rollback,
//
//   /// When a constraint violation occurs,no ROLLBACK is executed
//   /// so changes from prior commands within the same transaction
//   /// are preserved. This is the default behavior.
//   abort,
//
//   /// When a constraint violation occurs, the command aborts with a return
//   /// code SQLITE_CONSTRAINT. But any changes to the database that
//   /// the command made prior to encountering the constraint violation
//   /// are preserved and are not backed out.
//   fail,
//
//   /// When a constraint violation occurs, the one row that contains
//   /// the constraint violation is not inserted or changed.
//   /// But the command continues executing normally. Other rows before and
//   /// after the row that contained the constraint violation continue to be
//   /// inserted or updated normally. No error is returned.
//   ignore,
//
//   /// When a UNIQUE constraint violation occurs, the pre-existing rows that
//   /// are causing the constraint violation are removed prior to inserting
//   /// or updating the current row. Thus the insert or update always occurs.
//   /// The command continues executing normally. No error is returned.
//   /// If a NOT NULL constraint violation occurs, the NULL value is replaced
//   /// by the default value for that column. If the column has no default
//   /// value, then the ABORT algorithm is used. If a CHECK constraint
//   /// violation occurs then the IGNORE algorithm is used. When this conflict
//   /// resolution strategy deletes rows in order to satisfy a constraint,
//   /// it does not invoke delete triggers on those rows.
//   /// This behavior might change in a future release.
//   replace,
// }

abstract class QuickeyDB {
  static QuickeyDBImpl? _getInstance;

  // ConflictAlgorithm conflictReplace = ConflictAlgorithm.replace;
  // ConflictAlgorithm conflictAbort = ConflictAlgorithm.abort;
  // ConflictAlgorithm conflictFail = ConflictAlgorithm.fail;
  // ConflictAlgorithm conflictRollback = ConflictAlgorithm.rollback;

  static QuickeyDBImpl? get getInstance {
    assert(_getInstance != null,
        'No instance found, please make sure to call [initialize] before getting instance');
    return _getInstance;
  }

  static Future<QuickeyDBImpl> initialize({
    ///set a database name i.e 'tascan_db'
    required final String dbName,
    required final int dbVersion,
    required final List<DataAccessObject>? dataAccessObjects,
    final String? dbPath,
    final bool debugging = false,
    final bool importDB = false,
    final bool? persist = true,
  }) async {
    assert(dbVersion > 0);
    assert(dataAccessObjects != null && dataAccessObjects.isNotEmpty);
    assert(persist != null);


    if(Platform.isAndroid || Platform.isIOS){
      final databasePath = persist! == false
          ? inMemoryDatabasePath
          : '${dbPath ?? await getDatabasesPath()}/$dbName.db';

      if (importDB) {
        final isExists = await databaseExists(databasePath);

        if (!isExists) {
          // Should happen only the first time you launch your application
          if (debugging) {
            if (kDebugMode) {
              print('Creating new copy from "assets/$dbName.db"');
            }
          }

          // Make sure the parent directory isExists
          try {
            final dir = dbPath!.split('/');
            dir.removeLast();

            await Directory(dir.join('/')).create(recursive: true);
          } catch (_) {}

          final data = await rootBundle.load('assets/$dbName.db');

          // Convert to bytes
          final List<int> bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );

          // Write and flush the bytes written
          await File(dbPath!).writeAsBytes(bytes, flush: true);
        }
      }

      return _getInstance = QuickeyDBImpl(
        logger: debugging,
        dataAccessObjects: {
          for (var dao in dataAccessObjects!) dao.runtimeType: dao
        },
        database: await openDatabase('$dbName.db', version: dbVersion,
            onCreate: (Database? database, _) async {
          await Future.forEach(dataAccessObjects.map((dao) => dao.schema.sql),
              database!.execute);
        }, onUpgrade: (Database database, int from, int to) async {
          if (debugging) {
            if (kDebugMode) {
              print('Upgrading from $from to $to');
            }
          }
          final migration = Migration(database: database, logger: debugging);
          await Future.forEach(dataAccessObjects, migration.force);
            }, onDowngrade: (Database database, int from, int to) async {
              if (debugging) {
                if (kDebugMode) {
                  print('Downgrading from $from to $to');
                }
              }
              final migration = Migration(database: database, logger: debugging);
              await Future.forEach(dataAccessObjects, migration.force);
            }),
      );
    }
    else {
      final databasePath = persist! == false
          ? inMemoryDatabasePath
          : '${dbPath ?? await databaseFactoryFfi.getDatabasesPath()}/$dbName.db';

      if (importDB) {
        final isExists = await databaseFactoryFfi.databaseExists(databasePath);

        if (!isExists) {
          // Should happen only the first time you launch your application
          if (debugging) {
            if (kDebugMode) {
              print('Creating new copy from "assets/$dbName.db"');
            }
          }

          // Make sure the parent directory isExists
          try {
            final dir = dbPath!.split('/');
            dir.removeLast();

            await Directory(dir.join('/')).create(recursive: true);
          } catch (_) {}

          final data = await rootBundle.load('assets/$dbName.db');

          // Convert to bytes
          final List<int> bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );

          // Write and flush the bytes written
          await File(dbPath!).writeAsBytes(bytes, flush: true);
        }
      }

      return _getInstance = QuickeyDBImpl(
        logger: debugging,
        dataAccessObjects: {
          for (var dao in dataAccessObjects!) dao.runtimeType: dao
        },
        database: await databaseFactoryFfi.openDatabase(databasePath,
            options: OpenDatabaseOptions(
                version: dbVersion,
                onCreate: (Database? database, _) async {
                  await Future.forEach(
                      dataAccessObjects.map((dao) => dao.schema.sql),
                      database!.execute);
                },
                onUpgrade: (Database database, int from, int to) async {
                  if (debugging) {
                    if (kDebugMode) {
                      print('Upgrading from $from to $to');
                    }
                  }
                  final migration =
                  Migration(database: database, logger: debugging);
                  await Future.forEach(dataAccessObjects, migration.force);
                },
                onDowngrade: (Database database, int from, int to) async {
                  if (debugging) {
                    if (kDebugMode) {
                      print('Downgrading from $from to $to');
                    }
                  }
                  final migration =
                  Migration(database: database, logger: debugging);
                  await Future.forEach(dataAccessObjects, migration.force);
                })),
      );
    }

  }
}
