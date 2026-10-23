part of 'package:quickeydb/quickeydb.dart';

class QuickeyDBImpl implements QuickeyDB {
  final Map<Type, DataAccessObject?>? dataAccessObjects;
  final bool? logger;
  final QueryLogging? queryLogging;
  final Database? database;
  final ValueEncryption? valueEncryption;
  final ConflictAlgorithm conflictAlgorithm;
  final ConflictAlgorithm conflictReplace = ConflictAlgorithm.replace;
  final ConflictAlgorithm conflictAbort = ConflictAlgorithm.abort;
  final ConflictAlgorithm conflictFail = ConflictAlgorithm.fail;
  final ConflictAlgorithm conflictRollback = ConflictAlgorithm.rollback;
  static final _executorKey = Object();

  const QuickeyDBImpl(
      {this.dataAccessObjects,
      this.database,
      this.logger,
      this.queryLogging,
      this.valueEncryption,
      this.conflictAlgorithm = ConflictAlgorithm.replace});

  T? call<T extends DataAccessObject>() => get<T>();
  T? get<T extends DataAccessObject?>() => dataAccessObjects?[T] as T?;
  bool get isInTransaction => Zone.current[_executorKey] != null;
  DatabaseExecutor get executor {
    if (database?.isOpen != true) throw StateError('Database is closed.');
    return Zone.current[_executorKey] as DatabaseExecutor? ?? database!;
  }

  /// All DAO calls awaited inside this callback use the same transaction.
  Future<R> transaction<R>(Future<R> Function() action) async {
    if (Zone.current[_executorKey] != null) return action();
    return database!.transaction(
        (txn) => runZoned(action, zoneValues: {_executorKey: txn}));
  }

  Future<void> close() async {
    await database?.close();
    if (identical(QuickeyDB._getInstance, this)) QuickeyDB._getInstance = null;
  }
}
