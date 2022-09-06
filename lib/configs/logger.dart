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
        _log('\x1B[32m --- ${_elapsed(type)} ${builder.sql} '
            '[${builder.arguments!.join(', ')}] --- \x1B[0m')
    );
  }

  Logger.insert(Type type, Future future, SqlBuilder builder) {
    Logger._start();
    future.whenComplete(() =>
        _log('\x1B[33m --- ${_elapsed(type)} ${builder.sql} '
            '[${builder.arguments!.join(', ')}] --- \x1B[0m')
    );
  }

  Logger.update(Type type, Future future, SqlBuilder builder) {
    Logger._start();
    future.whenComplete(() =>
        _log('\x1B[37m --- ${_elapsed(type)} ${builder.sql} '
            '[${builder.arguments!.join(', ')}] --- \x1B[0m')
    );
  }

  Logger.destroy(Type type, Future future, SqlBuilder builder) {
    Logger._start();
    future.whenComplete(() =>
        _log('\x1B[31m --- ${_elapsed(type)} ${builder.sql} '
            '[${builder.arguments!.join(', ')}] --- \x1B[0m')
    );
  }

  Logger.sql(Future future, String sql) {
    Logger._start();
    future.whenComplete(() =>
        _log('\x1B[36m --- $sql --- \x1B[0m')
    );
  }

  _elapsed(dynamic type) {
    return _log('\x1B[34m --- $type (${_stopwatch.elapsed.inMilliseconds}ms)'
        ' --- \x1B[0m');
  }

  _log(body) {
    if (kDebugMode) {
      return debugPrint('\x1B[35m$body\x1B[0m');
    }
  }

}
