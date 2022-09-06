import 'dart:async';
import 'package:sqflite/sqlite_api.dart';
import 'package:quickeydb/quickeydb.dart';
import '../types/schema.dart';
import 'logger.dart';

class Migration {
  final Database? database;
  final bool? logger;

  Migration({final this.database, final this.logger});

  Future force(DataAccessObject dataAccessObject) async {
    final newSchema = dataAccessObject.schema;
    final oldSchema = Schema((await database!.rawQuery(
            "SELECT sql FROM sqlite_master WHERE name = '${dataAccessObject.schema.table}'"))
        .first
        .values
        .first as String);

    if (newSchema.sql != oldSchema.sql) {
      final oldColumns =
          oldSchema.columns.map((column) => column.name).toList();
      final newColumns =
          newSchema.columns.map((column) => column.name).toList();

      /// Remove any new column not exists in previous sql
      oldColumns.removeWhere((oldColumn) => !newColumns.contains(oldColumn));

      await Future.forEach([
        /// Disable foreign key constraint check
        'PRAGMA foreign_keys=OFF',

        /// Start a transaction
        'BEGIN TRANSACTION',

        /// Suffex table with `_old`
        'ALTER TABLE ${oldSchema.table} RENAME TO ${oldSchema.table}_old',

        /// Creating the new table on its new format
        newSchema.sql,

        /// Populating the table with the data
        'INSERT INTO ${newSchema.table} (${oldColumns.join(', ')}) SELECT ${oldColumns.join(', ')} FROM ${oldSchema.table}_old',

        /// Drop old table
        'DROP TABLE ${oldSchema.table}_old',

        /// Commit the transaction
        'COMMIT',

        /// Enable foreign key constraint check
        'PRAGMA foreign_keys=ON',
      ], (dynamic sql) async {
        final completer = Completer()..complete(database!.execute(sql));

        if (logger!) Logger.sql(completer.future, sql);
        await completer.future;
      });
    }
  }
}
