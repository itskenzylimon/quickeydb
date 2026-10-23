import 'dart:async';
import 'dart:typed_data';
import 'package:sqflite_common/sqlite_api.dart';
import '../quickeydb.dart';
import '../builder/data_method.dart';
import '../builder/query_method.dart';
import '../controls/relation.dart';
import '../types/schema.dart';
import 'migration.dart';
import 'sql_builder.dart';
import 'logger.dart';

/// Table metadata plus the backwards-compatible fluent query API.
/// Use [query] for independent scopes; terminal operations consume their scope
/// before the first await, including when execution subsequently fails.
class DataAccessObject<T> implements QueryMethod<T?>, DataMethods<T?> {
  final Schema schema;
  final Converter<T?> converter;
  final List<Relation> relations;
  final Set<String> encryptedColumns;
  final ConflictAlgorithm? insertConflictAlgorithm;
  final List<String> _columns = [],
      _where = [],
      _group = [],
      _having = [],
      _order = [];
  final List<Object?> _args = [];
  final List<Object> _includes = [];
  final List<Type> _joins = [];
  int? _limit, _offset;
  bool _distinct = false;

  DataAccessObject(String sql,
      {required this.converter,
      this.relations = const [],
      Set<String> encryptedColumns = const {},
      this.insertConflictAlgorithm})
      : schema = Schema(sql),
        encryptedColumns = Set.unmodifiable(encryptedColumns) {
    if (schema.columns
            .any((c) => c.isUnique && encryptedColumns.contains(c.name)) ||
        schema.foreignKeys.any((f) => encryptedColumns.contains(f.parent)) ||
        encryptedColumns.contains(schema.primaryKey) ||
        encryptedColumns
            .any((name) => !schema.columns.any((c) => c.name == name))) {
      throw ArgumentError(
          'Encrypted columns must exist and cannot be primary keys.');
    }
  }
  DataAccessObject._(
      {required this.schema,
      required this.converter,
      required this.relations,
      required this.encryptedColumns,
      required this.insertConflictAlgorithm});

  Type get type => T;
  QuickeyDBImpl get _db =>
      QuickeyDB.getInstance ??
      (throw StateError('Initialize QuickeyDB first.'));
  Database? get database => _db.database;
  DatabaseExecutor get _executor => _db.executor;
  bool? get isLogger => _db.logger;

  /// Fresh query scope; does not mutate the registered DAO.
  DataAccessObject<T> query() => DataAccessObject<T>._(
      schema: schema,
      converter: converter,
      relations: relations,
      encryptedColumns: encryptedColumns,
      insertConflictAlgorithm: insertConflictAlgorithm);

  DataAccessObject<T> _consume() {
    final copy = query();
    copy._columns.addAll(_columns);
    copy._where.addAll(_where);
    copy._args.addAll(_args);
    copy._group.addAll(_group);
    copy._having.addAll(_having);
    copy._order.addAll(_order);
    copy._includes.addAll(_includes);
    copy._joins.addAll(_joins);
    copy._limit = _limit;
    copy._offset = _offset;
    copy._distinct = _distinct;
    clear();
    return copy;
  }

  void clear() {
    _columns.clear();
    _where.clear();
    _args.clear();
    _group.clear();
    _having.clear();
    _order.clear();
    _includes.clear();
    _joins.clear();
    _limit = null;
    _offset = null;
    _distinct = false;
  }

  String _column(String key) => key.contains('.')
      ? key
      : '${quoteIdentifier(schema.table!)}.${schema.columns.any((c) => c.name == key) ? quoteIdentifier(key) : key}';
  void _conditions(Map<String?, dynamic> values, String join,
      {bool negate = false}) {
    if (values.isEmpty) return;
    final clauses = <String>[];
    final arguments = <Object?>[];
    for (final entry in values.entries) {
      final key = entry.key?.trim();
      if (key == null || key.isEmpty) {
        throw ArgumentError('Empty condition key.');
      }
      if (encryptedColumns
          .any((c) => RegExp('\\b${RegExp.escape(c)}\\b').hasMatch(key))) {
        throw UnsupportedError(
            'Filter encrypted columns in application memory, or use full-file encryption.');
      }
      final simple = RegExp(r'^\w+$').hasMatch(key) ||
          schema.columns.any((c) => c.name == key);
      final expression = _column(simple ? quoteIdentifier(key) : key);
      if (simple && entry.value == null) {
        clauses.add('$expression IS NULL');
      } else {
        clauses.add(simple ? '$expression = ?' : expression);
        void add(Object? value) {
          if (value is List && value is! Uint8List) {
            for (final element in value) {
              add(element);
            }
          } else {
            arguments.add(value);
          }
        }

        add(entry.value);
      }
    }
    _args.addAll(arguments);
    final expression = '${negate ? 'NOT ' : ''}(${clauses.join(' AND ')})';
    if (_where.isNotEmpty) _where.add(join);
    _where.add(expression);
  }

  @override
  DataAccessObject<T> where(Map<String?, dynamic> args) {
    _conditions(args, 'AND');
    return this;
  }

  @override
  DataAccessObject<T> or(Map<String, dynamic> args) {
    _conditions(args, 'OR');
    return this;
  }

  @override
  DataAccessObject<T> not(Map<String, dynamic> args) {
    _conditions(args, 'AND', negate: true);
    return this;
  }

  @override
  DataAccessObject<T> select(List<String> args) {
    _columns.addAll(args.map(_column));
    return this;
  }

  @override
  DataAccessObject<T> distinct([bool value = true]) {
    _distinct = value;
    return this;
  }

  @override
  DataAccessObject<T> group(List<String> args) {
    if (args.any((name) => encryptedColumns
        .any((c) => RegExp('\\b${RegExp.escape(c)}\\b').hasMatch(name)))) {
      throw UnsupportedError('Cannot group randomized encrypted values.');
    }
    _group.addAll(args.map(_column));
    return this;
  }

  @override
  DataAccessObject<T> having(String opts) {
    _having.add(opts);
    return this;
  }

  @override
  DataAccessObject<T> order(List<String> columns, String type) {
    if (columns.any((name) => encryptedColumns
        .any((c) => RegExp('\\b${RegExp.escape(c)}\\b').hasMatch(name)))) {
      throw UnsupportedError('Cannot order randomized encrypted values.');
    }
    final direction = type.isEmpty ? 'ASC' : type.toUpperCase();
    if (!['ASC', 'DESC'].contains(direction)) {
      throw ArgumentError('Order must be ASC or DESC.');
    }
    _order.addAll(columns.map((c) => c.contains(' ') ? c : '$c $direction'));
    return this;
  }

  @override
  DataAccessObject<T> limit(int value) {
    if (value < 0) throw ArgumentError('Negative limit.');
    _limit = value;
    return this;
  }

  @override
  DataAccessObject<T> offset(int value) {
    if (value < 0) throw ArgumentError('Negative offset.');
    _offset = value;
    return this;
  }

  @override
  DataAccessObject<T> includes(List args) {
    for (final arg in args) {
      if (arg is! Type && arg is! ProxyInclude && arg is! DataAccessObject) {
        throw ArgumentError('Unknown include.');
      }
      _includes.add(arg as Object);
    }
    return this;
  }

  @override
  DataAccessObject<T> joins(List<Type> args) {
    _joins.addAll(args);
    return this;
  }

  SqlBuilder _builder({List<String>? columns}) {
    if (_offset != null && _limit == null) {
      throw UnsupportedError('OFFSET requires LIMIT.');
    }
    if (_having.isNotEmpty && _group.isEmpty) {
      throw UnsupportedError('HAVING requires GROUP BY.');
    }
    final table = schema.table!;
    final from = StringBuffer(quoteIdentifier(table));
    final selected = columns ??
        (_columns.isEmpty
            ? ['${quoteIdentifier(table)}.*']
            : List<String>.from(_columns));
    for (final join in _joins) {
      final dao = _db.dataAccessObjects?[join] ??
          (throw ArgumentError('Unregistered join $join'));
      final fk = schema.foreignKeys
          .where((f) => f.reference?.table == dao.schema.table)
          .firstOrNull;
      if (fk == null) throw ArgumentError('No foreign key for join $join.');
      from.write(
          ' INNER JOIN ${quoteIdentifier(dao.schema.table!)} ON ${quoteIdentifier(dao.schema.table!)}.${quoteIdentifier(dao.schema.primaryKey!)} = ${quoteIdentifier(table)}.${quoteIdentifier(fk.parent!)}');
      if (columns == null) {
        for (final col in dao.schema.columns) {
          selected.add(
              '${quoteIdentifier(dao.schema.table!)}.${quoteIdentifier(col.name!)} AS ${quoteIdentifier('${_modelKey(dao.type)}_${col.name}')}');
        }
      }
    }
    return SqlBuilder.query(from.toString(),
        distinct: _distinct,
        columns: selected,
        where: _where.isEmpty ? null : _where.join(' '),
        whereArgs: _args,
        groupBy: _group.isEmpty ? null : _group.join(', '),
        having: _having.isEmpty ? null : _having.join(' AND '),
        orderBy: _order.isEmpty ? null : _order.join(', '),
        limit: _limit,
        offset: _offset);
  }

  @override
  String toSql() {
    final b = _consume()._builder();
    // Intentionally diagnostic; never executable value interpolation.
    return '${b.sql} /* args: ${List.filled(b.arguments?.length ?? 0, '<bound>').join(', ')} */';
  }

  Future<R> _trace<R>(
      Future<R> operation, String action, SqlBuilder builder) async {
    if (isLogger == true) Logger.sql(operation, '$action ${schema.table}');
    final logging = _db.queryLogging;
    // Snapshot policy before execution so enabling later cannot expose old work.
    final observe = logging?.isEnabled == true;
    if (!observe) return operation;
    final sql = observe && logging!.includeSql ? builder.sql : null;
    final watch = Stopwatch()..start();
    R? result;
    Object? failure;
    try {
      final value = await operation;
      result = value;
      return value;
    } catch (error) {
      failure = error;
      rethrow;
    } finally {
      if (observe) {
        logging!.emit(QueryLogEvent(
            operation: action,
            table: schema.table!,
            elapsed: watch.elapsed,
            timestamp: DateTime.now().toUtc(),
            succeeded: failure == null,
            sql: sql,
            parameterCount: builder.arguments?.length ?? 0,
            // INSERT returns a row ID, not a row count.
            rowCount: result is List
                ? result.length
                : action != 'INSERT' && result is int
                    ? result
                    : null,
            errorType: failure?.runtimeType.toString()));
      }
    }
  }

  Future<List<Map<String, dynamic>>> _read({List<String>? columns}) async {
    final b = _builder(columns: columns);
    final result =
        await _trace(_executor.rawQuery(b.sql, b.arguments), 'SELECT', b);
    final rows = result.map((r) => Map<String, dynamic>.from(r)).toList();
    for (final row in rows) {
      await _decrypt(row);
    }
    return rows;
  }

  Future<void> _decrypt(Map<String, dynamic> row) async {
    for (final column in encryptedColumns) {
      if (!row.containsKey(column)) continue;
      final cipher = _db.valueEncryption;
      if (cipher == null) {
        throw StateError('Supply valueEncryption for protected columns.');
      }
      row[column] =
          await cipher.decrypt(row[column], context: '${schema.table}.$column');
    }
  }

  Future<Map<String, Object?>> _encrypt(Map<String, Object?> values) async {
    final result = Map<String, Object?>.from(values);
    for (final column in encryptedColumns) {
      if (!result.containsKey(column) || result[column] == null) continue;
      final cipher = _db.valueEncryption;
      if (cipher == null) {
        throw StateError('Supply valueEncryption for protected columns.');
      }
      result[column] = await cipher.encrypt(result[column],
          context: '${schema.table}.$column');
    }
    return result;
  }

  /// Encrypt legacy plaintext values transactionally. Re-running is safe.
  Future<void> encryptExisting({bool compact = true}) async {
    if (compact && _db.isInTransaction) {
      throw StateError('Run encryption compaction outside a transaction.');
    }
    await _db.transaction(() async {
      final key =
          schema.primaryKey ?? (throw StateError('Primary key required.'));
      final cipher =
          _db.valueEncryption ?? (throw StateError('Encryption key required.'));
      final rows = await _executor.query(schema.table!);
      for (final row in rows) {
        final values = <String, Object?>{};
        for (final c in encryptedColumns) {
          if (row[c] != null && !cipher.isEncrypted(row[c])) {
            values[c] =
                await cipher.encrypt(row[c], context: '${schema.table}.$c');
          } else if (cipher.isEncrypted(row[c])) {
            await cipher.decrypt(row[c], context: '${schema.table}.$c');
          }
        }
        if (values.isNotEmpty) {
          await _executor.update(schema.table!, values,
              where: '${quoteIdentifier(key)} = ?', whereArgs: [row[key]]);
        }
      }
    });
    if (compact) {
      await database!.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      await database!.execute('VACUUM');
      await database!.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    }
  }

  static String _modelKey(Type type) => '$type'
      .replaceAllMapped(RegExp(r'(?<=[a-z])[A-Z]'), (match) => '_${match[0]}')
      .toLowerCase();
  Relation _relation(DataAccessObject dao) =>
      relations
          .where((r) => r.dao?.schema.table == dao.schema.table)
          .firstOrNull ??
      (throw ArgumentError('Missing relation for ${dao.schema.table}'));
  Future<void> _hydrate(List<Map<String, dynamic>> rows) async {
    for (final requested in _includes) {
      final DataAccessObject target;
      if (requested is ProxyInclude) {
        target = requested.parent?.query() ??
            (throw ArgumentError('Missing include DAO.'));
        target.includes(
            requested.children.whereType<DataAccessObject>().toList());
      } else if (requested is DataAccessObject) {
        target = requested.query();
      } else {
        target = _db.dataAccessObjects?[requested]?.query() ??
            (throw ArgumentError('Missing include $requested'));
      }
      final relation = _relation(target);
      final belongs = relation is BelongsTo;
      final foreign = (belongs ? schema.foreignKeys : target.schema.foreignKeys)
          .where((f) =>
              f.reference?.table ==
              (belongs ? target.schema.table : schema.table))
          .firstOrNull;
      if (foreign == null) throw StateError('Missing relation foreign key.');
      final parentKey = belongs ? foreign.parent! : schema.primaryKey!;
      final childKey = belongs ? target.schema.primaryKey! : foreign.parent!;
      final ids = rows
          .map((r) => r[parentKey])
          .where((v) => v != null)
          .toSet()
          .toList();
      final grouped = <Object?, List<Map<String?, dynamic>>>{};
      // Bound SQLite variable count and avoid quadratic parent/child scans.
      for (var start = 0; start < ids.length; start += 400) {
        final chunk = ids.sublist(start, (start + 400).clamp(0, ids.length));
        final scope = target.query();
        scope._includes.addAll(target._includes);
        final children = await scope.where({
          '$childKey IN (${List.filled(chunk.length, '?').join(',')})': chunk
        }).toMap();
        for (final child in children) {
          grouped.putIfAbsent(child[childKey], () => []).add(child);
        }
      }
      for (final row in rows) {
        final matches = grouped[row[parentKey]] ?? [];
        row[relation is HasMany
                ? target.schema.table!
                : _modelKey(target.type)] =
            relation is HasMany ? matches : matches.firstOrNull;
      }
    }
    for (final join in _joins) {
      final target = _db.dataAccessObjects![join]!;
      final prefix = '${_modelKey(target.type)}_';
      for (final row in rows) {
        final nested = <String, dynamic>{};
        for (final key
            in row.keys.where((k) => k.startsWith(prefix)).toList()) {
          nested[key.substring(prefix.length)] = row.remove(key);
        }
        await target._decrypt(nested);
        row[_modelKey(target.type)] = nested;
      }
    }
  }

  @override
  Future<List<Map<String?, dynamic>>> toMap() async {
    final scope = _consume();
    final rows = await scope._read();
    await scope._hydrate(rows);
    return rows;
  }

  @override
  Future<List<T?>> toList() async =>
      (await toMap()).map(converter.encode).toList();
  @override
  Future<List<T?>> get all => toList();
  @override
  Future<T?> get first async => (await limit(1).toList()).firstOrNull;
  @override
  Future<T?> get last async => (await toList()).lastOrNull;
  @override
  Future<List<T?>> take([int limit = 1]) => this.limit(limit).toList();
  @override
  Future<T?> find(dynamic id) => where({
        schema.primaryKey ?? (throw StateError('Primary key required.')): id
      }).first;
  @override
  Future<T?> findBy(Map<String, dynamic> args) => where(args).first;
  @override
  Future<bool> isExists(Map<String, dynamic> args) async => (await _consume()
          .where(args)
          .limit(1)
          ._read(columns: ['1 AS quickey_exists']))
      .isNotEmpty;
  Future<bool> get isEmpty async =>
      (await _consume().limit(1)._read(columns: ['1 AS quickey_exists']))
          .isEmpty;
  Future<bool> get isNotEmpty async => !(await isEmpty);
  Future<Object?> _aggregate(String function, String column) async {
    final scope = _consume();
    if (encryptedColumns.contains(column)) {
      throw UnsupportedError('Cannot aggregate encrypted columns.');
    }
    final rows =
        await scope._read(columns: ['$function($column) AS quickey_value']);
    return rows.firstOrNull?['quickey_value'];
  }

  @override
  Future<int?> count([String column = '*']) async =>
      (await _aggregate('COUNT', column)) as int?;
  @override
  Future<double?> average(String column) async =>
      ((await _aggregate('AVG', column)) as num?)?.toDouble();
  @override
  Future<dynamic> maximum(String column) => _aggregate('MAX', column);
  @override
  Future<dynamic> minimum(String column) => _aggregate('MIN', column);
  @override
  Future<int?> sum(String column) async {
    final value = await sumNumber(column);
    if (value != null && value != value.toInt()) {
      throw StateError('Use sumNumber for non-integer sums.');
    }
    return value?.toInt();
  }

  Future<num?> sumNumber(String column) async =>
      (await _aggregate('SUM', column)) as num?;
  @override
  Future<List<dynamic>> get ids =>
      pluck([schema.primaryKey ?? (throw StateError('Primary key required.'))]);
  @override
  Future<List<dynamic>> pluck(List<String> columns) async {
    if (columns.isEmpty) throw ArgumentError('Projection is empty.');
    final scope = _consume();
    final rows =
        await scope._read(columns: columns.map(scope._column).toList());
    return columns.length == 1
        ? rows.map((r) => r[columns.first]).toList()
        : rows.map((r) => columns.map((c) => r[c]).toList()).toList();
  }

  @override
  Future<List<dynamic>> pick(List<String> columns) async {
    final scope = _consume().limit(1);
    final values = await scope.pluck(columns);
    if (values.isEmpty) return [];
    return columns.length == 1 ? [values.first] : values.first as List<dynamic>;
  }

  @override
  Future<dynamic> create(T? item) {
    clear();
    return insert(converter.decode(item));
  }

  @override
  Future<void> createAll(List<T?> items) => _db.transaction(() async {
        for (final item in items) {
          await create(item);
        }
      });
  @override
  Future<void> insertAll(List<Map<String?, dynamic>> items) =>
      _db.transaction(() async {
        for (final item in items) {
          await insert(item);
        }
      });
  @override
  Future<dynamic> insert(Map<String?, Object?> input) {
    clear();
    return _db.transaction(() async {
      final values = Map<String, Object?>.from(input);
      final pending = <Relation, Object?>{};
      for (final relation in relations) {
        final target =
            relation.dao ?? (throw StateError('Unregistered relation DAO.'));
        final key =
            relation is HasMany ? target.schema.table! : _modelKey(target.type);
        final payload = values.remove(key);
        if (relation is BelongsTo && payload != null) {
          final fk = schema.foreignKeys
                  .where((f) => f.reference?.table == target.schema.table)
                  .firstOrNull ??
              (throw StateError('Missing parent foreign key.'));
          values[fk.parent!] =
              await target.insert(Map<String?, Object?>.from(payload as Map));
        } else {
          pending[relation] = payload;
        }
      }
      final encrypted = await _encrypt(values);
      final b = SqlBuilder.insert(schema.table!, encrypted,
          nullColumnHack: schema.primaryKey,
          conflictAlgorithm: insertConflictAlgorithm ?? _db.conflictAlgorithm);
      final id =
          await _trace(_executor.rawInsert(b.sql, b.arguments), 'INSERT', b);
      final primary = schema.primaryKey;
      final result = primary == null ? id : values[primary] ?? id;
      for (final entry in pending.entries) {
        if (entry.value == null || entry.key is BelongsTo) continue;
        final target = entry.key.dao!;
        final fk = target.schema.foreignKeys
                .where((f) => f.reference?.table == schema.table)
                .firstOrNull ??
            (throw StateError('Missing child foreign key.'));
        final children =
            entry.key is HasMany ? entry.value as List : [entry.value];
        for (final child in children) {
          await target.insert({
            ...Map<String?, Object?>.from(child as Map),
            fk.parent!: result
          });
        }
      }
      // Preserve generated-ID assignment for legacy mutable-map callers.
      if (primary != null && input[primary] == null) {
        try {
          input[primary] = result;
        } on UnsupportedError {/* Immutable input is supported. */}
      }
      return result;
    });
  }

  @override
  Future<int> updateAll(Map<String, dynamic> values) async {
    final scope = _consume();
    final b = SqlBuilder.update(
        schema.table!, await _encrypt(Map<String, Object?>.from(values)),
        where: scope._where.isEmpty ? null : scope._where.join(' '),
        whereArgs: scope._args);
    return _trace(_executor.rawUpdate(b.sql, b.arguments), 'UPDATE', b);
  }

  @override
  Future<int> update(T? item) async {
    final scope = _consume();
    final values = Map<String, dynamic>.from(converter.decodeTable(item));
    final key =
        schema.primaryKey ?? (throw StateError('Primary key required.'));
    final id = values.remove(key);
    if (id == null) {
      clear();
      throw ArgumentError('Update requires a primary key.');
    }
    for (final r in relations) {
      values.remove(r.dao?.schema.table);
      values.remove(_modelKey(r.dao!.type));
    }
    return scope.where({key: id}).updateAll(values);
  }

  @override
  Future<int> delete(T? item) {
    final scope = _consume();
    final values = converter.decodeTable(item);
    final id = values[schema.primaryKey];
    if (id == null) {
      clear();
      throw ArgumentError('Delete requires a primary key.');
    }
    return scope.destroy(id);
  }

  @override
  Future<int> destroy(dynamic id) async {
    final scope = _consume();
    scope.where(
        {schema.primaryKey ?? (throw StateError('Primary key required.')): id});
    return scope._deleteRows();
  }

  Future<int> _deleteRows() {
    final b = SqlBuilder.delete(schema.table!,
        where: _where.isEmpty ? null : _where.join(' '), whereArgs: _args);
    return _trace(_executor.rawDelete(b.sql, b.arguments), 'DELETE', b);
  }

  @override
  Future<int> destroyAll() {
    final scope = _consume();
    // Preserve old explicit whole-table semantics, but reject ignored filters.
    if (scope._where.isNotEmpty) {
      throw StateError('Use deleteWhere() for scoped deletion.');
    }
    return scope._deleteRows();
  }

  Future<int> deleteWhere() {
    final scope = _consume();
    if (scope._where.isEmpty) {
      throw StateError('deleteWhere requires a filter.');
    }
    return scope._deleteRows();
  }
}
