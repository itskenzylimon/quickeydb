import 'package:sqflite_common/sqlite_api.dart';
import 'data_access_object.dart';

String quoteIdentifier(String name) => '"${name.replaceAll('"', '""')}"';

/// Runs within the version callback transaction. Destructive changes need an
/// explicit onUpgrade/onDowngrade callback instead of guessed column mappings.
class Migration {
  final Database? database;
  final bool? logger;
  Migration({this.database, this.logger});

  Future<void> force(DataAccessObject dao) async {
    final db = database!;
    final table = dao.schema.table!;
    final existing = await db.rawQuery(
        'SELECT sql FROM sqlite_master WHERE type = ? AND name = ?',
        ['table', table]);
    if (existing.isEmpty) {
      await db.execute(dao.schema.sql);
      return;
    }
    final oldSql = existing.first['sql'] as String;
    String normalize(String s) =>
        s.trim().replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r';$'), '');
    if (normalize(oldSql) == normalize(dao.schema.sql)) return;
    final oldColumns =
        await db.rawQuery('PRAGMA table_info(${quoteIdentifier(table)})');
    final names = oldColumns.map((r) => r['name'] as String).toList();
    final nextNames = dao.schema.columns.map((c) => c.name).toSet();
    if (names.any((n) => !nextNames.contains(n))) {
      throw StateError(
          'Removing/renaming columns requires an explicit migration for $table.');
    }
    final enabled =
        (await db.rawQuery('PRAGMA foreign_keys')).first.values.first == 1;
    if (enabled) {
      final tables = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      for (final other in tables) {
        final references = await db.rawQuery(
            'PRAGMA foreign_key_list(${quoteIdentifier(other['name'] as String)})');
        if (references.any((r) => r['table'] == table)) {
          throw StateError(
              'Referenced table $table requires an explicit foreign-key-safe migration.');
        }
      }
    }
    final sequenceTable = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE name='sqlite_sequence'");
    final sequence = sequenceTable.isEmpty
        ? <Map<String, Object?>>[]
        : await db.rawQuery(
            'SELECT seq FROM sqlite_sequence WHERE name = ?', [table]);
    final objects = await db.rawQuery(
        'SELECT sql FROM sqlite_master WHERE tbl_name = ? AND type IN (?, ?) AND sql IS NOT NULL',
        [table, 'index', 'trigger']);
    final temporary = '${table}__quickey_new';
    final replacement = dao.schema.sql.replaceFirst(
        RegExp(
            r'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?("[^"]+"|`[^`]+`|\[[^\]]+\]|\w+)',
            caseSensitive: false),
        'CREATE TABLE ${quoteIdentifier(temporary)}');
    await db.execute(replacement);
    final columns = names.map(quoteIdentifier).join(', ');
    await db.execute(
        'INSERT INTO ${quoteIdentifier(temporary)} ($columns) SELECT $columns FROM ${quoteIdentifier(table)}');
    // SQLite rejects unsafe parent replacement with FK enforcement enabled;
    // the enclosing callback transaction then rolls back without losing data.
    await db.execute('DROP TABLE ${quoteIdentifier(table)}');
    await db.execute(
        'ALTER TABLE ${quoteIdentifier(temporary)} RENAME TO ${quoteIdentifier(table)}');
    if (sequence.isNotEmpty) {
      await db.rawUpdate(
          'UPDATE sqlite_sequence SET seq = MAX(seq, ?) WHERE name = ?',
          [sequence.single['seq'], table]);
    }
    for (final object in objects) {
      await db.execute(object['sql'] as String);
    }
    final violations = await db.rawQuery('PRAGMA foreign_key_check');
    if (violations.isNotEmpty) {
      throw StateError('Migration produced foreign key violations.');
    }
  }
}
