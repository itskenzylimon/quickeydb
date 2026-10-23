# QuickeyDB

<p align="center"><img src="https://raw.githubusercontent.com/itskenzylimon/quickeydb/main/assets/quickeydb.png" width="128" alt="QuickeyDB logo"></p>

[![pub package](https://img.shields.io/pub/v/quickeydb.svg)](https://pub.dev/packages/quickeydb)

**3.0.0 release preparation** · [What changed](https://github.com/itskenzylimon/quickeydb/blob/main/CHANGELOG.md) ·
[Upgrade from 1.2.0+8](https://github.com/itskenzylimon/quickeydb/blob/main/doc/MIGRATING_TO_3.md) · [Release checks](https://github.com/itskenzylimon/quickeydb/blob/main/doc/RELEASING.md)

**Local SQLite data for Flutter — SQL schemas, Dart DAOs, fluent queries.**

[Start learning](#new-to-sql-or-quickeydb) · [SQL → DAO](#generate-ready-daos-from-sql) ·
[Reactive example gallery](https://github.com/itskenzylimon/quickeydb/blob/main/example/README.md) · [Test map](https://github.com/itskenzylimon/quickeydb/blob/main/test/README.md) · [In-depth workflows](https://github.com/itskenzylimon/quickeydb/blob/main/doc/FEATURE_RECIPES.md) ·
[Compatibility notes](https://github.com/itskenzylimon/quickeydb/blob/main/CHANGELOG.md)

| Build with | Use it for |
| --- | --- |
| SQL + a DAO | Tables, records and model conversion |
| Independent query scopes | Bound filters, ordering, pagination and projections |
| Transactions and relations | Atomic work and connected records |
| Selected-column AES-GCM | Protecting configured values with an application-managed key |
| Memory | Separate named values with optional encryption and TTL |
| SQL-to-DAO generator | Turning table definitions into reviewable Dart source |

> Explore the [19-section reactive gallery](https://github.com/itskenzylimon/quickeydb/blob/main/example/README.md), styled like the
> Activity example, now using Activity state and routes: inline API/view/model
> code, result terminals, live CRUD, pagination, aggregates, conflict/bulk rollback probes,
> encrypted Memory, SQL generation and migration planning, plus eight application
> recipes, complete DAO samples and a practical integration checklist.


QuickeyDB is a Flutter SQLite ORM with typed model converters, fluent queries,
relationships, transactions, and optional authenticated encryption. Existing
initialization calls, DAO subclasses, default database paths, integer sum API,
and REPLACE-on-insert behavior remain available. Version 3.0.0 requires
**Dart 3.9 / Flutter 3.35 or newer**, matching the minimum declared IDB dependency.

This checkout includes the repairs tracked in [Observations.md](https://github.com/itskenzylimon/quickeydb/blob/main/Observations.md).
The ORM selects native Sqflite/FFI or browser SQLite/WASM automatically.
`quickeywebdb.dart` remains a compatibility import of the same API. Memory's IDB
backend is separate.

## Gallery previews

[![QuickeyDB overview](https://raw.githubusercontent.com/itskenzylimon/quickeydb/main/example/gallery-preview.jpg)](https://github.com/itskenzylimon/quickeydb/blob/main/example/README.md)
[![CRUD code and results](https://raw.githubusercontent.com/itskenzylimon/quickeydb/main/example/gallery-source-preview.jpg)](https://github.com/itskenzylimon/quickeydb/blob/main/example/README.md)

[![Tested workflow examples](https://raw.githubusercontent.com/itskenzylimon/quickeydb/main/example/gallery-workflows.jpg)](https://github.com/itskenzylimon/quickeydb/blob/main/doc/FEATURE_RECIPES.md)

## Package example and branding

The [standalone example](https://github.com/itskenzylimon/quickeydb/blob/main/example/example.md) demonstrates SQL-to-DAO generation
using only QuickeyDB. The [full gallery](https://github.com/itskenzylimon/quickeydb/blob/main/example/README.md) includes CRUD, queries,
encryption and Memory; its repository checkout also needs the sibling Activity
package. Use `flutter pub get --no-example` for package-only development.

The supplied Q logo uses pink, orange and yellow. The gallery defaults to pink,
with matching warm surfaces and selectable orange/yellow accents.

## New to SQL or QuickeyDB?

A **table** groups records with the same columns. A **row** is one record; its
**primary key** identifies it. SQLite is the database engine running locally in
your app. SQL describes its schema and queries. QuickeyDB adds a Dart layer:

```text
CREATE TABLE SQL → DataAccessObject + Converter → query() → Dart results
```

1. Describe a table with a single primary key. Use `INTEGER PRIMARY KEY
   AUTOINCREMENT` when SQLite should assign IDs.
2. Create a DAO subclass, or generate one using the SQL-to-DAO API below.
3. Register DAO instances in `QuickeyDB.initialize` and keep one owner for the
   database handle. Retrieve a registered DAO with `database.get<YourDao>()!`.
4. Create records, query them, update using their ID, and delete deliberately.
   A `Converter` connects maps to typed domain models when you need them.
5. Add validation, indexes, explicit migrations and key management for your app.
   The gallery’s **Start here** and **Tips & points** tabs explain these concepts.

QuickeyDB is local persistence, not a hosted database or automatic cloud sync.
SQLite has no separate Boolean storage class: `INTEGER` values `0` and `1` are a
common choice. Make your model converters explicit about date/time and other
application-specific representations.

## Generate ready DAOs from SQL

The public `SqlDaoGenerator` lives in `lib/codegen/sql_dao_generator.dart` and is
exported by `package:quickeydb/quickeydb.dart`. It needs no `build_runner` and never
executes the input or changes a database.

```dart
import 'package:quickeydb/quickeydb.dart';

final generated = const SqlDaoGenerator().generate('''
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  done INTEGER NOT NULL DEFAULT 0
);
''');

final dartSource = generated.source;      // class TasksDao extends ...
final registration = generated.registration; // [TasksDao()]
final table = generated.tables.first;
// table.tableName, table.className, table.sql, table.schema
```

Save `dartSource` to a Dart file under your app’s `lib/`, format it, and import
that file. The generator returns strings; it does not write files for you. Each
table gets its own named DAO class, so multiple tables can be registered by type.
Generated DAOs use `Map<String?, dynamic>` and a complete map converter:

```dart
// Import your generated tasks_dao.dart first.
final database = await QuickeyDB.initialize(
  dbName: 'my_app', dbVersion: 1,
  dataAccessObjects: [TasksDao()],
  conflictAlgorithm: ConflictAlgorithm.abort,
);
final tasks = database.get<TasksDao>()!;
final id = await tasks.insert({'title': 'Learn SQL'});
final rows = await tasks.query().where({'done': 0}).toMap();
await tasks.query().where({'id': id}).updateAll({'done': 1});
```

| Input | Behavior |
| --- | --- |
| One or more ordinary `CREATE TABLE` statements | Produces one named DAO per table, in input order |
| Optional final semicolon, SQL comments and quoted string values | Split without treating punctuation inside strings as statements |
| Table names | Letters, digits and underscores, starting with a letter; SQLite/internal names and name collisions are rejected |
| Primary key | One per table is required; composite keys are unsupported |
| Foreign keys | Preserved in SQL; configure `foreignKeys: true` when opening for enforcement, and declare DAO eager-loading relations separately |
| Indexes, triggers, views, data changes and table options | Rejected with `FormatException`; apply them separately through reviewed setup/migration code |

This is a schema-to-source helper for the package’s supported table metadata,
not a complete SQLite syntax validator. Review generated source and run database
tests before shipping. It does not infer typed models, encryption policies,
relations or migrations. Decide which columns to encrypt before opening a new
database; adding encryption to existing values needs the explicit migration
shown later in this README. Never execute untrusted SQL just because source was
generated from it.

## Platform setup

See the [platform and console guide](https://github.com/itskenzylimon/quickeydb/blob/main/example/README.md#platform-setup-and-console-diagnostics)
for Xcode first-launch components, CocoaPods, the example’s single Android Kotlin
DSL configuration, secure-storage host dependencies, and Flutter’s upstream web
hot-restart loader fix. Package tests and native builds should run sequentially
when they share a checkout’s generated native assets.

## Run the example in Chrome

Run from **example/**; the package directory itself has no lib/main.dart:

```sh
cd plugins/external/quickeydb/example
flutter pub get
dart run tool/setup_web.dart
flutter run -d chrome --web-port 8080
```

The checked-in worker/WASM assets are ready for the resolved browser backend.
Re-run setup after changing SQLite/backend dependency versions. The setup script
compiles the official worker directly and downloads the matching SQLite WASM,
avoiding the upstream build-runner setup failure seen on the current SDK.
The browser backend requires one connection per persistent database; initialization
sets that option automatically. Storage persists in IndexedDB by origin, so keep
the hostname and port fixed. Use localhost or HTTPS for browser secure storage.

`privateStorage` is a virtual namespace on web; it cannot hide data from browser
developer tools or apply OS file permissions. AES-GCM still protects selected
values. Web key storage is origin-bound browser storage, not native Keychain or
Keystore, and cannot protect against malicious scripts running in that origin.
SQLCipher full-file encryption and asset DB import remain native-only. JavaScript
Chrome builds are tested; the secure-storage plugin does not yet support a full
Dart/Wasm application build.

## Setup and a complete example

Until 3.0.0 is published, use `quickeydb: {path: ../quickeydb}` with this
checkout. The release constraint below becomes available after publication.

For the 3.0.0 release, add the dependency and run `flutter pub get`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  quickeydb: ^3.0.0
```

A converter's `encode` reads a row into a model, `decode` writes a model with
optional nested relationships, and `decodeTable` writes just its table columns.
This is a complete `lib/main.dart` example using a short-lived in-memory DB:

```dart
import 'package:flutter/material.dart';
import 'package:quickeydb/quickeydb.dart';

class Task {
  const Task({this.id, required this.title});
  final int? id;
  final String title;
  factory Task.fromMap(Map<String?, dynamic> map) =>
      Task(id: map['id'] as int?, title: map['title'] as String);
  Map<String, Object?> toMap() => {'id': id, 'title': title};
}

class TasksDao extends DataAccessObject<Task> {
  TasksDao() : super('''
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL
)
''', converter: Converter<Task?>(
    encode: Task.fromMap,
    decode: (task) => task!.toMap(),
    decodeTable: (task) => task!.toMap(),
  ));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await QuickeyDB.initialize(
    dbName: 'demo', dbVersion: 1,
    dataAccessObjects: [TasksDao()], persist: false,
    conflictAlgorithm: ConflictAlgorithm.abort,
  );
  late String message;
  try {
    final tasks = db.get<TasksDao>()!;
    final id = await tasks.create(const Task(title: 'Learn QuickeyDB'));
    message = (await tasks.find(id))!.title;
  } finally {
    await db.close();
  }
  runApp(MaterialApp(home: Scaffold(body: Center(child: Text(message)))));
}
```

Desktop FFI initialization is automatic. `persist: false` now uses an in-memory
DB on mobile and desktop. In an actual app, keep the database open for its owner
and await pending operations before `close()`. Initialize once, outside `build`.
Call `db.get<TasksDao>()` or `db<TasksDao>()` for the registered DAO instance.

## Queries and isolated scopes

The old fluent API still works. Use `query()` when building independent scopes:

```dart
Future<List<Task?>> search(TasksDao tasks, String title) async {
  return tasks.query()
    .where({'title': title})
    .order(['id'], 'DESC')
    .limit(20).offset(0)
    .toList();
}
```

Terminal methods consume query state **before awaiting**, including errors and
aggregates. You no longer need manual `clear()` after every query. The original
fluent builder still mutates itself while a chain is being constructed; use
separate `query()` instances for independent chains or concurrent callers.

| API | Behavior |
| --- | --- |
| `where({'title': value})` | Bound equality; null becomes `IS NULL`. |
| `where({'id >= ?': value})` | Explicit SQL operator with a bound value. |
| `where({'id IN (?, ?)': [1, 2]})` | Bound list values, flattened to placeholders. |
| `or({...})`, `not({...})` | OR and negated condition groups; equality shorthand works. |
| `find(id)`, `findBy(map)`, `first`, `last` | Nullable model; explicitly order predictable first/last results. |
| `all`, `toList()`, `take(n)` | `List<T?>`; converters may return null. |
| `toMap()` | Row maps with requested includes/joins. |
| `select(['title']).toMap()` | Strict projection; excludes unrequested columns. |
| `group([...])`, `having(sql)` | GROUP BY / raw HAVING; HAVING requires grouping. |

Keys, operator fragments, order/group expressions, and HAVING are trusted SQL
provided by your application. Bind user values; never interpolate them into SQL
fragments. Boolean groups follow SQL AND/OR precedence. OFFSET requires LIMIT;
negative limits/offsets throw. Empty IN lists and arbitrary expression parsing
are not normalized by the API.

## Writes, transactions, and conflicts

- `create(model)` / `insert(map)` return the primary-key value.
- `createAll` / `insertAll` run in one transaction and roll back on failure.
- `update(model)` uses the model's primary key; `updateAll(map)` uses pending filters.
- `delete(model)` / `destroy(id)` delete by key; missing model keys are rejected.
- `where(...).deleteWhere()` deletes matching rows and requires a filter.
- `destroyAll()` retains its legacy explicit whole-table meaning. Calling it with
  filters now throws rather than silently deleting unrelated rows.

Generated IDs are assigned to mutable insert maps for legacy callers. Immutable
input maps also work, and nested payload processing uses copies. Returned IDs do
not update immutable model objects; read the model again with `find(id)`.

Legacy insert conflict behavior remains REPLACE. New apps should choose
`conflictAlgorithm: ConflictAlgorithm.abort` on initialization or use the DAO's
`insertConflictAlgorithm` override. REPLACE may delete a conflicting row; it is
not equivalent to a conventional UPDATE.

DAO calls participate in `QuickeyDBImpl.transaction` through an async-local executor:

```dart
Future<void> renameTasks(QuickeyDBImpl db, TasksDao tasks) async {
  await db.transaction(() async {
    await tasks.where({'id': 1}).updateAll({'title': 'First'});
    await tasks.where({'id': 2}).updateAll({'title': 'Second'});
  });
}
```

Await every operation inside the callback; do not schedule work to outlive it.
For the underlying `db.database!.transaction((txn) async {...})`, use only `txn`
inside the callback. The wrapper's `db.executor` exposes its active executor for
custom SQL inside `db.transaction`. This keeps transaction ownership explicit.

## Aggregates and projections

`count()` and `ids` consume their query scope. `isEmpty`/`isNotEmpty` now have the
correct meanings. `pluck(['title'])` returns a flat list; multiple columns return
row-value lists. `pick(['title'])` returns `[value]`, or `[]` if there is no row.

`maximum` and `minimum` preserve SQLite's value type. `average` returns `double?`.
The legacy `sum` returns `int?`; a fractional result throws with guidance to use
the new `sumNumber(column)` (`num?`). This avoids silently truncating real values.
Existence and emptiness checks stop after the first matching row without model
conversion. Use projections for partial-row maps; a model converter requiring other fields
cannot reconstruct a complete model from an incomplete projection.

`toSql()` and the SQL builder's `fullSql` are diagnostics, not executable SQL.
They expose argument counts rather than secret bound values. Query logging is
optional with `debugging: true`; values and encryption keys are not printed by
the package's diagnostic helpers.

## Less-visible private files

`privateStorage: true` opts into an application-support `.quickeydb` subdirectory.
With an explicit `dbPath`, that subdirectory is created beneath the supplied
directory. On macOS/Linux, the directory is restricted to mode 0700 and the main
file to 0600. Mobile relies on the application sandbox. Windows uses the app's
support location; dot naming alone does not provide Windows ACL protection.

Default paths remain unchanged so old databases reopen. **Enabling private storage
changes the location; it does not move your existing database.** Plan an explicit,
backed-up relocation after closing all handles. `dbPath` consistently means a
directory; mobile now honors it. If an old mobile app supplied a path that used to
be ignored, its data remains at the old default location: locate that file before
switching paths. Asset import now reads/writes/opens the same resolved filename.
Existing database-name suffix behavior (`'$dbName.db'`) is retained.

Hidden locations and permissions reduce casual discovery; encryption protects
content. They serve different purposes.

## AES-GCM for sensitive values

Use a 32-byte random key stored separately in platform secure storage. A key is
never generated implicitly by the ORM or written beside the database. The
[notes example](https://github.com/itskenzylimon/quickeydb/blob/main/example/lib/main.dart) generates a key once and retains it in
`flutter_secure_storage`, with platform setup in [example/README.md](https://github.com/itskenzylimon/quickeydb/blob/main/example/README.md).

To protect selected columns, add `encryptedColumns: {'body'}` to a DAO constructor
and supply `valueEncryption` on initialization:

```dart
Future<QuickeyDBImpl> openProtectedDatabase(
  List<int> keyFromSecureStorage, List<DataAccessObject> daos,
) => QuickeyDB.initialize(
  dbName: 'protected', dbVersion: 1, dataAccessObjects: daos,
  privateStorage: true,
  valueEncryption: ValueEncryption(keyFromSecureStorage),
  conflictAlgorithm: ConflictAlgorithm.abort,
);
```

`ValueEncryption.generateKey()` creates suitable random bytes. Values use
AES-256-GCM with fresh nonces, authentication tags, a versioned envelope, and
table/column context binding. Equal plaintext values do not produce equal stored
ciphertext. A key verifier rejects missing/wrong keys on reopen before migrations.
Malformed or modified ciphertext throws; there is no fallback to plaintext when
a ciphertext envelope fails authentication.

- Protected values must be JSON-encodable; columns should store encrypted TEXT values and must not be primary,
  local foreign-key, or individually UNIQUE columns.
- Protected values are decrypted by the DAO, but randomized encryption cannot
  support SQL equality/range search, joins, ordering, or numeric aggregation on
  those values. Filter/sort after decryption, or use full-file encryption below.
- IDs, unprotected fields, schema, row counts, nulls, and indexes remain visible.
  This is **value encryption**, not whole-file encryption.
- Raw database access bypasses DAO encryption. Do not write plaintext into protected
  fields through raw SQL or introduce plaintext defaults/indexes for sensitive data.
- `allowPlaintextReads` defaults to false. Enable it explicitly only during a
  staged legacy migration, then reopen with false. Migration mode permits
  unmarked plaintext and therefore cannot authenticate those legacy values.
- Back up keys securely. Losing a key means losing access to its encrypted values;
  do not regenerate a replacement key to recover an existing database.

To migrate legacy values, register their protected columns, open with the key and
`allowPlaintextReads: true`, then `await dao.encryptExisting()`. It authenticates
existing ciphertext and rewrites plaintext in a transaction. Default compaction
checkpoints the WAL and runs VACUUM outside that transaction; call this migration
outside `db.transaction`. `compact: false` is available when managing compaction
separately. Secure deletion is enabled for value-encrypted connections.

Compaction cannot erase old backups, copies, filesystem snapshots, or guarantee
physical erasure on SSDs. It also does not encrypt unselected fields or provide
key rotation. Keep the original key available for recovery until you have verified
a migration and any backup policy.

## Full-file encryption through SQLCipher

For schema and all SQLite pages to be encrypted, supply a **SQLCipher-capable
`DatabaseFactory`** and `databaseKey: keyBytes` to initialization. QuickeyDB checks
`PRAGMA cipher_version` and applies a 32-byte raw key before schema access. An
ordinary Sqflite/SQLite backend throws instead of silently saving unencrypted data.

The default backends are ordinary SQLite; this repository does **not** bundle
SQLCipher binaries. Configure a compatible native backend in the consuming app
and test it on every target. See the upstream
[FFI encryption guide](https://github.com/tekartik/sqflite/blob/master/sqflite_common_ffi/doc/encryption_support.md)
and [mobile SQLCipher factory](https://pub.dev/documentation/sqflite_sqlcipher/latest/sqflite/databaseFactory.html).
Native SQLCipher encryption/reopen is not part of this checkout's local test
matrix; fail-closed behavior on ordinary SQLite is tested.

An existing plaintext SQLite file does not become encrypted by setting a key.
Use the chosen backend's explicit export/import migration into a new encrypted
file, verify reopening, then manage the old plaintext copy according to your
backup policy. Do not use `importDB` with `databaseKey` as an implicit conversion.

## Relations and performance

Read the [complete relation templates and SQL translations](https://github.com/itskenzylimon/quickeydb/blob/main/doc/RELATIONS.md):
HasOne, HasMany, BelongsTo, nested includes, inner joins, atomic nested inserts,
explicit many-to-many join tables, deletion constraints and unsupported cases.


Register each related DAO and declare SQL foreign keys. Relations are
`HasMany<ChildDao>`, `HasOne<ChildDao>`, and `BelongsTo<ParentDao>`. `includes` accepts
DAO types, DAO instances, and ProxyInclude helpers. HasMany hydration groups by
foreign key, HasOne matches the foreign key, and every requested include runs.
IN lists are chunked at 400 values; child results are no longer limited by parent
count. `joins` remains an inner join from a discoverable local foreign key.

For compatibility, nested singular keys retain the existing `toCamelCase` helper's
actual **snake_case** convention (`UserProfile` → `user_profile`); HasMany uses the
child table name. Use converters that understand these nested keys. Relation
writes insert the parent once and use one encompassing transaction.

Performance improvements include batched transactional writes, map-based relation
matching, strict projections, and incremental Memory writes. The tests include a
1,000-row transactional insertion diagnostic without a hardware-specific timing
assertion. Add application-specific indexes and use EXPLAIN QUERY PLAN for large
queries; the ORM does not automatically index arbitrary predicates.

## Migrations and compatibility boundaries

Additive schema rebuilds run in the version callback's existing transaction,
preserve explicit indexes/triggers, and roll back failures. Schema parsing supports
case variations, simple quoted identifiers, nested defaults, and single-column keys.
Composite keys and arbitrary SQL grammar remain outside automatic metadata support.

Removing/renaming columns, downgrading a database, or rebuilding a referenced table
with foreign-key enforcement enabled requires an explicit `onUpgrade` or
`onDowngrade` callback. The automatic path rejects these cases instead of guessing
and risking data loss. Added required columns still need valid defaults/backfills.
Use the callback's database directly; never manually BEGIN/COMMIT inside it.

`foreignKeys` defaults to false to retain old connection behavior. New apps can
choose `foreignKeys: true`; enforcement is configured before the migration
transaction. Test populated, backed-up databases before changing schemas.

These intentional safety changes affect callers relying on old bugs: filtered
`destroyAll` now throws, strict `select` excludes other fields, failed destructive
migrations throw, initialization while another handle is open throws, and Memory
missing bool values now return null. Existing public entry points and ordinary
fluent calls remain available. `close()` permits explicit reinitialization.

## Memory helper

Import `package:quickeydb/memory/memory.dart`. The legacy
`await Memory().instance(memoryKey: 'settings')` works. Optional `encryption` takes
a `ValueEncryption`; `storagePath` selects a native backing location. Reopening a
namespace must use the same path and key configuration.

Typed setters/getters cover strings, integers, doubles, booleans, dates, maps, and
lists. Setters now await the IDB transaction commit. `flush()` explicitly waits for
pending writes and `close()` flushes then closes the handle. Writes persist only
changed/deleted keys rather than rewriting the whole namespace. Concurrent initial
opens share one future. TTL expiry, missing bools, and expired-entry metadata have
consistent handling; corrupted records surface errors.

Unconfigured namespaces retain the old shifted format for compatibility; this is
obfuscation, not encryption. Open a legacy namespace with
`encryption: ValueEncryption(key, allowPlaintextReads: true)` and call
`encryptExisting()` to rewrite its active entries as authenticated ciphertext.
Memory namespace/type/timestamp metadata remains visible. It does not flush or
cache ORM query results. Native and browser IDB imports are separated. The
Chrome Memory gallery has been checked with persistence across reloads; full
Wasm and other browser/device combinations remain unverified.

## Example, testing, and contribution

The [reactive example gallery](https://github.com/itskenzylimon/quickeydb/blob/main/example/README.md) contains 19 sections with
copyable API/view/model source and inline results. It is built reactively by
[Activity](https://pub.dev/packages/activity), using named routes and shared state.
The docked bottom console shows operation history and optional development SQL.
Secure startup reuses the existing notes database and key. The SQL generator
never executes its input. Unused legacy Task/User template files have been removed.

Tests are grouped by [feature and key function](https://github.com/itskenzylimon/quickeydb/blob/main/test/README.md), with common
fixtures under `test/support/`. Generated DAO fixtures compile as part of analysis
and have an integration test for real CRUD and foreign-key enforcement.

```sh
flutter pub get
flutter analyze
flutter test
# Generator-only checks without Flutter/native build hooks:
dart --packages=.dart_tool/package_config.json test/codegen/sql_generator_contract.dart
cd example
flutter pub get
flutter test test/gallery
dart run tool/test_web.dart
```

See [Observations.md](https://github.com/itskenzylimon/quickeydb/blob/main/Observations.md) for implementation status and remaining
limits, and [CHANGELOG.md](https://github.com/itskenzylimon/quickeydb/blob/main/CHANGELOG.md) for compatibility notes. Contributions
should include meaningful regression tests. License: [Apache 2.0](https://github.com/itskenzylimon/quickeydb/blob/main/LICENSE).

## Development SQL diagnostics

```dart
import 'package:flutter/foundation.dart';
import 'package:quickeydb/quickeydb.dart';

final logging = QueryLogging(
  enabled: true, // Still automatically disabled in profile/release builds.
  includeSql: true, // Opt in to actual SQL templates; bound values are omitted.
  onQuery: (event) => debugPrint(event.toString()),
);
final db = await QuickeyDB.initialize(
  dbName: 'notes', dbVersion: 1, dataAccessObjects: [NotesDao()],
  queryLogging: logging,
);
// Example: SELECT "notes".* FROM "notes" WHERE "title" = ?
// Event also includes UTC time, elapsed duration, parameter count and success.
// SELECT/UPDATE/DELETE include row counts; INSERT does not mislabel its row ID.
logging.includeSql = false; // Future events contain summaries only.
logging.enabled = false; // Stop all diagnostic events immediately.
```

Defaults are silent. `debugging: true` remains a legacy debug-only summary switch.
Observers cannot change a query's success/failure, and error messages/parameter
values are not included in events. SQL expressions you write can contain literals:
use bound values and never embed secrets in SQL. This is DAO statement logging,
not a full database audit: direct raw SQL, opening/migration work and encryption
maintenance are outside its scope. A successful statement can still belong to a
transaction that later rolls back. Do not treat a log line as a commit receipt.
The example only enables collection in debug builds; its Raw SQL switch affects
future statements, with a bounded 120-event history.

## Updates, migrations and compatibility

3.0.0 follows published **1.2.0+8**, not the unpublished intermediate checkout
version. See [CHANGELOG.md](https://github.com/itskenzylimon/quickeydb/blob/main/CHANGELOG.md) for the complete release delta and
[the migration guide](https://github.com/itskenzylimon/quickeydb/blob/main/doc/MIGRATING_TO_3.md) for before/after code, schema upgrades,
conflict/FK behavior, encryption recovery, browser assets and integration conflicts.
The release checklist records validation and remaining gates; preparation does not
mean an artifact has already been published.

## Documentation approach

The copyable schema → DAO → query → SQL examples take teaching inspiration from
[GORM documentation](https://gorm.io/docs/), with original QuickeyDB Dart code.
See [relation attribution and capability limits](https://github.com/itskenzylimon/quickeydb/blob/main/doc/RELATIONS.md#context-and-attribution).
GORM features are not automatically QuickeyDB features.

## Support, gifts and community

Help fund and sustain open-source work.
[GitHub community](https://github.com/itskenzylimon) ·
[Report an issue](https://github.com/itskenzylimon/quickeydb/issues) ·
[Blog & Articles](https://medium.com/@itskenzylimon) ·
[QuickeyDB on pub.dev](https://pub.dev/packages/quickeydb).
