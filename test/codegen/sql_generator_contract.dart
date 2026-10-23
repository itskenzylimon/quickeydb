// Portable contract checks: dart --packages=.dart_tool/package_config.json
// test/codegen/sql_generator_contract.dart (no Flutter/native hooks required).
import 'package:quickeydb/codegen/sql_dao_generator.dart';

const input = '''CREATE TABLE projects (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL
);
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER,
  title TEXT NOT NULL,
  done INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (project_id) REFERENCES projects (id)
);''';

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Map<String, void Function()> generatorContractCases() {
  const generator = SqlDaoGenerator();
  return {
    'multiple tables, metadata, unique classes and registration': () {
      final output = generator.generate(input);
      _check(
          output.tables.map((t) => t.tableName).join(',') == 'projects,tasks',
          'Table order changed');
      _check(output.registration == '[ProjectsDao(), TasksDao()]',
          'Invalid registration');
      _check(output.source.contains('Converter<Map<String?, dynamic>?>'),
          'Missing converter');
      _check(output.tables.last.schema.foreignKeys.length == 1,
          'Foreign key lost');
      var immutable = false;
      try {
        output.tables.clear();
      } on UnsupportedError {
        immutable = true;
      }
      _check(immutable, 'Results must be immutable');
    },
    'comments, escaped quotes, punctuation and Dart interpolation': () {
      final output = generator.generate(r'''-- heading;
CREATE TABLE IF NOT EXISTS "draft_notes" (
 id INTEGER PRIMARY KEY, body TEXT DEFAULT 'it''s $safe; /* text */ (a,b)'
); /* trailing ; */''');
      _check(output.tables.single.className == 'DraftNotesDao',
          'Incorrect class name');
      _check(
          output.tables.single.sql.contains(r"'it''s $safe; /* text */ (a,b)'"),
          'SQL string changed');
      _check(output.source.contains(r'\$safe'),
          'Dart interpolation must be escaped');
      _check(!output.source.contains('-- heading'), 'Comment not removed');
    },
    'constraint words inside defaults do not change metadata': () {
      final table = generator
          .generate(
              "CREATE TABLE labels (id INTEGER PRIMARY KEY, value TEXT DEFAULT 'PRIMARY KEY NOT NULL UNIQUE FOREIGN KEY (id) REFERENCES other (id)')")
          .tables
          .single;
      _check(table.schema.primaryKey == 'id', 'Default replaced primary key');
      _check(table.schema.foreignKeys.isEmpty, 'Default created a foreign key');
      _check(
          table.schema.columns.last.isNullable, 'Default changed nullability');
      _check(!table.schema.columns.last.isUnique, 'Default changed uniqueness');
    },
    'single table and optional final semicolon': () {
      final result = generator.generate(
          'create table [things] (id integer primary key, value TEXT)');
      _check(result.registration == '[ThingsDao()]', 'Quoted name failed');
      _check(result.tables.single.schema.columns.length == 2,
          'Column metadata lost');
      final mixed = generator
          .generate('CREATE TABLE casing (id INTEGER, PRIMARY KEY (ID))');
      _check(mixed.tables.single.schema.primaryKey == 'id',
          'Key case must use the real column name');
    },
    for (final sql in [
      '',
      '-- comment only',
      'SELECT 1;',
      'CREATE TABLE x (id INTEGER PRIMARY KEY); DELETE FROM x;',
      'CREATE TABLE x (id INTEGER PRIMARY KEY); CREATE INDEX x_id ON x(id);',
      'CREATE TABLE x (id INTEGER);',
      "CREATE TABLE x (body TEXT DEFAULT 'PRIMARY KEY');",
      'CREATE TABLE x (a INTEGER PRIMARY KEY, b INTEGER PRIMARY KEY);',
      'CREATE TABLE x (body TEXT, PRIMARY KEY (missing));',
      'CREATE TABLE x (a INTEGER, b INTEGER, PRIMARY KEY(a,b));',
      'CREATE TABLE x (id INTEGER PRIMARY KEY',
      "CREATE TABLE x (id INTEGER PRIMARY KEY, body TEXT DEFAULT 'oops);",
      'CREATE TABLE x (id INTEGER PRIMARY KEY); /* unfinished',
      'CREATE TABLE x (id INTEGER PRIMARY KEY) STRICT;',
      'CREATE TABLE "not a name" (id INTEGER PRIMARY KEY);',
      'CREATE TABLE sqlite_test (id INTEGER PRIMARY KEY);',
      'CREATE TABLE x (id INTEGER PRIMARY KEY); CREATE TABLE X (id INTEGER PRIMARY KEY);',
      'CREATE TABLE a_b (id INTEGER PRIMARY KEY); CREATE TABLE a__b (id INTEGER PRIMARY KEY);',
    ])
      'reject unsupported/malformed input: $sql': () {
        var rejected = false;
        try {
          generator.generate(sql);
        } on FormatException {
          rejected = true;
        }
        _check(rejected, 'Expected FormatException for: $sql');
      },
  };
}

void main() {
  final cases = generatorContractCases();
  for (final entry in cases.entries) {
    entry.value();
  }
  // ignore: avoid_print
  print('${cases.length} SQL-to-DAO contract checks passed.');
}
