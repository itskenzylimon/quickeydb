# Practical QuickeyDB workflows

[Package guide](../README.md) · [Gallery](../example/README.md) ·
[Ready source](../example/lib/workflow_recipes.dart) ·
[Executable contracts](../test/documentation/workflow_recipes_test.dart)

These examples explain how schema, query scopes, transactions and lifecycle fit
together. The new source file is an ordinary Dart DAO/repository helper: copy it
into an application and register `WorkItems()` in the application's single
`QuickeyDB.initialize` call. It needs no generator or Activity dependency.

## 1. Start with schema and ownership

The example table has an integer ID, title, bucket and archived flag. SQLite stores
Booleans as integers; use `0`/`1` explicitly. A Converter connects SQL maps to model
objects; this recipe deliberately uses map rows. For domain models, implement both
conversion directions and use `toList()` for complete rows.

```dart
final database = await QuickeyDB.initialize(
  dbName: 'work', dbVersion: 1, dataAccessObjects: [WorkItems()],
  conflictAlgorithm: ConflictAlgorithm.abort,
);
final items = database.get<WorkItems>()!;
await items.insert({'title': 'Review release', 'bucket': 'inbox'});
```

This is application startup code, not widget-build code. Keep one owner for the
handle, await pending work, and close it when that owner ends. The default remains
REPLACE for compatibility; choose abort explicitly when an ID conflict should
roll back rather than replace an existing record. Tests use temporary real SQLite.

## 2. Independent queries and bound values

```dart
final inbox = await items.query().where({'bucket': 'inbox', 'archived': 0})
  .order(['id'], 'DESC').limit(20).toMap();
final saved = await items.query().where({'bucket': 'saved'}).count();
final detail = await items.query().find(selectedId);
```

Each `query()` creates a separate scope. The inbox filter does not leak into the
count or detail lookup. Terminal reads consume a scope; start a fresh scope for
each logical query. Bind data values; never concatenate input into raw SQL.
Identifiers and predicate syntax are application-owned, not user-supplied strings.
`LIKE` has wildcard semantics even when bound: escape `%`/`_` if users expect a
literal search. Parameterization prevents SQL injection; it does not change search
semantics or make an unindexed scan fast.

## 3. Keyset pagination during concurrent inserts

```dart
final first = await pageBefore(items, pageSize: 20);
final cursor = first.isEmpty ? null : first.last['id'] as int;
final next = cursor == null ? <WorkRow>[] :
  await pageBefore(items, beforeId: cursor, pageSize: 20);
```

`pageBefore` orders by the unique ID descending and adds `id < ?` for subsequent
pages. Inserting a newer row between reads will not duplicate the old first page,
which can happen with offset paging. Stop when a page is empty or shorter than
the page size; do not restart from null after the end. A cursor is not a snapshot:
rows can still be deleted or change filters between reads. Offset remains useful
for small lists that need page numbers; choose a deterministic unique tie-breaker.

The helper selects only `id` and `title`, returning maps. Do not send projections
through a converter that requires missing columns. Page size is limited to 1–100
as an application policy, not an ORM limitation. The regression inserts a new row
between two reads and verifies IDs `[5,4]` then `[3,2]` with no duplicates.

## 4. Replace a dedicated inbox atomically

```dart
await replaceInbox(database, items, [
  {'id': 100, 'title': 'New inbox item', 'bucket': 'inbox'},
]);
```

The helper validates the bucket, then deletes only inbox rows and inserts their
replacements inside `database.transaction`. If an insert fails under abort policy,
the deletion is rolled back too. Saved rows in another bucket survive. Fetch and
validate remote data before entering the transaction; keep network requests out
of the transaction callback. Use this pattern for dedicated replaceable data,
never for deleting unsynced user edits indiscriminately.

The test intentionally conflicts with an existing saved row and checks that both
original rows remain. SQL atomicity covers this database's transaction executor;
it does not cover a Memory namespace, secure storage, filesystem writes or a
remote API call. Use an outbox/reconciliation design for cross-system work.

## 5. Bulk updates, explicit deletes and aggregates

```dart
final changed = await archiveBefore(items, cutoffId);
final remaining = await items.query().where({'archived': 0}).count();
final removed = await items.query().where({'archived': 1}).deleteWhere();
```

Read the returned affected-row count; zero rows may be a valid stale-record case.
A scoped deletion uses `deleteWhere()`. Unfiltered `destroyAll()` deletes the whole
table, and a filtered `destroyAll()` intentionally throws to avoid ambiguous data
loss. Avoid confirming a deletion before you know its exact scope. Counts and
aggregates need fresh scopes. Use `sumNumber` when fractional totals must be
preserved; the legacy integer `sum` retains its compatibility behavior.

## 6. Indexes and schema-to-DAO generation are separate steps

The SQL-to-DAO feature accepts ordinary CREATE TABLE input and returns Dart source;
it never executes SQL. Save the generated file, format/review it, and register the
resulting DAO. It does not infer domain models, eager-loading relations or indexes.

```dart
final output = const SqlDaoGenerator().generate('''
CREATE TABLE messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  channel_id INTEGER NOT NULL,
  body TEXT NOT NULL
);
''');
// output.source: MessagesDao class; output.registration: [MessagesDao()]
```

Put indexes in database configuration/migration callbacks, not in generator input.
For a channel history query, `(channel_id, id)` is a useful candidate to evaluate
with `EXPLAIN QUERY PLAN` against realistic data. Fresh installs and upgrades must
end with the same schema/index set. Increment dbVersion and apply ordered,
version-gated migration steps. Test reopening an existing database and rollback
on failure; do not treat deleting/recreating user data as a migration.
See [migration guidance](MIGRATING_TO_3.md) and [relations](RELATIONS.md).

## 7. Sensitive values, full files and key recovery

Configure `encryptedColumns` on the DAO and provide `valueEncryption` at database
initialization. Generate a key once with `ValueEncryption.generateKey()`, persist
it in an appropriate application-managed key store, and reuse it on reopen.
A newly generated key cannot decrypt old data. Backups need a tested key-recovery
policy; do not store the key beside the database or print it in diagnostics.

AES-GCM protects configured values and authenticates their context. Table names,
public columns, indexes and SQLite metadata remain visible. Encrypted values do
not support useful SQL search/order/aggregate operations. Full-file encryption
requires a compatible SQLCipher factory/key integration; hiding the path is not
encryption. Browser key storage has different protections from native secure
storage and cannot protect an unlocked application from its own scripts.

For existing plaintext, follow the explicit migration and backup process in the
[security/migration guide](MIGRATING_TO_3.md); verify raw persisted bytes and reopen
with the correct key, and require a wrong key to fail. Do not silently replace an
unreadable database with an empty one.

## 8. Memory, expiry and shutdown

Use Memory for separate small named values and optional TTL/encryption. Await
setters and reuse a named owner. Expired values disappear when read; TTL is not a
background timer or a sync mechanism. Null/missing values require an application
default. Use a dedicated namespace for encrypted drafts; preserve unrelated
preferences when clearing one key. Cancel debounce timers, save the latest draft
explicitly, and await pending writes before closing the owner.

Memory and SQLite do not participate in one transaction. Keep a relational record
and its consistency-critical metadata in SQLite together. The gallery's
**Draft autosave**, **Preferences and expiry**, and **Memory** pages show complete
lifecycle snippets and explain the ownership boundary.

## 9. Observe behavior without logging user data

Opt in to QueryLogging only for development; profile/release diagnostics are
disabled. Events expose parameterized SQL, operation/row counts and durations,
not bound values. A UI terminal that displays returned records is different from
a redacted SQL log: do not copy production user records into diagnostic output.
Measure query plans and round trips before changing transaction size or indexes.
A test timing is diagnostic, not a portable performance guarantee.

## Verification checklist

| Workflow | Check |
| --- | --- |
| Read | Empty table, quoted/unicode input, independent scopes, partial projection |
| Paging | Stable tie-breaker, inserted/deleted records, page boundaries |
| Write | Affected rows, conflicts, rollback, unrelated records survive |
| Upgrade | Fresh install, old schema reopen, failure rollback |
| Encryption | Correct/wrong key, tamper, raw bytes, key recovery |
| Memory | Awaited persistence, namespace isolation, TTL and shutdown |
| Browser | Matching worker/WASM assets, reopen, persistence policy and errors |

Run `flutter test test/documentation` for the canonical recipe contracts. See
[test map](../test/README.md) for integration coverage and
[release checks](RELEASING.md) for packaging/platform gates.
