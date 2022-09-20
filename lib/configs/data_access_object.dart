import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:quickeydb/quickeydb.dart';
import 'package:quickeydb/extension/core_extension.dart';
import 'package:quickeydb/builder/quickey_Builder.dart';
import 'package:quickeydb/builder/data_method.dart';
import 'package:quickeydb/builder/query_method.dart';
import 'package:quickeydb/configs/logger.dart';
import 'package:quickeydb/controls/relation.dart';
import 'package:quickeydb/types/schema.dart';
import 'package:sqflite_common/src/sql_builder.dart';
import 'package:sqflite_common/sqlite_api.dart';

class DataAccessObject<T> implements QueryMethod<T?>, DataMethods<T?> {
  final Schema schema;
  final Converter<T?> converter;
  final List<Relation> relations;

  DataAccessObject(
  final String sql, {
  required final this.converter,
  this.relations = const [],
})  : schema = Schema(sql);

Type get type => T;
Database? get database => QuickeyDB.getInstance!.database;
bool? get isLogger => QuickeyDB.getInstance!.logger;

final List<String> _select = [];
final List<String> _columns = [];
final Map<String, dynamic> _where = {};
final Map<String, dynamic> _or = {};
final List<String> _group = [];
final List<String> _having = [];
final List<String> _order = [];
final List<DataAccessObject?> _includes = [];
final List<DataAccessObject> _joins = [];
int? _limit, _offset;
bool? _distinct;

String? get _whereQuery => _where.isEmpty && _or.isEmpty
    ? null
    : [_where.keys.join(' AND '), _or.keys.map((key) => ' OR $key').join()]
    .join();

List<dynamic> get _whereArgs => [..._where.values, ..._or.values].flatten;

/// Relation
@override
Future<int> updateAll(Map<String, dynamic> values) async {
  final builder = SqlBuilder.update(
    schema.table!,
    values,
    where: _whereQuery,
    whereArgs: _whereArgs,
  );

  final completer = Completer<int>()
    ..complete(database!.rawUpdate(builder.sql, builder.arguments));

  if (isLogger!) Logger.update(type, completer.future, builder);

  return await completer.future.whenComplete(clear);
}

@override
String toSql() {
  final builder = _copyQueryWith();
  clear();
  return builder.fullSql;
}

/// Calculations
@override
Future<double?> average(String column) async {
  final builder = _copyQueryWith(columns: ['AVG($column)']);

  final completer = Completer<List<Map<String, dynamic>>>()
    ..complete(database!.rawQuery(builder.sql, builder.arguments));

  if (isLogger!) Logger.query(type, completer.future, builder);
  final result = await completer.future;

  return result.first.values.firstOrNull as double?;
}

@override
Future<int?> count([String column = '*']) async {
  final builder = _copyQueryWith(columns: ['COUNT($column)']);

  final completer = Completer<List<Map<String, dynamic>>>()
    ..complete(database!.rawQuery(builder.sql, builder.arguments));

  if (isLogger!) Logger.query(type, completer.future, builder);
  final result = await completer.future;

  return result.firstOrNull?.values.firstOrNull as int?;
}

@override
Future<List<dynamic>> get ids async {
  final builder =
  _copyQueryWith(columns: ['${schema.table}.${schema.primaryKey}']);

  final completer = Completer<List<Map<String, dynamic>>>()
    ..complete(database!.rawQuery(builder.sql, builder.arguments));

  if (isLogger!) Logger.query(type, completer.future, builder);
  final result = await completer.future;

  return result.expand((item) => item.values).toList();
}

@override
Future<int?> maximum(String column) async {
  final builder = _copyQueryWith(columns: ['MAX($column)']);

  final completer = Completer<List<Map<String, dynamic>>>()
    ..complete(database!.rawQuery(builder.sql, builder.arguments));

  if (isLogger!) Logger.query(type, completer.future, builder);
  final result = await completer.future;

  return result.firstOrNull?.values.firstOrNull as int?;
}

@override
Future<int?> minimum(String column) async {
  final builder = _copyQueryWith(columns: ['MIN($column)']);

  final completer = Completer<List<Map<String, dynamic>>>()
    ..complete(database!.rawQuery(builder.sql, builder.arguments));

  if (isLogger!) Logger.query(type, completer.future, builder);
  final result = await completer.future;

  return result.firstOrNull?.values.firstOrNull as int?;
}

@override
Future<List<dynamic>> pick(List<String> columns) async {
  return limit(1).pluck(columns).then((value) => value.firstOrNull);
}

@override
Future<List<dynamic>> pluck(List<String> columns) async {
  final builder = _copyQueryWith(
      columns: columns.map((column) => '${schema.table}.$column').toList());

  final completer = Completer<List<Map<String, dynamic>>>()
    ..complete(database!.rawQuery(builder.sql, builder.arguments));

  if (isLogger!) Logger.query(type, completer.future, builder);
  final result = await completer.future
      .then((value) => value.map((item) => item.values.toList()).toList())
      .whenComplete(clear);

  return columns.length == 1 ? result.flatten : result;
}

@override
Future<int?> sum(String column) async {
  final builder = _copyQueryWith(columns: ['SUM($column)']);

  final completer = Completer<List<Map<String, dynamic>>>()
    ..complete(database!.rawQuery(builder.sql, builder.arguments));

  if (isLogger!) Logger.query(type, completer.future, builder);
  final result = await completer.future;

  return result.firstOrNull?.values.firstOrNull as int?;
}

// Queries
@override
QueryMethod<T?> select(List<String> args) {
  return this.._columns.addAll(args.map((arg) => '${schema.table}.$arg'));
}

@override
QueryMethod<T?> distinct([bool value = true]) {
  return this.._distinct = value;
}

@override
QueryMethod<T?> group(List<String> args) {
  return this.._group.addAll(args.map((arg) => '${schema.table}.$arg'));
}

@override
QueryMethod<T?> having(String opts) {
  return this.._having.add(opts);
}

@override
QueryMethod<T?> order(List<String> columns) {
  return this
    .._order.addAll(columns
        .map((item) => item.split(' ').length > 1 ? item : '$item ASC'));
}

@override
QueryMethod<T?> where(Map<String?, dynamic> args) {
  return this
    .._where.addAll(args.map((key, value) {
      key = key!.trim();
      if (!key.contains(' ')) key += ' = ?';
      // if (value == null)
      return MapEntry('${schema.table}.$key', value);
    }));
}

@override
QueryMethod<T?> or(Map<String, dynamic> args) {
  return this
    .._or.addAll(
        args.map((key, value) => MapEntry('${schema.table}.$key', value)));
}

@override
QueryMethod<T> not(Map<String, dynamic> args) {
  throw UnimplementedError();
  // return where(args.map((key, value) => MapEntry('$key != ?', value)));
}

@override
QueryMethod<T?> limit(int value) {
  return this.._limit = value;
}

@override
QueryMethod<T?> offset(int value) {
  return this.._offset = value;
}


// ProxyInclude0<AccountingBookAuditDao, AccountingBookDao, CurrencyDao>(),
@override
QueryMethod<T?> includes(List args) {
  _includes
    ..clear()
    ..addAll(args.map((arg) {

      DataAccessObject? value;

      final isDao = QuickeyDB.getInstance!.dataAccessObjects!.containsKey(arg);

      if (isDao) {
        value = QuickeyDB.getInstance!.dataAccessObjects![arg];
      } else if (arg is ProxyInclude) {
        value = arg.parent;
        value!.includes(arg.children);
        if (kDebugMode) {
          print(arg);
        }
      }

      return value;
    }));

  return this;
}

@override
QueryMethod<T?> joins(List<Type> args) {
  _joins
    ..clear()
    ..addAll(
      args.map((arg) {
        final dao = QuickeyDB.getInstance!.dataAccessObjects![arg]!;

        /// get [include] ForeignKey
        final foreignKey = schema.foreignKeys.find(
              (foreignKey) => foreignKey.reference!.table == dao.schema.table,
        )!;

        /// Add inner join
        _select.add(
            'INNER JOIN ${dao.schema.table} ON ${dao.schema.table}.'
            '${dao.schema.primaryKey} = ${schema.table}.${foreignKey.parent}');

        /// Add inner join columns
        _columns.addAll(
          dao.schema.columns.map((column) {
            /// table.column AS type_column
            return '${dao.schema.table}.${column.name} AS '
                '${dao.type.toString().toCamelCase()}_${column.name}';
          }).toList(),
        );

        return dao;
      }),
    );

  return this;
}

/// Finders
@override
Future<bool> isExists(Map<String, dynamic> args) async {
  return findBy(args).then((value) => value != null);
}

@override
Future<T?> find(int id) async {
  return where({schema.primaryKey: id}).first;
}

@override
Future<T?> findBy(Map<String, dynamic> args) async {
  return where(args).first;
}

@override
Future<T?> get first async {
  return limit(1).toList().then((value) => value.firstOrNull);
}

@override
Future<T?> get last async {
  return toList().then((value) => value.lastOrNull);
}

@override
Future<List<T?>> take([int limit = 1]) async {
  return this.limit(limit).toList();
}

/// Persistence
@override
Future<dynamic> create(T? item) async {
  return await insert(converter.decode(item));
}

@override
Future createAll(List<T?> items) async {
  return await Future.forEach(items, (dynamic item) async => await create(item));
}

@override
Future<dynamic> insert(Map<String?, Object?> values) async {
  Map<String, Object?>? mapValue = values.cast<String, Object?>();
  Future<dynamic> call() async {
    final builder = SqlBuilder.insert(schema.table!, mapValue);

    final completer = Completer<int>()
      ..complete(database!.rawInsert(builder.sql, builder.arguments));
    if (isLogger!) Logger.insert(type, completer.future, builder);

    final id = await completer.future;

    // assign primary key to values if not exists
    if (values[schema.primaryKey!] == null) values[schema.primaryKey!] = id;

    /// assign primary key to values
    return values[schema.primaryKey!];
  }

  for (final relation in relations) {

    if (relation is BelongsTo) {
      if (kDebugMode) {
        print('$type ${relation.runtimeType}');
      }

      if (kDebugMode) {
        print('values $values');
      }

      final association = values.remove('${relation.dao!.type}'.toCamelCase())
      as Map<String?, dynamic>?;

      if (association != null) {
        final Relation<DataAccessObject<dynamic>>? assocationRelation = relation.dao!.relations
            .find((rel) => rel.dao!.schema.table == schema.table);

        /// Convert relation to [has-one] or [has-many]
        /// and use insert which will trigger later the relation
        if (assocationRelation is HasOne) {
          association['$type'.toCamelCase()] = values;
        } else if (assocationRelation is HasMany) {
          association[schema.table] = [values];
        }

        return relation.dao!.insert(association);

      }
    }

    else if (relation is HasOne) {
      if (kDebugMode) {
        print('$type ${relation.runtimeType}');
      }

      final association = values.remove('${relation.dao!.type}'.toCamelCase())
      as Map<String?, dynamic>?;

      /// insert master will add id into values
      await call();

      if (values[schema.primaryKey] == -1) {
        return throw Exception(
          'Something went wrong while inserting $runtimeType',
        );
      }

      if (association != null) {
        final foreignKey = relation.dao!.schema.foreignKeys.find(
              (fk) => fk.reference!.table == schema.table,
        );

        if (foreignKey != null) {

          association[foreignKey.parent] = values[schema.primaryKey];

          await relation.dao!.insert(association);

          /// Set `null` relation attribute to avoid `null` exception while converting
          values['$relation.dao.type}'.toCamelCase()] = null;

          // master['$type'.toCamelCase()] = association;

          /// add association to master
          // values['$type'.toCamelCase()] =await relation.dao.insert(association);
          // print();
          if (kDebugMode) {
            print(association);
          }

          return values[schema.primaryKey];
        } else {
          throw Exception(
            '''
              $runtimeType: could not find foreign key for ${schema.table}\n
              Make sure to add HasOne<${relation.dao!.type}> in $runtimeType
              ''',
          );
        }
      }
    }

    else if (relation is HasMany) {

      if (kDebugMode) {
        print(
          '$runtimeType has_many ${relation.dao!.type} via '
              '${relation.dao!.schema.table}');
      }

      /// Make sure to remove `relation` object from master
      final associations = values.remove(relation.dao!.schema.table)
      as List<Map<String?, dynamic>>?;

      /// insert master will fill id in values
      await call();

      /// make sure that insert was success
      if (values[schema.primaryKey] == -1) {
        return throw Exception(
          'Something went wrong while inserting $runtimeType',
        );
      }

      if (associations != null) {
        /// load foreign key
        final foreignKey = relation.dao!.schema.foreignKeys.find(
              (fk) => fk.reference!.table == schema.table,
        );

        if (foreignKey != null) {
          for (final association in associations) {
            association[foreignKey.parent] = values[schema.primaryKey];
          }
          // association['$type'.toCamelCase()] = values;

          await relation.dao!.insertAll(associations);

          /// Set empty relation attribute to avoid `null` exception while converting
          values[relation.dao!.schema.table] = [];

          return values[schema.primaryKey];
        } else {
          throw Exception(
            '''
              $runtimeType: could not find foreign key for ${schema.table}
              Make sure to add HasMany<${relation.dao!.type}> in $runtimeType
              ''',
          );
        }
      }
    }
  }

  return call();
}

@override
Future insertAll(List<Map<String?, dynamic>> items) async {
  await Future.forEach(items, (dynamic item) async => await insert(item));
}

@override
Future<int> update(T? item) async {
  final values = converter.decodeTable(item);
  where({schema.primaryKey: values.remove(schema.primaryKey)});

  /// Remove any relation attributes
  for (final relation in relations) {

    if (relation is HasMany) {
      values.remove(relation.dao!.schema.table);
    } else if (relation is BelongsTo) {
      values.remove(relation.dao!.type);
    } else if (relation is HasOne) {
      values.remove(relation.dao!.schema.table);
    }
  }

  final builder = SqlBuilder.update(
    schema.table!,
    values as Map<String, Object?>,
    where: _whereQuery,
    whereArgs: _whereArgs,
  );

  final completer = Completer<int>()
    ..complete(database!.rawUpdate(builder.sql, builder.arguments));

  if (isLogger!) Logger.update(type, completer.future, builder);

  return await completer.future.whenComplete(clear);
}

@override
Future<int> delete(T? item) async {
  final values = converter.decode(item);

  where({schema.primaryKey: values.remove(schema.primaryKey)});

  final builder = SqlBuilder.delete(
    schema.table!,
    where: _whereQuery,
    whereArgs: _whereArgs,
  );

  final completer = Completer<int>()
    ..complete(database!.rawDelete(builder.sql, builder.arguments));

  if (isLogger!) Logger.destroy(type, completer.future, builder);

  return await completer.future.whenComplete(clear);
}

@override
Future<int> destroy(int id) async {
  final builder = SqlBuilder.delete(
    schema.table!,
    where: '${schema.table}.${schema.primaryKey} = ?',
    whereArgs: [id],
  );

  final completer = Completer<int>()
    ..complete(database!.rawDelete(builder.sql, builder.arguments));

  if (isLogger!) Logger.destroy(type, completer.future, builder);

  return await completer.future;
}

@override
Future<int> destroyAll() async {
  final builder = SqlBuilder.delete(schema.table!, whereArgs: []);

  final completer = Completer<int>()
    ..complete(database!.rawDelete(builder.sql, builder.arguments));

  if (isLogger!) Logger.destroy(type, completer.future, builder);

  return await completer.future;
}

@override
Future<List<T?>> toList() async {
  return (await toMap()).map((item) => converter.encode(item)).toList();
}

@override
Future<List<Map<String?, dynamic>>> toMap() async {
  if (_offset != null && _limit == null) {
    return throw UnsupportedError(
      'You need to pass LIMIT when using OFFSET\n'
          'Use: dao.limit(x).offset(x) instead of dao.offset(x)',
    );
  }

  if (_having.isNotEmpty && _group.isEmpty) {
    return throw UnsupportedError(
      'You need to pass GROUP BY when using HAVING\n'
          'Use: dao.having(x).group(x) instead of dao.having(x)',
    );
  }

  if (_or.isNotEmpty && _where.isEmpty) {
    return throw UnsupportedError(
      'You need to pass WHERE when using OR\n'
          'Use: dao.where(x).or(x) instead of dao.or(x)',
    );
  }

  final builder = _copyQueryWith();

  final completer = Completer<List<Map<String, dynamic>>>()
    ..complete(database!.rawQuery(builder.sql, builder.arguments));

  if (isLogger!) Logger.query(type, completer.future, builder);

  /// use mapping to convert `QueryRow` into `Map` so we can edit that list
  final items = await completer.future.then(
        (values) => values.map((value) {
      var item = Map<String?, dynamic>.from(value);

      /// Search for any join to convert join to nested attributes
      for (final relation in relations) {
        final join = _joins.find((join) => join.type == relation.dao!.type);
        final include =
        _includes.find((include) => include!.type == relation.dao!.type);

        if (join != null) item.nest('${join.type}'.toCamelCase());

        /// nest item if no include
        if (include == null) {
          final foreignKey = schema.foreignKeys.find(
                (fk) => fk.reference!.table == relation.dao!.schema.table,
          );

          if (foreignKey != null) {
            item.nest('${relation.dao!.type}'.toCamelCase());
          }
        }

      }

      return item;
    }).toList(),
  );

  /// include associations
  for (final include in _includes) {
    final Relation<DataAccessObject<dynamic>>? relation = relations.find(
            (relation) => relation.dao!.schema.table == include!.schema.table);

    if (kDebugMode) {
      print(relation);
    }

    if (relation is BelongsTo) {
      final foreignKey = schema.foreignKeys.find(
            (fk) => fk.reference!.table == include!.schema.table,
      );

      /// collect ids to avoid duplication
      final foreignKeys =
      items.map((item) => item[foreignKey!.parent]).toSet().toList();

      // if not empty
      if (foreignKeys.isNotEmpty) {
        /// if length is only one record then use a simple where statment
        if (foreignKeys.length == 1) {
          include!.where({include.schema.primaryKey: foreignKeys.first});
        }

        /// else use where in
        else {
          include!.where({
            '${include.schema.primaryKey} IN (${List.filled(foreignKeys.length, '?').join(',')})':
            foreignKeys
          }).limit(foreignKeys.length);
        }

        final associations = await include.toMap();

        /// add all associations to object for
        for (final item in items) {
          final Map<String?, dynamic>? association = associations.find(
                (association) {
              final primaryKey = association[include.schema.primaryKey];

              /// search for `primaryKey` that matches item `foreignKey`
              return primaryKey == item[foreignKey!.parent];
            },
          );

          item['${include.type}'.toCamelCase()] = association;
        }
      }
    }

    else {
      final foreignKey = relation!.dao!.schema.foreignKeys.find(
            (fk) => fk.reference!.table == schema.table,
      );

      /// collect ids to avoid duplication
      final primaryKeys =
      items.map((item) => item[schema.primaryKey]).toSet().toList();

      // if not empty
      if (primaryKeys.isNotEmpty) {
        /// if length is only one record then use a simple where statment
        if (primaryKeys.length == 1) {
          include!.where({foreignKey!.parent: primaryKeys.first});
        } else {
          include!.where({
            '${foreignKey!.parent} IN (${List.filled(primaryKeys.length, '?').join(',')})':
            primaryKeys
          }).limit(primaryKeys.length);
        }

        final associations = await include.toMap();

        for (final item in items) {
          /// assign association to parent
          if (relation is HasOne) {
            item['${include.type}'.toCamelCase()] = associations.find(
                  (association) {
                /// search for `primaryKey` that matches item `foreignKey`
                return association[include.schema.primaryKey] ==
                    item[include.schema.primaryKey];
              },
            );
          }

          // just removed  || relation is ProxyHasMany
          else if (relation is HasMany) {
            item[include.schema.table] = associations;
          }

          if (kDebugMode) {
            print('item: $item');
          }
        }
      }
    }
    break;
  }

  clear();

  return items;
}

@override
Future<List<T?>> get all => toList();
Future<bool> get isEmpty async => (await count())! > 0;
Future<bool> get isNotEmpty async => !await isEmpty;

SqlBuilder _copyQueryWith({
  bool? distinct,
  List<String>? columns,
  String? where,
  List<dynamic>? whereArgs,
  String? groupBy,
  String? having,
  String? orderBy,
  int? limit,
  int? offset,
}) {
  return SqlBuilder.query(
    [schema.table, ..._select].join(' '),
    distinct: distinct ?? _distinct,
    columns: columns ?? ['${schema.table}.*', ..._columns],
    where: where ?? _whereQuery,
    whereArgs: whereArgs ?? _whereArgs,
    groupBy: groupBy as bool? ?? _group.isEmpty ? null : _group.join(', '),
    having: having as bool? ?? _having.isEmpty ? null : _having.join(', '),
    orderBy: orderBy as bool? ?? _order.isEmpty ? null : _order.join(', '),
    limit: limit ?? _limit,
    offset: offset ?? _offset,
  );
}

void clear() {
  /// Queries
  _select.clear();
  _distinct = null;
  _columns.clear();
  _where.clear();
  _or.clear();
  _group.clear();
  _having.clear();
  _order.clear();
  _limit = null;
  _offset = null;

  /// Associations
  _includes.clear();
  _joins.clear();
}
}
