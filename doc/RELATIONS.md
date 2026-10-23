# Relations: schema → DAO → SQL → result

QuickeyDB 3.0.0 has three primary relation declarations. They describe how to
load and insert connected records; SQL foreign keys enforce integrity. Register
every DAO once and enable `foreignKeys: true`. A declaration alone never creates
an SQL constraint or migration.

| Declaration | FK lives on | `includes()` result | Missing match |
| --- | --- | --- | --- |
| `HasMany<TasksDao>()` | tasks.project_id | `tasks: [map, …]` | empty list |
| `HasOne<ProfilesDao>()` | profiles.project_id | model-derived key: map | null |
| `BelongsTo<ProjectsDao>()` | tasks.project_id | model-derived key: map | null |

Singular keys come from the **model type**, converted to snake_case: a DAO of
`Project` produces `project`. A map model produces the legacy key
`map<string?, dynamic>`; named domain models are preferable for singular relations.
`HasOne` does not enforce uniqueness: add `UNIQUE(project_id)` in SQL. Otherwise
one matching row is chosen without a guaranteed ordering.

## Complete copyable schema and map DAOs

The following is a standalone starter. It deliberately uses maps to keep all
columns visible. For typed conversion, adapt the complete `Note`/`NotesDao`
example in the README and preserve the nested keys in `Converter.encode`.

```dart
import 'package:quickeydb/quickeydb.dart';

typedef Row = Map<String?, dynamic>;
Converter<Row?> rowConverter() => Converter<Row?>(
  encode: (row) => Map<String?, dynamic>.from(row),
  decode: (row) => Map<String?, dynamic>.from(row!),
  decodeTable: (row) => Map<String?, dynamic>.from(row!),
);
class ProjectsDao extends DataAccessObject<Row> {
  ProjectsDao() : super(
    'CREATE TABLE projects (id INTEGER PRIMARY KEY, name TEXT NOT NULL)',
    converter: rowConverter(),
    relations: [const HasMany<TasksDao>(), const HasOne<ProfilesDao>()],
  );
}
class TasksDao extends DataAccessObject<Row> {
  TasksDao() : super(
    'CREATE TABLE tasks (id INTEGER PRIMARY KEY, project_id INTEGER NOT NULL, '
    'title TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0, '
    'FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE)',
    converter: rowConverter(), relations: [const BelongsTo<ProjectsDao>()],
  );
}
class ProfilesDao extends DataAccessObject<Row> {
  ProfilesDao() : super(
    'CREATE TABLE profiles (id INTEGER PRIMARY KEY, project_id INTEGER NOT NULL UNIQUE, '
    'description TEXT, FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE)',
    converter: rowConverter(), relations: [const BelongsTo<ProjectsDao>()],
  );
}
Future<void> main() async {
  // In a Flutter application, call WidgetsFlutterBinding.ensureInitialized()
  // before opening a database that uses platform channels.
  final db = await QuickeyDB.initialize(
    dbName: 'projects', dbVersion: 1,
    dataAccessObjects: [ProjectsDao(), TasksDao(), ProfilesDao()],
    foreignKeys: true, conflictAlgorithm: ConflictAlgorithm.abort,
  );
  try {
    final projects = db.get<ProjectsDao>()!;
    final tasks = db.get<TasksDao>()!;
    final id = await projects.insert({
      'name': 'Release',
      // HasMany payload key is the target table name.
      'tasks': [{'title': 'Write tests'}, {'title': 'Review docs'}],
    }); // Parent and children are inserted in one transaction.
    final rows = await projects.query().where({'id': id})
        .includes([TasksDao, ProfilesDao]).toMap();
    final pending = await tasks.query().where({'done': 0})
        .includes([ProjectsDao]).toMap();
    print(rows); // tasks list; singular profile uses the map-model key.
    print(pending);
  } finally {
    await db.close(); // Application owner closes after pending work finishes.
  }
}
```

Use fresh scopes (`dao.query()`) for concurrent or independent work. Re-running
this starter adds another project; use a temporary database for experiments.

## HasMany: batched eager loading

```dart
final result = await projects.query().order(['id'], 'ASC')
    .limit(20).includes([TasksDao]).toMap();
// result[0]['tasks'] is a List of child maps, including every matching child.
```

Equivalent SQL shape (identifiers/whitespace may differ):

```sql
SELECT projects.* FROM projects ORDER BY id ASC LIMIT 20;
SELECT tasks.* FROM tasks WHERE project_id IN (?, ?, ?);
-- Bound arguments: the parent IDs, never SQL string interpolation.
```

Loading uses distinct non-null IDs in batches of at most 400. It avoids one child
query per parent. No parents means no child query. A parent limit applies to
parents, not to each child's list. The current include API does not provide
per-parent limits or custom child filters; query children explicitly for those.

## HasOne and BelongsTo: opposite FK directions

```dart
final owners = await projects.query().includes([ProfilesDao]).toMap();
final work = await tasks.query().includes([ProjectsDao]).toMap();
```

```sql
-- HasOne: parent IDs select child foreign keys.
SELECT projects.* FROM projects;
SELECT profiles.* FROM profiles WHERE project_id IN (?, ?);
-- BelongsTo: task foreign keys select project primary keys.
SELECT tasks.* FROM tasks;
SELECT projects.* FROM projects WHERE id IN (?, ?);
```

Includes preserve parents without matches. Typed converters must explicitly
accept an absent singular child. Keep parent primary keys / FK columns in
projections used with includes; removing them prevents matching records.

## Joins: one SQL statement, different semantics

```dart
final work = await tasks.query().joins([ProjectsDao]).toMap();
final template = tasks.query().joins([ProjectsDao]).toSql();
```

```sql
SELECT tasks.*, projects.id AS project_id, projects.name AS project_name
FROM tasks INNER JOIN projects ON projects.id = tasks.project_id;
-- Alias prefixes actually follow the target model type, not the table name.
```

`joins()` follows an FK on the current table to a registered target DAO. It is
an INNER JOIN: orphan/unmatched rows disappear. It does not implement a general
join builder, LEFT JOIN, has-many grouping or arbitrary ON clauses. Use
`includes()` to retain unmatched parents and group children. For other joins,
use bound raw SQL on the correct transaction executor and map the results
explicitly; raw SQL bypasses DAO value encryption and diagnostics.

## Nested includes and legacy proxy types

```dart
// If a TasksDao also declares a relation to CommentsDao, and CommentsDao is
// registered with an FK to tasks, load project → tasks → comments:
final tree = await projects.query()
    .includes([const ProxyInclude<TasksDao, CommentsDao>()]).toMap();
// Sibling children on the same intermediate table:
// ProxyInclude0<TasksDao, CommentsDao, AttachmentsDao>()
// ProxyInclude1<TasksDao, CommentsDao, AttachmentsDao, LabelsDao>()
```

These types select an intermediate DAO plus one, two or three child DAO types.
They require all intervening relation declarations and SQL FKs. Each level uses
batched separate SELECTs, rather than one huge joined result. Avoid cyclic
include trees and load only the depth the screen needs.

`ProxyHasMany`, `Proxy0HasMany`, and `Proxy1HasMany` remain exported legacy
classes. They are not substitutes for `HasMany`: automatic nested loading from
those declarations is not supported. Use `HasMany` plus explicit `ProxyInclude`
requests instead. This limitation is retained rather than silently promising a
many-to-many association API.

## Writes, updates and deletes

Nested `insert()` supports HasMany child lists, HasOne child maps and BelongsTo
parent maps using their result keys. A failed child insert rolls back the whole
nested operation. The generated parent ID populates the child FK. For an
**existing** parent, pass its FK value instead of nesting a parent map (which
creates another parent). `update()` changes the current table's fields; it does
not synchronize related collections. Update each DAO explicitly in a transaction.

```dart
await db.transaction(() async {
  await projects.query().where({'id': projectId}).updateAll({'name': 'Ready'});
  await tasks.query().where({'project_id': projectId}).updateAll({'done': 1});
});
// BEGIN; UPDATE projects SET name = ? WHERE id = ?;
// UPDATE tasks SET done = ? WHERE project_id = ?; COMMIT;
// On failure: ROLLBACK. Nested transaction() calls join this transaction.
```

`ON DELETE CASCADE` is a schema choice; DAO relation declarations never imply
cascade, soft delete, append/replace association helpers, or deletion of a
belongs-to parent. REPLACE conflicts can delete then insert a row and trigger
cascades: prefer `ConflictAlgorithm.abort` when this matters. Enforce one-to-one
uniqueness and add indexes on frequently queried FK columns yourself.

## Many-to-many: explicit join table

There is no first-class `ManyToMany` declaration or polymorphic relation helper.
Use a membership DAO with two foreign keys and a single surrogate primary key:

```sql
CREATE TABLE memberships (
  id INTEGER PRIMARY KEY,
  project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(project_id, user_id)
);
CREATE INDEX idx_memberships_user ON memberships(user_id);
-- projects HasMany<MembershipsDao>; memberships BelongsTo<ProjectsDao> and
-- BelongsTo<UsersDao>; users HasMany<MembershipsDao>.
SELECT users.* FROM users INNER JOIN memberships ON memberships.user_id = users.id
WHERE memberships.project_id = ?;
```

Alternatively load projects → memberships → users via
`ProxyInclude<MembershipsDao, UsersDao>()` and map the nested results. Add and
remove membership rows explicitly; deleting a membership should not delete a
user. Composite primary keys, multiple ambiguous FKs to the same table,
self-join aliases and polymorphic `(owner_type, owner_id)` loading require manual
SQL/application logic. Do not assume GORM association auto-save parity.

## Context and attribution

The paired schema/query/SQL teaching format and project-membership context are
inspired by [GORM associations](https://gorm.io/docs/associations.html) and
[preloading](https://gorm.io/docs/preload.html). These are original Dart examples
for QuickeyDB, not copied Go examples or a claim of equivalent features. GORM's
documentation is licensed CC BY 4.0; its API has additional association features.
