import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quickeydb/configs/data_access_object.dart';
import 'package:quickeydb/configs/migration.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

export 'configs/converter.dart';
export 'configs/data_access_object.dart';
export 'configs/include.dart';

export 'configs/relations.dart';

part 'configs/quickey_web_impl.dart';

abstract class QuickeyDB {
  static QuickeyDBImpl? _getInstance;

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
    final bool debugging = true,
    final bool importDB = false,
    final bool? persist = false,
  }) async {
    assert(dbVersion > 0);
    assert(dataAccessObjects != null && dataAccessObjects.isNotEmpty);
    assert(persist != null);

    final databasePath = persist! == false
        ? inMemoryDatabasePath
        : '${dbPath ?? await databaseFactoryFfiWeb.getDatabasesPath()}/$dbName.db';

    return _getInstance = QuickeyDBImpl(
      logger: debugging,
      dataAccessObjects: {
        for (var dao in dataAccessObjects!) dao.runtimeType: dao
      },
      database: await databaseFactoryFfiWeb.openDatabase(databasePath,
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
