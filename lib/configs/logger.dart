import 'package:flutter/foundation.dart';
import 'package:sqflite_common/src/sql_builder.dart';

class Logger {
  static final _stopwatch = Stopwatch();

  Logger._start() {
    _stopwatch
      ..reset()
      ..start();
  }

  Logger.query(Type type, Future future, SqlBuilder builder) {
    Logger._start();
    future.whenComplete(() =>
        _log('${_elapsed(type)}\x1B[37m -- ${builder.sql} '
            '[${builder.arguments!.join(', ')}] --- \x1B[0m')
    );
  }

  Logger.insert(Type type, Future future, SqlBuilder builder) {
    Logger._start();
    future.whenComplete(() =>
        _log('${_elapsed(type)}\x1B[32m -- ${builder.sql} '
            '[${builder.arguments!.join(', ')}] --- \x1B[0m')
    );
  }

  Logger.update(Type type, Future future, SqlBuilder builder) {
    Logger._start();
    future.whenComplete(() =>
        _log('${_elapsed(type)}\x1B[33m -- ${builder.sql} '
            '[${builder.arguments!.join(', ')}] --- \x1B[0m')
    );
  }

  Logger.destroy(Type type, Future future, SqlBuilder builder) {
    Logger._start();
    future.whenComplete(() =>
        _log('${_elapsed(type)}\x1B[31m -- ${builder.sql} '
            '[${builder.arguments!.join(', ')}] --- \x1B[0m')
    );
  }

  Logger.sql(Future future, String sql) {
    Logger._start();
    future.whenComplete(() =>
        _log('\x1B[36m -- ${sql.replaceAll('null ', '')} --- \x1B[0m')
    );
  }

  _elapsed(dynamic type) {
    return '\x1B[30m$type (${_stopwatch.elapsed.inMilliseconds} ms)'
        ' \x1B[0m';
  }

  _log(body) {
    if (kDebugMode) {
      return debugPrint('\x1B[35m$body\x1B[0m');
    }
  }

}
