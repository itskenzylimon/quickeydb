import 'package:flutter/foundation.dart';

/// A completed DAO statement. Parameter values and exception messages are omitted.
class QueryLogEvent {
  const QueryLogEvent(
      {required this.operation,
      required this.table,
      required this.elapsed,
      required this.timestamp,
      required this.succeeded,
      required this.parameterCount,
      this.sql,
      this.rowCount,
      this.errorType});
  final String operation, table;
  final Duration elapsed;
  final DateTime timestamp;
  final bool succeeded;
  final int parameterCount;
  final int? rowCount;
  final String? sql, errorType;
  @override
  String toString() => '${timestamp.toIso8601String()} $operation $table '
      '${succeeded ? "OK" : "FAILED ($errorType)"} '
      '${elapsed.inMicroseconds / 1000} ms · ${rowCount ?? "?"} rows · '
      '$parameterCount bound parameters${sql == null ? "" : "\n$sql"}';
}

/// Opt-in development diagnostics. Always silent in profile and release builds.
/// SQL is the parameterized statement, never an interpolation of bound values.
/// Trusted SQL expressions can still contain literals: do not embed secrets.
/// Covers DAO reads/writes, not direct database/transaction or migration SQL.
class QueryLogging {
  QueryLogging({this.enabled = true, this.includeSql = false, this.onQuery});
  bool enabled;
  bool includeSql;
  final void Function(QueryLogEvent event)? onQuery;
  final _listeners = <void Function(QueryLogEvent)>[];
  bool get isEnabled => kDebugMode && enabled;
  void addListener(void Function(QueryLogEvent) listener) =>
      _listeners.add(listener);
  void removeListener(void Function(QueryLogEvent) listener) =>
      _listeners.remove(listener);

  /// Observer failures must never change the outcome of a database operation.
  void emit(QueryLogEvent event) {
    if (!isEnabled) return;
    for (final callback in [if (onQuery != null) onQuery!, ..._listeners]) {
      try {
        callback(event);
      } catch (_) {/* Diagnostics are best effort. */}
    }
  }
}
