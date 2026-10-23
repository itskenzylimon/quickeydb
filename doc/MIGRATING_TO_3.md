# Upgrading from pub.dev 1.2.0+8 to 3.0.0

The last published release, verified against the pub.dev API on 20 October 2026,
is **1.2.0+8** (28 June 2023). The intermediate `1.2.1+9` checkout version was
not the published baseline. This major version includes the accumulated repairs
and new APIs documented in CHANGELOG.md. Test an upgrade on a backup first.

| Area | 3.0.0 behavior / action |
| --- | --- |
| SDK | Library and example require Dart >=3.9 / Flutter >=3.35, matching idb_shim 2.6.7+1. The example also requires the newer companion Activity APIs. |
| Initialization | One active database; await close before reopening. Invalid names, missing DAOs, duplicate DAO types and invalid versions fail early. |
| Browser | ORM selects SQLite/WASM automatically. Deploy matching worker/WASM assets. Memory uses a separate IDB backend. |
| Query state | Prefer `dao.query()` for each operation. Terminal methods consume legacy query state; do not share a mutable scope across async jobs. |
| Filtered deletion | `where(...).destroyAll()` now throws to prevent ignored filters. Use `where(...).deleteWhere()`. Unfiltered `destroyAll()` still deletes the table's rows. |
| Migration | Unsafe automatic changes fail rather than dropping data. Supply versioned `onUpgrade` and explicit `onDowngrade`; callbacks already run in SQLite's version transaction. |
| Conflicts | Legacy INSERT default remains REPLACE. Configure abort/ignore intentionally; REPLACE is not an in-place update and can trigger FK cascades. |
| Decimal aggregates | Use `sumNumber()` for REAL/decimal totals; integer `sum()` rejects a fractional result. Empty aggregates can return null. |
| Projections | `toMap()` for partial rows. Typed converters may require columns omitted by `select()`. |
| Relations | Correct FK grouping / nested atomic writes; singular nested keys follow model names. Audit converters that relied on incomplete old hydration. |
| Encryption | New opt-in column AES-GCM is not full-file encryption. Persist/recover the key separately; never generate a new key over an existing encrypted database. |
| Memory | Await setters, `flush()` and `close()`. TTL expiration and stored nulls now have consistent behavior. Memory and SQL do not share a transaction. |
| Diagnostics | Off by default. `QueryLogging` is debug-build-only, bound values omitted. Raw database/migration SQL is not intercepted. |

## Query and deletion changes

```dart
// Before: a shared DAO could retain another operation's filters.
// Now: independent scopes are explicit.
final recent = await notes.query().order(['id'], 'DESC').limit(20).toList();
final count = await notes.query().count();
// Before: filtered destroyAll could be misleading/unsafe.
await notes.query().where({'id': obsoleteId}).deleteWhere();
// Whole-table deletion remains an explicit, destructive operation:
// await notes.query().destroyAll();
```

## Additive migration template

```dart
final db = await QuickeyDB.initialize(
  dbName: 'notes', dbVersion: 2,
  dataAccessObjects: [NotesDao()], // CREATE TABLE must describe version 2.
  conflictAlgorithm: ConflictAlgorithm.abort,
  onUpgrade: (executor, from, to) async {
    if (from < 2) {
      await executor.execute(
        'ALTER TABLE notes ADD COLUMN archived INTEGER NOT NULL DEFAULT 0');
    }
  },
);
// Also run for fresh installations; onUpgrade does not run on a new database.
await db.database!.execute(
  'CREATE INDEX IF NOT EXISTS idx_notes_title ON notes(title)');
```

Use the callback's executor, not a globally accessed DAO, during opening. Version
callbacks are transactional; do not open another transaction inside them. Renames,
constraint changes and column removals need reviewed copy-table migrations,
backups and validation of row counts, FKs and indexes. Restore a consistent backup
of both data and keys when rolling back an application release; lowering a schema
version alone is not a rollback strategy.

## Existing plaintext → encrypted values

Add a recoverable 32-byte key and the DAO's `encryptedColumns`, explicitly allow
legacy plaintext only for the migration (see ValueEncryption API and README),
then run `await dao.encryptExisting()` outside an existing transaction. Review
backups, WAL files and old copies too; compaction cannot erase copies elsewhere.
Filtering, sorting, joining and aggregating protected columns is unsupported.
Do not change encryption context/table/column names without migrating ciphertext.

## Likely integration conflicts

- Keep native database name/path stable. Opting into private storage changes the
  directory; move a closed database deliberately instead of appearing to lose it.
- Keychain/secure-storage configuration and browser origin affect key recovery.
  Changing origin/domain can make existing browser data and keys inaccessible.
- Unique constraints + REPLACE + cascading FKs can remove related rows. Review
  insert policy and prefer update-by-primary-key when editing existing data.
- Deploy the worker and WASM from the resolved SQLite web package together.
  Rebuild the example assets after changing web dependencies.
- New Activity state/router APIs in the example are not in pub.dev 1.5.3+5. The
  companion Activity release must land before replacing the local path dependency
  with its tested public version. QuickeyDB's library has no Activity dependency.
- Custom raw SQL bypasses DAO encryption/diagnostics. Use bound arguments and the
  transaction's executor; do not query a shared database handle from inside its
  active raw transaction callback.

## Upgrade verification

Exercise the oldest supported schema → current version and fresh install on each
shipping platform. Verify reopen, missing/wrong key errors, rollback, relation
shape, foreign-key enforcement, conflict policy, empty results and web persistence.
See [release preparation](RELEASING.md) for commands and remaining release gates.
