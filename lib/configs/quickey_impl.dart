part of 'package:quickeydb/quickeydb.dart';

class QuickeyDBImpl implements QuickeyDB {
  /// `Data Access Object (DAO)`
  final Map<Type, DataAccessObject?>? dataAccessObjects;

  /// print loggers `
  final bool? logger;

  // Database instance
  final Database? database;

  T? call<T extends DataAccessObject>() => get<T>();
  T? get<T extends DataAccessObject?>() => dataAccessObjects![T] as T?;

  const QuickeyDBImpl({this.dataAccessObjects, this.database, this.logger});
}
