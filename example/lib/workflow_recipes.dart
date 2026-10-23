import 'package:quickeydb/quickeydb.dart';

typedef WorkRow = Map<String?, dynamic>;

/// Small map-based DAO for the cookbook; register it once with initialize.
class WorkItems extends DataAccessObject<WorkRow> {
  WorkItems()
    : super(
        '''
CREATE TABLE work_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  bucket TEXT NOT NULL DEFAULT 'inbox',
  archived INTEGER NOT NULL DEFAULT 0
)
''',
        converter: Converter<WorkRow?>(
          encode: (row) => Map<String?, dynamic>.from(row),
          decode: (row) => Map<String?, dynamic>.from(row!),
          decodeTable: (row) => Map<String?, dynamic>.from(row!),
        ),
      );
}

/// Descending keyset pagination stays stable when newer rows are inserted.
/// Projection returns maps; it deliberately does not run a full model converter.
Future<List<WorkRow>> pageBefore(
  WorkItems items, {
  int? beforeId,
  int pageSize = 20,
}) {
  if (pageSize < 1 || pageSize > 100) {
    throw ArgumentError.value(pageSize, 'pageSize', 'Use 1–100');
  }
  final scope = items.query().where({'archived': 0});
  if (beforeId != null) scope.where({'id < ?': beforeId});
  return scope
      .select(['id', 'title'])
      .order(['id'], 'DESC')
      .limit(pageSize)
      .toMap();
}

/// Replace a dedicated inbox as one transaction; unrelated buckets survive.
/// The application's chosen conflict policy applies to the replacement rows.
Future<void> replaceInbox(
  QuickeyDBImpl database,
  WorkItems items,
  List<WorkRow> replacements,
) async {
  if (replacements.any((row) => row['bucket'] != 'inbox')) {
    throw ArgumentError('Every replacement must belong to the inbox');
  }
  await database.transaction(() async {
    await items.query().where({'bucket': 'inbox'}).deleteWhere();
    await items.insertAll(replacements);
  });
}

/// Bound values and independent scopes keep reads and bulk updates separate.
Future<int> archiveBefore(WorkItems items, int exclusiveId) => items
    .query()
    .where({'id < ?': exclusiveId, 'archived': 0})
    .updateAll({'archived': 1});
