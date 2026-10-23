import 'package:flutter_test/flutter_test.dart';
import 'package:quickeydb/types/schema.dart';

void main() {
  test('unsupported schema definitions fail descriptively', () {
    expect(() => Schema('SELECT 1'), throwsFormatException);
    expect(
        () => Schema(
            'CREATE TABLE pair (a INTEGER, b INTEGER, PRIMARY KEY (a,b))'),
        throwsFormatException);
  });
}
