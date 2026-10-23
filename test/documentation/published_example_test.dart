@TestOn('vm')
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../example/quickeydb_example.dart' as example;

void main() {
  test('published example generates a ready notes DAO and stays in sync', () {
    final result = example.generateNotesDao();
    expect(result.registration, '[NotesDao()]');
    expect(result.source, contains('class NotesDao extends DataAccessObject'));
    final source = File('example/quickeydb_example.dart').readAsStringSync();
    expect(
      File('example/example.md').readAsStringSync(),
      contains(source.trim()),
    );
  });
}
