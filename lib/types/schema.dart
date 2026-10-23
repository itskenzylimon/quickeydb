import 'package:collection/collection.dart';
import 'column.dart';
import 'foreign_key.dart';
import 'reference.dart';

/// Metadata for ordinary single-key CREATE TABLE statements.
/// Unsupported composite keys fail rather than silently corrupt migration data.
class Schema {
  final String sql;
  final String? table;
  final List<Column> columns;
  final String? primaryKey;
  final List<ForeignKey> foreignKeys;
  factory Schema(String sql) {
    final match = RegExp(
            r'^\s*CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?("[^"]+"|`[^`]+`|\[[^\]]+\]|\w+)\s*\(',
            caseSensitive: false)
        .firstMatch(sql);
    if (match == null) {
      throw const FormatException('Unsupported CREATE TABLE statement.');
    }
    String name(String s) => s.replaceAll(RegExp(r'^["`\[]|["`\]]$'), '');
    final body = sql.substring(match.end, sql.lastIndexOf(')'));
    final definitions = <String>[];
    var depth = 0, start = 0;
    String? quote;
    for (var i = 0; i < body.length; i++) {
      final c = body[i];
      if (quote != null) {
        if (c == quote) {
          if (i + 1 < body.length && body[i + 1] == quote) {
            i++;
          } else {
            quote = null;
          }
        }
      } else if (c == "'" || c == '"' || c == '`') {
        quote = c;
      } else if (c == '(') {
        depth++;
      } else if (c == ')') {
        depth--;
      } else if (c == ',' && depth == 0) {
        definitions.add(body.substring(start, i).trim());
        start = i + 1;
      }
    }
    definitions.add(body.substring(start).trim());
    final columns = <Column>[];
    final fks = <ForeignKey>[];
    String? primary;
    for (final definition in definitions) {
      // SQL keywords in a string default are data, not column constraints.
      final structure = definition.replaceAll(RegExp(r"'(?:''|[^'])*'"), "''");
      final fk = RegExp(
              r'FOREIGN\s+KEY\s*\(([^)]+)\)\s+REFERENCES\s+(\w+)\s*\(([^)]+)\)',
              caseSensitive: false)
          .firstMatch(structure);
      if (fk != null) {
        if (fk[1]!.contains(',') || fk[3]!.contains(',')) {
          throw const FormatException(
              'Composite foreign keys need explicit metadata.');
        }
        fks.add(ForeignKey(
            parent: name(fk[1]!.trim()),
            reference: Reference(
                table: name(fk[2]!), primaryKey: name(fk[3]!.trim()))));
        continue;
      }
      final tablePk = RegExp(
              r'^(?:CONSTRAINT\s+\w+\s+)?PRIMARY\s+KEY\s*\(([^)]+)\)',
              caseSensitive: false)
          .firstMatch(structure);
      if (tablePk != null) {
        if (tablePk[1]!.contains(',')) {
          throw const FormatException(
              'Composite primary keys are unsupported.');
        }
        if (primary != null) {
          throw const FormatException('Multiple primary keys are unsupported.');
        }
        primary = name(tablePk[1]!.trim());
        continue;
      }
      if (RegExp(r'^(CONSTRAINT|UNIQUE|CHECK)\b', caseSensitive: false)
          .hasMatch(definition)) {
        continue;
      }
      final col = RegExp(r'^("[^"]+"|`[^`]+`|\[[^\]]+\]|\w+)\s+')
          .firstMatch(definition);
      if (col == null) throw FormatException('Unsupported column: $definition');
      final colName = name(col[1]!);
      final constraints = structure.substring(col.end);
      if (RegExp(r'\bPRIMARY\s+KEY\b', caseSensitive: false)
          .hasMatch(constraints)) {
        if (primary != null) {
          throw const FormatException('Multiple primary keys are unsupported.');
        }
        primary = colName;
      }
      columns.add(Column(
          name: colName,
          isNullable: !RegExp(r'\bNOT\s+NULL\b', caseSensitive: false)
              .hasMatch(constraints),
          isUnique:
              RegExp(r'\bUNIQUE\b', caseSensitive: false).hasMatch(constraints),
          defaultValue: RegExp(
                  r'\bDEFAULT\s+(.+?)(?:\s+(?:NOT NULL|UNIQUE|CHECK|REFERENCES)\b|$)',
                  caseSensitive: false)
              .firstMatch(definition)?[1]));
    }
    if (primary != null) {
      final key = columns.firstWhereOrNull(
          (c) => c.name?.toLowerCase() == primary?.toLowerCase());
      if (key == null) {
        throw const FormatException(
            'Primary key must name an existing column.');
      }
      primary = key.name;
    }
    return Schema._(sql.trim(), name(match[1]!), List.unmodifiable(columns),
        primary, List.unmodifiable(fks));
  }
  const Schema._(
      this.sql, this.table, this.columns, this.primaryKey, this.foreignKeys);
  @override
  bool operator ==(Object other) =>
      other is Schema &&
      sql == other.sql &&
      table == other.table &&
      primaryKey == other.primaryKey &&
      const ListEquality<Column>().equals(columns, other.columns) &&
      const ListEquality<ForeignKey>().equals(foreignKeys, other.foreignKeys);
  @override
  int get hashCode => Object.hash(sql, table, primaryKey,
      Object.hashAll(columns), Object.hashAll(foreignKeys));
}
