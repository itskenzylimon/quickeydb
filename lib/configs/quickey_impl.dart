part of 'package:quickeydb/quickeydb.dart';

class QuickeyDBImpl implements QuickeyDB {
  /// `Data Access Object (DAO)`
  final Map<Type, DataAccessObject?>? dataAccessObjects;

  final ConflictAlgorithm conflictReplace = ConflictAlgorithm.replace;
  final ConflictAlgorithm conflictAbort = ConflictAlgorithm.abort;
  final ConflictAlgorithm conflictFail = ConflictAlgorithm.fail;
  final ConflictAlgorithm conflictRollback = ConflictAlgorithm.rollback;

  /// print loggers `
  final bool? logger;

  // Database instance
  final Database? database;

  T? call<T extends DataAccessObject>() => get<T>();
  T? get<T extends DataAccessObject?>() => dataAccessObjects![T] as T?;

  const QuickeyDBImpl({this.dataAccessObjects, this.database, this.logger});
}
