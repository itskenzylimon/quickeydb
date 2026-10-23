// Console output is the purpose of this source-generation example.
// ignore_for_file: avoid_print

import 'package:quickeydb/codegen/sql_dao_generator.dart';

/// Run with `dart run example/quickeydb_example.dart` from the package root.
/// This generates source only; it never creates or changes a database.
void main() {
  final generated = generateNotesDao();
  print(generated.source);
  print('Register with dataAccessObjects: ${generated.registration}');
}

SqlDaoGeneration generateNotesDao() => const SqlDaoGenerator().generate('''
CREATE TABLE notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  done INTEGER NOT NULL DEFAULT 0
);
''');
