import 'package:flutter_test/flutter_test.dart';
import 'package:quickeydb/configs/sql_builder.dart';
import 'package:quickeydb/builder/quickey_builder.dart';
import 'package:quickeydb/configs/logger.dart';

void main() {
  test('SQL diagnostics redact arguments and accept no arguments', () {
    final query =
        SqlBuilder.query('rows', where: 'name = ?', whereArgs: ['sensitive']);
    expect(query.arguments, ['sensitive']);
    expect(query.fullSql, isNot(contains('sensitive')));
    expect(SqlBuilder.query('rows').fullSql, contains('0 bound arguments'));
  });
  test('query builder validates HAVING without GROUP BY', () {
    expect(() => SqlBuilder.query('rows', having: 'COUNT(*) > 1'),
        throwsArgumentError);
  });
  test('logger observes failures without producing a second failed future',
      () async {
    final future = Future<int>.error(StateError('expected'));
    Logger.query(int, future, SqlBuilder.query('rows'));
    await expectLater(future, throwsStateError);
    await Future<void>.delayed(Duration.zero);
  });
}
