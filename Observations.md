# Workflow documentation follow-up — 23 October 2026

- Added a feature cookbook covering scopes, projections, keyset paging, atomic
  replacement, bulk updates, migrations/indexes, encryption/key recovery, Memory
  shutdown and diagnostics, with clear expected results and failure cases.
- Added WorkItems/pageBefore/replaceInbox/archiveBefore as copyable source, used
  unchanged in the gallery's two additional recipes. Real SQLite contracts check
  insertion between pages, rollback after deletion, unrelated-row preservation,
  scope isolation and displayed-source synchronization.
- Expanded both repository/example ignore rules for recursive output, private
  configuration and local databases/sidecars; retained intentional worker/WASM,
  branding, screenshots and source. Existing tracked files were not untracked.

Verification: 67 package tests and clean analysis; 13 host gallery tests, 4 Chrome
worker/gallery tests and the production web build pass with Activity's own router.
Browser recipe/model source was inspected and captured in gallery-workflows.jpg;
no browser warnings/errors were captured. Minimum-SDK/device/hosted-CI execution
remain separate release gates. Earlier totals and routing-engine descriptions
below refer to their dated preparation snapshots.

---

# 3.0.0 publication preparation — 20 October 2026

- Verified latest pub.dev version is 1.2.0+8; set requested version to 3.0.0.
- Added debug-only parameterized DAO events with redacted values and isolated
  observers; example console now docks at the bottom with SQL/Output tabs.
- Added aflare.space funding, configurable gift/coffee/social slots, GitHub and
  Activity pub.dev credit. Placeholder destinations await manual configuration.
- Expanded relation SQL templates and migration/release guides under doc/.
- Removed unused legacy example templates, mockito and historical screenshots.
- Corrected SDK floor to Dart 3.9 / Flutter 3.35, required by minimum idb_shim.
- Disclosed AI assistance. Publication requires the companion Activity release,
  a tested public example dependency, maintainer review/commit and final dry run.
- Validation: analyzer clean; 62 package, 13 example host and 4 Chrome worker
  tests passed; production web build passed. Pub dry run reports only the two
  repository-state warnings plus the requested version-jump hint (1 MB archive).
- No publication or native device verification is claimed here.

# Reactive views and inline source/results follow-up — 19 October 2026

The example now depends on the sibling Activity development package. Its app
owns a GalleryController and ActivityRouter: registered reactive values hold
notes, stats, results, terminal runs, errors, appearance and operation summaries;
activeAsync tracks database work. Local input controllers remain screen state.
Named section URLs support direct links, and saved notes open a nested typed
read/detail route that returns a String to the CRUD terminal. Tests verify draft
retention, invalid-section redirection and controller/database ownership.

Source panels now offer API, View and connected Model/DAO tabs. Complete CRUD
and query views use the actual GalleryController/Note APIs. Related application
contexts show their own generated DAO definitions. Read-only inline terminals
show actual data, errors, running state and elapsed time, with output copying.
“All notes” includes live ascending/descending ordering, ID/title sorting,
projection, limit and offset controls; its source includes additional query
variants. Outputs remain associated with the section that started the work.

Validation: clean example analysis, **12 host tests**, **4 Chrome worker tests**,
and a release web build passed. Four complete CRUD/query/list/controller sample
files were extracted from the inline strings and analyzed with **no issues**.
The relocated browser rollback button was also verified by a focused passing
regression after scrolling synchronization was updated. The example SDK floor is
now Dart **3.7.2 / Flutter 3.29** because it uses Activity; the QuickeyDB library's
SDK floor remains unchanged. Native platform builds were not repeated.

Earlier gallery validation entries below record the previous stage.

# Activity-style gallery follow-up — 19 October 2026

The QuickeyDB example now follows Activity's Material 3 gallery design: grouped
search, sidebar/drawer navigation, compact header, API badges, green overview,
preview/source cards, do/don't guidance, theme/accent controls and a bounded live
operation console. Existing startup, saved notes, encryption keys and SQLite
worker assets are preserved.

The example expands from 12 to 19 sections. New playgrounds cover pagination,
aggregates/projections, conflict policies and scoped bulk writes. Conflict and
bulk probes deliberately roll back; host and Chrome worker tests verify existing
records survive. The relation guide supplies complete map DAOs and standalone
usage. Migration/index generation reads the current version and returns source
without modifying schema; query-plan inspection is read-only. Six application
contexts explain repositories, debounced drafts, outboxes, replaceable catalog
caches, search and expiring preferences. Tips include a session checklist of 12
integration tasks. Code and docs identify required application services/schemas.

Validation with Flutter 3.47.7 / Dart 3.13.5:

- Example analysis: **no issues**.
- Complete example host suite: **10 passed**. Coverage includes all 19 sections
  at desktop/phone widths, CRUD, encrypted pagination, aggregates, all three
  conflict policies, bulk rollback, read-only migration plans and appearance.
- Real Chrome SQLite-worker suite: **4 passed**, including persistence/reopen,
  key rejection, Memory/generation, CRUD/mobile navigation and the new probes.
- Release web build with local web resources: **passed**. Native platform builds
  were not repeated for these example UI changes.
- Complete Note/NotesDao and Projects/Tasks DAO/usage samples were assembled and
  analyzed against the package API: **no issues**.

# Web startup follow-up

Chrome startup is now supported through a conditional SQLite/WASM backend with
IndexedDB persistence. Native filesystem, platform detection, and chmod calls
are isolated in storage_io.dart; the browser path uses a virtual namespace and
single-instance persistent connections. The example's missing-key check uses
QuickeyDB.databaseExists instead of File/path_provider. Startup errors now retain
the actual error and stack trace rather than a generic platform message.

The deprecated web bootstrap was replaced and CanvasKit loads locally. Worker
and WASM assets were regenerated for the resolved backend. The example's
setup_web.dart compiles the official worker directly because upstream setup's
build-runner failed on this SDK. test_web.dart exercises actual Chrome persistence
and encrypted data. Browser refresh persistence was also checked interactively.

Follow-up verification: analyzer clean; native package 33 tests passed; example
native widget test passed; actual Chrome worker/encryption/reopen regression passed;
web debug build succeeded. The replacement setup helper compiled the official
worker and fetched the matching WASM successfully. Manual browser save/reload also
retained the encrypted note and browser-stored key.

Earlier entries below calling browser ORM support unavailable describe the
pre-follow-up implementation. Native SQLCipher, Windows ACLs, browser key-storage
threats, and full Dart/Wasm secure-storage compatibility remain separate limits.

# QuickeyDB implementation status

The review below was applied to implementation on 16 October 2026. It is retained
as the historical rationale; **its original validation baseline and statements
that changes are not applied describe the pre-implementation review only**.

## Applied changes

| Review findings | Implemented behavior |
| --- | --- |
| 1: initialization paths | Mobile/desktop use one resolved path; asset existence, copy, and open agree. Runtime argument/registration checks replace assertions. |
| 2–3: migrations | No nested BEGIN/COMMIT or in-transaction PRAGMA toggling; additive rebuilds preserve indexes/triggers and autoincrement sequence; destructive/reference-sensitive changes require explicit callbacks. |
| 4–6: query state/results | Terminal methods snapshot and consume state, query() isolates scopes, emptiness is fixed, pick/projections and aggregate types are corrected with a compatible sumNumber addition. |
| 7: scoped deletion | Legacy unfiltered destroyAll remains; filtered misuse throws; deleteWhere is explicit. |
| 8: writes | Configurable conflicts retain legacy REPLACE default, bulk/relation writes are atomic, parent inserts occur once, nullable-key converters are normalized. Generated IDs still reach mutable input maps. |
| 9: includes | All includes run; children group by foreign key without parent-count truncation; IN queries are chunked. |
| 10–11: SQL/diagnostics | NOT/null/OR handling, bounds, strict projections, redacted diagnostics, and safe logging observers replace previous broken paths. |
| 12: schema | Case-insensitive parsing, simple quoted identifiers, default-expression splitting, corrected nullability, immutable metadata and structural equality. Unsupported composite keys fail explicitly. |
| 13: platforms | Duplicate web ORM code forwards to the native API; Memory IDB imports are conditional. The ORM still has no browser backend. |
| 14–15: Memory | Shared initialization, incremental committed writes, flush/close, expiry metadata, nullable booleans, corruption errors, opt-in authenticated encryption and legacy value migration. |
| 16–17: lifecycle/tests | Explicit close/reinitialize and transaction executor routing, direct dependencies, supported imports, substantive SQLite/Memory/example tests. |

## Added storage protection

- Opt-in application-support private directory, with POSIX 0700 directory / 0600
  main-file permissions on macOS/Linux; existing locations remain the default.
- Versioned AES-256-GCM envelopes with random nonces, authenticated table/column
  context, and application-supplied keys. Key markers reject wrong/missing keys
  before migration. Memory also authenticates encrypted values before reopening.
- Legacy plaintext can be migrated explicitly. DAO compaction checkpoints/VACUUMs
  after the transaction; existing external backups/snapshots cannot be erased by
  this operation.
- A SQLCipher-capable factory plus databaseKey enables full-file backend integration;
  ordinary SQLite fails closed. Native SQLCipher binaries are not bundled or
  integration-tested here. Sensitive-column encryption is tested on real SQLite.
- The example retains its key in platform secure storage and uses a distinct DB.

## Remaining boundaries and compatibility decisions

The Dart 3.1 public baseline remains; newer syntax requiring a higher language
version was not imposed on existing consumers. Default path and insert conflict
behavior remain. Fixes intentionally reject unsafe old behavior such as filtered
destroyAll, destructive guessed migrations, and replacing a live singleton.

The schema reader is not a general SQLite parser. Composite keys, arbitrary DDL,
column renames, destructive migrations, full-text/virtual-table metadata, and
foreign-key-safe complex rebuilds require explicit application migrations.
Platform builds of the ORM, native secure-store installation, Windows ACLs, browser/Wasm IDB,
and actual SQLCipher backend builds are separate platform integration concerns.
Raw SQL bypasses value encryption. Protected columns cannot retain ordinary
SQL search/index/unique/ordering semantics; schema and unprotected fields remain
visible. Key rotation and secure deletion of historical copies are not supplied.
The singleton still represents one database at a time, and callers must finish
pending operations before close. Legacy fluent chain construction is mutable;
use query() for independent scopes. Transaction callbacks must await their work.

## Final verification

- Package tests: **33 passed**, with real assertions (the original empty tests
  have been replaced).
- Example widget test: **1 passed**, covering encrypted note creation/readback.
- Analyzer: no issues after final style cleanup; README Dart snippets were assembled
  and included in analysis.
- 1,000 inserts in one transaction: approximately **90 ms** on this local macOS
  test host, without a timing assertion or claim of cross-platform throughput.
- Tests cover legacy reopening/default conflicts, resolved-path asset import, query isolation, aggregates,
  projections, bulk rollback, relation loading/writes, migration rollback and
  autoincrement/index/trigger retention, encryption/key rejection/tampering,
  plaintext migration/compaction, Memory TTL/durability, and concurrent close.
- Actual SQLCipher binaries, native secure-store installation, and the full OS/web
  matrix remain unverified; ordinary SQLite's encryption fail-closed path is tested.

See [test/README.md](test/README.md) for the feature-organized suite and
[example/README.md](example/README.md#tests-by-feature) for gallery coverage.

---

## Original review (historical)

# QuickeyDB code review observations

Reviewed on **16 October 2026** against commit
`23fdc2074cb4a910bdce939235de69174debf5cb` and the source present during validation.
Scope: native/web entry points, DAO/query building, schema parsing and migrations,
relations, converters, logging, the separate Memory helper, and existing tests.

This change updates documentation only. Implementation and dependency upgrades
below are recommendations, not applied fixes.

## Validation baseline

- Package version: `1.2.1+9`; SDK constraint: `>=3.1.0 <4.0.0`.
- Installed Dart SDK: **3.13.5 stable**, macOS arm64.
- `flutter analyze --no-pub`: **8 issues** — **2 warnings** (duplicate imports) and
  **6 infos** (undeclared direct dependencies, implementation import, example style).
  No analyzer errors.
- `flutter test --no-pub`: **8 passed**, but all eight test bodies in
  `test/widget_test.dart` are empty. This establishes no ORM behavior coverage.
- Three temporary in-memory SQLite regression probes all failed against expected
  behavior, confirming the defects in findings 4–6 below. The probes were removed
  after review; no failing tests were added to the package.
- README Dart snippets were assembled with shared imports/model declarations:
  **analyzer: no issues**. A temporary in-memory SQLite smoke test passed for
  model creation/readback, filtered queries, count/pluck, update/updateAll, deletion,
  and raw transaction writes. Temporary verification files were removed.
- No Android/iOS, Windows/Linux, browser/Wasm build matrix, persisted upgrade test,
  durability benchmark, or published release version was verified. Other findings
  are source-inspection conclusions and are labeled with their triggering paths.

## Initialization, migrations, and data integrity

### 1. High: computed mobile path and persistence mode are ignored

**Source:** `lib/quickeydb.dart` and `lib/quickeywebdb.dart`, `initialize`.

Both mobile branches calculate `databasePath` from `dbPath`/`persist` but then open
`'$dbName.db'` instead. Consequently mobile `persist: false` does not select an
in-memory database and `dbPath` does not control the actual opened location.
Asset import checks `databasePath` but writes bytes to `File(dbPath!)`; `dbPath` is
otherwise treated as a directory. An omitted import path can throw, and a supplied
one may refer to a different location from the database subsequently opened.

**Improve:** define directory versus full-file-path semantics once, use a path
joining utility, copy assets to the resolved database file, create its parent,
and pass the exact same path to existence checks and opening. Reject incompatible
`importDB`/in-memory combinations with runtime validation.

**Verify:** default/custom directories, paths with spaces, first/subsequent asset
imports, missing assets, and in-memory mode on both native branches.

### 2. High: migration transaction handling conflicts with version callbacks

**Source:** `lib/configs/migration.dart`, `force`; initialization version callbacks.

Upgrade/downgrade callbacks call `Migration.force`, which executes raw
`BEGIN TRANSACTION`/`COMMIT` even though Sqflite already wraps those callbacks in a
transaction. It has no explicit rollback/finally restoration. It also attempts to
toggle foreign-key enforcement inside the transaction. Sqflite documents its
[version-callback transactions](https://pub.dev/packages/sqflite#transaction), and
SQLite documents that changing `foreign_keys` inside a transaction has no effect
in its [PRAGMA reference](https://www.sqlite.org/pragma.html#pragma_foreign_keys).

**Improve:** use the callback's existing executor/transaction boundary; introduce
explicit ordered version migrations and a deliberate connection configuration
policy. Restore any outside-transaction state on failure and propagate the error.

**Verify:** upgrade/downgrade a populated file, fail the data-copy step, reopen,
and check both data and PRAGMA state. Test callbacks through normal database open,
not only direct calls to `force`.

### 3. High: schema rebuilds can discard data and database objects

**Source:** `lib/configs/migration.dart`, `force`.

Any differing SQL text triggers a table rename/recreate/copy/drop cycle. Only
same-named columns are copied: renames lose values, required new columns without
defaults can reject copying, and no common columns produce an invalid column list.
Standalone indexes and triggers are not recreated. Downgrades use the same process
without an explicit preservation policy. A formatting-only difference can rebuild
a table unnecessarily.

**Improve:** prefer explicit versioned migrations with column mappings/backfills,
index/trigger management, row-count/integrity checks, and rollback. Use metadata
comparison where automatic migration remains supported. Make destructive changes
explicit and separately reviewable.

**Verify:** renamed/removed/added columns, changed defaults, no overlapping columns,
indexes, triggers, references, and recovery after every failed step.

## DAO and query correctness

### 4. High: singleton DAO query state leaks between operations

**Source:** `lib/configs/data_access_object.dart`, query fields, aggregate methods,
`ids`, `destroy`, `destroyAll`, `toMap`, and `clear`.

DAO retrieval returns a shared instance. Builders mutate fields on that instance;
several terminal methods never clear them, and `toMap` clears only after success.
An awaited query can leave a filter/limit behind. Concurrent queries additionally
share relation and join state, which remains in use after the initial SQL await.

**Reproduced:** after inserting two rows, `where({'id': 1}).count()` returns 1,
but the subsequent unfiltered `toList()` returns only row 1 instead of both rows.

**Improve:** separate stateless DAO metadata from an immutable per-query object.
Snapshot all execution state before awaiting. As an interim fix, use `try/finally`
cleanup consistently, while documenting that this alone cannot make a shared
mutable builder concurrency-safe.

**Verify:** independent sequential aggregates/finders, failed SQL, interleaved
queries, nested includes, and separate consumers sharing a DAO.

### 5. Medium: emptiness checks are inverted

**Source:** `lib/configs/data_access_object.dart`, `isEmpty` and `isNotEmpty`.

`isEmpty` returns `(await count())! > 0`; `isNotEmpty` negates it.

**Reproduced:** a newly opened empty table reports `isEmpty == false`.

**Improve:** return a count-zero or explicit existence result, with the query
cleanup policy from finding 4. Prefer `EXISTS` when checking large tables.

**Verify:** empty/populated tables and filters that match zero/one row.

### 6. Medium: projection and aggregate return contracts can throw

**Source:** `lib/configs/data_access_object.dart`, `pick`, `pluck`, `select`,
`maximum`, `minimum`, `sum`, and `_copyQueryWith`.

`pluck` flattens a one-column result. `pick` returns its first element under a
`Future<List<dynamic>>` signature; this may be a scalar or null. Aggregates cast
MAX/MIN/SUM to `int?` even when SQLite returns real numbers or text. `select`
appends selected columns after `table.*`, so it does not restrict selected data.

**Reproduced:** `pick(['label'])` on one string row throws
`String is not a subtype of FutureOr<List<dynamic>>`.

**Improve:** define distinct scalar/row/list result APIs and empty-result behavior;
parameterize supported aggregates or return `num?` where appropriate. Honor explicit
projection instead of always selecting `table.*`.

**Verify:** zero/one/many rows, one/multiple selected columns, int/real/text columns,
null aggregate results, and projection maps that exclude unrequested columns.

### 7. High: filtered bulk deletion silently deletes every row

**Source:** `lib/configs/data_access_object.dart`, `destroyAll` and `updateAll`.

`destroyAll` constructs DELETE without `_whereQuery`, even if callers previously
set a filter. `updateAll` does use filters, creating inconsistent chain semantics.
Neither provides an explicit all-rows guard.

**Improve:** either apply the query conditions or reserve an unmistakable
`truncate`/all-rows API and reject filtered calls. Separate scoped deletion from
whole-table deletion, clear state consistently, and return typed affected counts.

**Verify:** scoped deletion preserves unrelated rows, no-match deletion affects
zero rows, and explicit whole-table deletion removes all rows.

### 8. High: inserts replace on conflict and multi-row writes lack atomicity

**Source:** `lib/configs/data_access_object.dart`, `insert`, `createAll`, `insertAll`,
`update`, and nested relation persistence.

`insert` always uses REPLACE, irrespective of the exposed conflict constants.
Replacement can delete a conflicting row; it is not an ordinary field update
([SQLite conflict behavior](https://www.sqlite.org/lang_conflict.html)). Bulk
methods perform individual writes without a shared transaction. Relation branches
call the master insert during iteration and may reach another insertion after
processing, depending on missing payloads or multiple relation declarations.
Input maps are also mutated by relation removal and generated-key assignment.

**Also reproduced during README verification:** `update` casts `decodeTable` to
`Map<String, Object?>`; a converter returning the advertised nullable-key map
`Map<String?, dynamic>` throws even with valid String keys. Normalize with a
validated copy instead of relying on a runtime generic cast. The README converter
returns `Map<String, Object?>` to satisfy the current implementation.

**Improve:** accept an explicit conflict policy with a conservative default,
insert the parent exactly once, persist children through the same transaction,
return a documented ID/model result, and copy caller payloads. Reject missing
primary keys for update/delete before execution.

**Verify:** duplicate unique values, existing foreign-key references, immutable
payloads, multiple relation declarations, absent nested payloads, and a later
child/batch write failing after earlier writes succeeded.

### 9. High: eager relation hydration attaches incorrect or incomplete results

**Source:** `lib/configs/data_access_object.dart`, `toMap` include loop.

- HasMany assigns the complete fetched association list to every parent rather
  than filtering by that parent's key.
- Multi-parent child queries use `.limit(primaryKeys.length)`, which can truncate
  legitimate children when a parent has several.
- HasOne compares child and parent primary-key fields rather than matching the
  child's foreign key to the parent's primary key.
- An unconditional `break` means only the first include is processed.
- Unregistered includes and missing relation metadata are forced-null dereferenced.

**Improve:** group children by foreign key, match each parent separately, remove
parent-count limits on child queries, handle every include, and validate metadata
before executing. Chunk large IN lists and avoid repeated linear scans.

**Verify:** two parents with different child counts, disjoint parent/child IDs,
zero children, multiple/nested includes, null references, and unknown DAO types.

### 10. Medium: SQL conditions are loosely typed and partially implemented

**Source:** `lib/configs/data_access_object.dart`, `where`, `or`, `not`,
`_whereQuery`, and `_copyQueryWith`; `lib/configs/sql_builder.dart`.

OR keys are appended verbatim without the equality shorthand used by WHERE.
Mixed AND/OR clauses receive no grouping; null equality does not become IS NULL.
`not` throws `UnimplementedError`. Conditions are stored by text key, so adding
the same condition twice overwrites its earlier value. `_copyQueryWith` casts
optional String overrides (`groupBy`, `having`, `orderBy`) to `bool?`, which would
throw if those overrides are supplied. Identifier escaping covers selected
keywords rather than arbitrary identifiers; raw fragments still require trusted
input. Limit/offset validation is incomplete across terminal methods.

**Improve:** model predicates and ordering as typed immutable structures with
explicit grouping, null/IN semantics, identifier validation, and ordered argument
lists. Implement or remove `not`; fix override selection with straightforward
nullable String logic. Bind values instead of interpolating user data.

**Verify:** nested boolean conditions, duplicate-column bounds, nulls, empty IN
lists, quoted identifiers, bad limits, and SQL/argument correspondence.

### 11. Medium: SQL diagnostic formatting and logging can introduce errors

**Source:** `lib/builder/quickey_builder.dart`, `fullSql`;
`lib/configs/logger.dart`.

`fullSql` force-unwraps a possibly null argument list and substitutes raw values
without quoting or handling question marks inside literals. Logging also
force-unwraps arguments, uses one shared Stopwatch across concurrent operations,
and discards futures produced by `whenComplete`; failed SQL/logging can lead to
additional unhandled asynchronous errors. Arguments may contain sensitive values.

**Improve:** log SQL and a separate redacted argument list, use a per-operation
Stopwatch, handle empty arguments, and attach logging to the awaited execution
path without changing its error semantics. Keep diagnostics distinct from SQL
execution; never execute the reconstructed debug string.

**Verify:** zero arguments, nulls, apostrophes, literal question marks, failing SQL,
concurrent timing, and logging enabled versus disabled.

## Metadata, platforms, and auxiliary storage

### 12. High: schema regexes cannot represent general SQLite DDL

**Source:** `lib/types/schema.dart`, `column.dart`, and `lib/configs/patterns.dart`.

Patterns are case-sensitive and assume simple identifiers and layout. `table` is
force-read from the first match, so valid forms such as CREATE TABLE IF NOT EXISTS
or quoted/lowercase names can fail or be misread. Composite keys, constraints,
and defaults containing punctuation are fragile. `isNullable` is set from
`contains('NOT NULL')`, reversing its apparent meaning. Schema equality compares
List objects by identity instead of contents; parsed fields are publicly mutable.

**Improve:** use explicit typed schema metadata and SQLite introspection
(`table_info`, foreign keys, indexes) for existing databases. If retaining a parser,
define and enforce its supported grammar with descriptive errors. Correct nullability
and use immutable collections with matching structural equality/hash semantics.

**Verify:** case/whitespace variants, quoted names, IF NOT EXISTS, composite keys,
constraints, expression defaults, and equivalent independently parsed schemas.

### 13. High for browser consumers: web entry points still depend on native code

**Source:** `lib/quickeywebdb.dart`, `quickeydb.dart`, `lib/memory/memory.dart`,
and internal conditional imports.

The web ORM entry point imports `dart:io` and native FFI and follows native platform
branches. Memory imports both browser and IO IDB backends unconditionally. Runtime
`kIsWeb` checks do not isolate unsupported library dependencies.

**Improve:** share a platform-neutral DAO/query layer, use conditional backend
imports with explicit capabilities, and choose a supported browser database backend.
Keep Memory and ORM platform claims separate. Verify JavaScript and Wasm builds;
future browser interop should follow the
[current Dart web approach](https://dart.dev/interop/js-interop/package-web).

**Verify:** compile minimal imports of each public entry point on each advertised
target, then execute actual storage reads/writes and reopening tests.

### 14. High for durable writes: Memory setters finish before persistence

**Source:** `lib/memory/memory.dart`, `_delaySave`, `_saveToIDB`, and CRUD methods.

Awaiting `_delaySave` only schedules a 300 ms Timer; it does not await IDB commit.
There is no flush/close method. Timer callback futures/errors are discarded.
Concurrent first calls to `instance` can initialize multiple stores because the
instance is cached only after initialization finishes. Save seriality and cache
snapshot ownership are not explicit, and each save scans/deletes/rewrites the
whole namespace instead of persisting the changed keys.

**Improve:** share an in-flight initialization future, expose `flush`/`close`,
serialize saves of immutable snapshots or individual dirty keys, and return a
persistence future with observable errors. Define consistency across handles,
isolates/tabs, shutdown, and namespace collisions.

**Verify:** immediate process exit after awaited setters, failed commit,
concurrent initialization/write/delete, repeated flush, and reopen with TTLs.

### 15. Medium: Memory encoding, null semantics, and TTL contracts need clarity

**Source:** `lib/memory/memory.dart` and `memorymodel.dart`.

The fixed shift cipher is trivially reversible and should not be called secure
encryption. `getBool` compares a nullable result with `'true'`, producing false for
a missing/expired key despite its `bool?` return type. Existing expired entries
are removed but then their old metadata is reused during upsert. Silent JSON-load
catch blocks hide corrupted records; typed getters do not verify stored type tags.

**Improve:** describe encoding honestly, use a secure-storage boundary when needed,
return null consistently for absence, treat expired upserts as fresh entries,
validate serialization/type tags, and surface recoverable corruption diagnostics.

**Verify:** absent/expired false values, non-ASCII round trips, malformed records,
wrong typed getter, zero/negative TTLs, and metadata after expiry/reinsert.

### 16. Medium: singleton lifecycle and nullable APIs obscure invalid states

**Source:** `QuickeyDB.initialize`, `getInstance`, `QuickeyDBImpl`, DAO lookup,
`lib/configs/relations.dart`, and relation controls.

Most required setup invariants are assertions with nullable arguments. Release
builds can proceed with invalid configuration. Duplicate DAO runtime types overwrite
registrations, simultaneous initialization can race, and reinitialization can
replace a handle without closing it. Closing the exposed database does not clear
the singleton. Nested code repeatedly force-unwraps registration and connection state.

**Improve:** validate configuration at runtime, use non-null initialized fields,
expose explicit async open/close lifecycle, reject duplicate DAO types, and return
descriptive errors for missing registrations or closed databases. Accept an
injected executor so DAOs can participate in transactions and tests without a
global connection.

**Verify:** invalid setup in release mode, duplicate/missing DAOs, concurrent opens,
reopen after close, multiple databases, and transaction executor routing.

### 17. Medium: dependency and test hygiene need a real baseline

**Source:** `pubspec.yaml`, `lib/memory/path_helper.dart`, public barrels,
`lib/types/conflicts.dart`, and `test/widget_test.dart`.

`path` and `sqflite_common` are imported directly but not declared directly.
`conflicts.dart` reaches into another package's `src`; Memory has duplicate imports.
The current eight passing placeholders neither import the ORM nor assert results.
The example and README cannot substitute for integration tests.

**Improve:** declare direct dependencies or import supported public re-exports,
remove copied/private dependency implementation where feasible, update lints after
checking SDK compatibility, and build a real test matrix. Start with the three
reproduced defects and data-integrity findings above; use temporary databases and
explicit fixture lifecycles. Add persisted migration and platform smoke tests.

## Dart style and feature modernization

The package language baseline is **3.1**, even on the installed 3.13.5 SDK.
Select features deliberately and increase the declared minimum only with a
consumer migration plan. Versions below were checked against
[Dart language evolution](https://dart.dev/resources/language/evolution).

| Feature | Minimum | Possible use |
| --- | --- | --- |
| Records, patterns, switch expressions, class modifiers | 3.0 | Typed SQL/argument results, predicate dispatch, exhaustive backend handling, intentional API inheritance. |
| Extension types | 3.3 | Distinct table/column identifiers; requires raising the baseline. |
| Wildcards and language-versioned formatter | 3.7 | Unused callback parameters and consistent new formatting. |
| Null-aware collection elements | 3.8 | Optional query/payload entries. |
| Dot shorthand | 3.10 | Context-typed enums and configuration values. |
| Private named initializing parameters | 3.12 | Simpler constructors with encapsulated fields. |
| Primary / concise constructors | 3.13 | Optional reduction of boilerplate in small metadata classes. |

These are opportunities, not a requirement to adopt every feature. The
[language versioning guide](https://dart.dev/language/versions) explains why a newer
installed SDK alone does not enable newer package syntax.

Compatible cleanup and API design priorities:

- Replace raw `Future`, raw DAO types, `dynamic` IDs/counts, and nullable map keys
  with explicit generics, typed IDs, and `Future<void>`/`Future<int>` results.
- Make query plans immutable; use `List<Object?>` for bound values and typed
  projections rather than unchecked scalar/list conversions.
- Remove redundant Completers that only wrap an existing future. Await database
  operations directly and use `try/finally` for resource/query cleanup.
- Separate DAO metadata, query execution, and relation hydration; deduplicate the
  native/web initialization libraries and obsolete commented alternatives.
- Prefer final fields/locals, const metadata, Dartdoc `///`, and small named
  functions. Replace runtime-type-name relation conventions with explicit metadata.
- Run `dart format` separately from behavior repairs, inspect `dart fix --dry-run`,
  and strengthen strict casts/inference/raw-types and discarded-future diagnostics.
- Do not mark user-extensible DAO/model classes final merely for style. Class
  modifiers and constructor changes can be public API compatibility decisions.
- Preserve the conservative SDK baseline unless a newer feature justifies raising
  the minimum Dart/Flutter versions. Test the minimum and chosen stable SDKs in CI.

## Suggested implementation order

1. Fix migration safety, mobile/import path handling, filtered deletion semantics,
   conflict policies, and atomic relation/bulk writes.
2. Introduce isolated query state; repair emptiness, projection types, aggregates,
   and relation hydration with targeted SQLite regression tests.
3. Repair schema metadata and executor injection, then lifecycle and diagnostics.
4. Isolate platforms and define Memory durability; add platform/upgrade coverage.
5. Establish a clean analyzer/test baseline, then perform compatible style cleanup
   and select any justified newer language features in separate changes.

**Final verification note:** README snippets pass analysis and the in-memory
smoke test described above. This does not verify every documented API, persistence
across process restarts, migrations, or other platforms.
