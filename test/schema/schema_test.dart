import 'package:flutter_test/flutter_test.dart';
import 'package:quickeydb/types/schema.dart';

void main() {
  test('schema handles case, quoted names, parentheses and nullable metadata',
      () {
    final schema = Schema(
        'create table if not exists "things" (id integer primary key, name text not null, note text default \'a,b\')');
    expect(schema.table, 'things');
    expect(schema.primaryKey, 'id');
    expect(schema.columns[1].isNullable, isFalse);
    expect(schema.columns[2].isNullable, isTrue);
    expect(schema, Schema(schema.sql));
    expect(
        () => Schema(
            'CREATE TABLE pairs (a INTEGER, b INTEGER, PRIMARY KEY (a,b))'),
        throwsFormatException);
  });
}
