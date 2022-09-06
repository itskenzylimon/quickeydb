library quickeydb;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:quickeydb/configs/data_access_object.dart';
import 'package:quickeydb/configs/migration.dart';
import 'package:sqflite/sqlite_api.dart';

export 'configs/converter.dart';
export 'configs/data_access_object.dart';
export 'configs/include.dart';

export 'configs/relations.dart';

part 'configs/quickey_impl.dart';

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
    required final List<DataAccessObject >? dataAccessObjects,
    final String? dbPath,
    final bool debugging = true,
    final bool importDB = false,
    final bool? persist = false,
  }) async {
    assert(dbVersion > 0);
    assert(dataAccessObjects != null && dataAccessObjects.isNotEmpty);
    assert(persist != null);
    if (persist == true) {
      assert(
      dbName != null,
      'Name property is required while not using in-memory database',
      );
    }


    final databasePath = persist! == false
        ? sqflite.inMemoryDatabasePath
        : '${dbPath ?? await sqflite.getDatabasesPath()}/$dbName.db';

    if (importDB) {
      final isExists = await sqflite.databaseExists(databasePath);

      if (!isExists) {
        // Should happen only the first time you launch your application
        if (debugging) {
          if (kDebugMode) {
            print('Creating new copy from "assets/$dbName.db"');
          }}

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
      dataAccessObjects: { for (var dao in dataAccessObjects!) dao.runtimeType : dao },
      database: await sqflite.openDatabase(
        databasePath,
        version: dbVersion,
        onCreate: (Database? database, _) async {
          await Future.forEach(
              dataAccessObjects.map((dao) => dao.schema.sql), database!.execute);
        },
        onUpgrade: (sqflite.Database database, int from, int to) async {
          if (debugging) {
            if (kDebugMode) {
              print('Upgrading from $from to $to');
          
            }}
          final migration = Migration(database: database, logger: debugging);
          await Future.forEach(dataAccessObjects, migration.force);
        },
        onDowngrade: (sqflite.Database database, int from, int to) async {
          if (debugging) {
            if (kDebugMode) {
              print('Downgrading from $from to $to');
            }}
          final migration = Migration(database: database, logger: debugging);
          await Future.forEach(dataAccessObjects, migration.force);
        },
      ),
    );
  }

}
