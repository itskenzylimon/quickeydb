import 'package:quickeydb/types/reference.dart';
import '../configs/patterns.dart';
import 'column.dart';
import 'foreign_key.dart';

class Schema {
  final String sql;

  final String? table;
  final List<Column> columns;
  final String? primaryKey;
  final List<ForeignKey> foreignKeys;

  Schema(String sql)
      : sql = sql.trim(),
        table = RegExp(tablePattern).firstMatch(sql)!.group(1),
        columns = RegExp(columnsPattern).allMatches(sql).map((match) {
          final defention = match.group(0)!;

          return Column(
            name: match.group(1),
            isNullable: defention.contains('NOT NULL'),
            isUnique: defention.contains('UNIQUE'),
            defaultValue: defention.contains('DEFAULT')
                ? defention
                    .substring(defention.indexOf('DEFAULT'))
                    .replaceAll('DEFAULT', '')
                    .replaceAll(',', '')
                    .trim()
                : null,
          );
        }).toList(),
        primaryKey = RegExp(primaryKeysPattern)
            .firstMatch(sql)
            ?.groups([1, 2]).firstWhere((item) => item != null),
        foreignKeys = RegExp(foreignKeyPattern).allMatches(sql).map((match) {
          return ForeignKey(
            parent: match.group(1),
            reference: Reference(
              table: match.group(2),
              primaryKey: match.group(3),
            ),
          );
        }).toList();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Schema &&
          runtimeType == other.runtimeType &&
          sql == other.sql &&
          table == other.table &&
          columns == other.columns &&
          primaryKey == other.primaryKey &&
          foreignKeys == other.foreignKeys;

  @override
  int get hashCode =>
      sql.hashCode ^
      table.hashCode ^
      columns.hashCode ^
      primaryKey.hashCode ^
      foreignKeys.hashCode;

  @override
  String toString() {
    return 'Schema(sql: $sql, table: $table, columns: $columns, primaryKey: $primaryKey, foreignKeys: $foreignKeys)';
  }
}
