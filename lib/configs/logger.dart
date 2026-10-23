import 'package:flutter/foundation.dart';
import 'sql_builder.dart';

/// Optional SQL diagnostics. Bound values are deliberately never logged.
class Logger {
  static void _observe(Type? type, Future future, String sql) {
    final watch = Stopwatch()..start();
    // Handle both paths on this observer without introducing unhandled futures.
    future.then<void>((_) {
      if (kDebugMode) {
        debugPrint('$type (${watch.elapsedMilliseconds} ms) $sql');
      }
    }, onError: (Object _, StackTrace __) {
      if (kDebugMode) {
        debugPrint('$type (${watch.elapsedMilliseconds} ms) SQL failed');
      }
    });
  }

  Logger.query(Type type, Future future, SqlBuilder builder) {
    _observe(type, future, builder.sql);
  }
  Logger.insert(Type type, Future future, SqlBuilder builder) {
    _observe(type, future, builder.sql);
  }
  Logger.update(Type type, Future future, SqlBuilder builder) {
    _observe(type, future, builder.sql);
  }
  Logger.destroy(Type type, Future future, SqlBuilder builder) {
    _observe(type, future, builder.sql);
  }
  Logger.sql(Future future, String sql) {
    _observe(null, future, sql);
  }
}
