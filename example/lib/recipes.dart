part of 'showcase.dart';

const relationsDaoSource = '''import 'package:quickeydb/quickeydb.dart';

typedef Row = Map<String?, dynamic>;
Converter<Row?> rowConverter() => Converter<Row?>(
  encode: (row) => Map<String?, dynamic>.from(row),
  decode: (row) => Map<String?, dynamic>.from(row!),
  decodeTable: (row) => Map<String?, dynamic>.from(row!),
);

class ProjectsDao extends DataAccessObject<Row> {
  ProjectsDao() : super(
    'CREATE TABLE projects (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)',
    converter: rowConverter(), relations: [const HasMany<TasksDao>()],
  );
}

class TasksDao extends DataAccessObject<Row> {
  TasksDao() : super(
    'CREATE TABLE tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, project_id INTEGER NOT NULL, title TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0, FOREIGN KEY(project_id) REFERENCES projects(id))',
    converter: rowConverter(), relations: [const BelongsTo<ProjectsDao>()],
  );
}''';

const relationsUsageSource =
    '''// Standalone app; use the named DAOs from the preceding source.
final database = await QuickeyDB.initialize(
  dbName: 'projects_app', dbVersion: 1,
  dataAccessObjects: [ProjectsDao(), TasksDao()],
  foreignKeys: true, conflictAlgorithm: ConflictAlgorithm.abort,
);
final projects = database.get<ProjectsDao>()!;
final tasks = database.get<TasksDao>()!;
await database.transaction(() async {
  final projectId = await projects.insert({'name': 'Release'});
  await tasks.insertAll([
    {'project_id': projectId, 'title': 'Write tests', 'done': 0},
    {'project_id': projectId, 'title': 'Review docs', 'done': 0},
  ]);
});
final parents = await projects.query().includes([TasksDao]).toMap();
final pending = await tasks.query().where({'done': 0})
    .includes([ProjectsDao]).toMap();
// SQL FKs reject orphan task records. No automatic cascade is declared here.
// Close only after the application's pending work is drained.
await database.close();''';

const migrationRecipe = '''// Supplied db is the version callback's executor.
// Keep the final CREATE TABLE definition aligned with each migration.
onUpgrade: (db, from, to) async {
  if (from < 2) {
    await db.execute(
      'ALTER TABLE notes ADD COLUMN archived INTEGER NOT NULL DEFAULT 0');
    await db.execute('CREATE INDEX idx_notes_title ON notes(title)');
  }
},
// After initialize completes, install idempotent indexes for fresh installs too:
await database.database!.execute(
  'CREATE INDEX IF NOT EXISTS idx_notes_title ON notes(title)');
// Keep migration SQL trusted and use bound parameters for data values.
// Back up recoverable data and keys, then test the oldest supported upgrade.''';

const _checkItems = [
  'Open once and pass the database handle to repositories and screens.',
  'Describe each table with a stable primary key and explicit constraints.',
  'Register named DAO types and complete model converters.',
  'Validate drafts and show write errors without discarding input.',
  'Use fresh query scopes and bound values for independent work.',
  'Paginate large lists and select only the columns you need.',
  'Await writes and group dependent changes in transactions.',
  'Review conflicts, foreign keys and deletion behavior explicitly.',
  'Persist and recover encryption keys separately from data.',
  'Align schema versions, migrations, indexes and fresh installs.',
  'Test reopening, rollback, empty/error states and web workers.',
  'Drain pending operations before closing the owning handle.',
];

const _contexts = [
  (
    title: 'Notes repository',
    use:
        'A screen needs typed notes without exposing query construction or database ownership.',
    flow: 'Widget → repository → NotesDao → encrypted local SQLite',
    caution:
        'The repository borrows the application-owned database. It should not close the shared handle or create a key.',
    code: '''// Import Note and NotesDao from the gallery's notes.dart.
class NotesRepository {
  NotesRepository(this.notes);
  final NotesDao notes;

  Future<List<Note>> newest({int limit = 20}) async {
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    final rows = await notes.query().order(['id'], 'DESC').limit(limit).toList();
    return rows.whereType<Note>().toList();
  }

  Future<void> save({int? id, required String title, required String body}) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw ArgumentError('A title is required');
    final note = Note(id: id, title: cleanTitle, body: body);
    if (id == null) { await notes.create(note); }
    else { await notes.update(note); }
  }

  Future<void> remove(int id) async { await notes.destroy(id); }
}
// final repository = NotesRepository(database.get<NotesDao>()!);
// Keep the draft until save completes; check mounted before updating the UI.''',
  ),
  (
    title: 'Draft autosave',
    use:
        'A form needs a small encrypted draft independent of relational records.',
    flow: 'Text change → debounce → Memory namespace → restore draft',
    caution:
        'Cancel the timer and await the active save before closing. Do not write on every build. Memory and SQLite do not share one transaction.',
    code: '''import 'dart:async';
import 'package:quickeydb/quickeydb.dart';

class DraftStore {
  DraftStore(this.memory);
  final Memory memory;
  Timer? _timer;
  Future<void> _pending = Future.value();
  Object? lastError;

  void schedule(String text) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), () {
      _pending = _pending.then((_) async {
        try {
          await memory.setString('draft', text, ttl: const Duration(days: 1));
          lastError = null;
        } catch (error) { lastError = error; } // Surface this to your UI.
      });
    });
  }
  Future<void> close() async {
    _timer?.cancel();
    await _pending;
    await memory.close();
  }
}
// final memory = await Memory().instance(
//   memoryKey: 'compose', encryption: applicationCipher);
// final previous = await memory.getString('draft');
// On explicit submit, await a direct save of the latest draft before closing.''',
  ),
  (
    title: 'Offline outbox',
    use:
        'A local change and its outbound operation must be stored atomically before attempting sync.',
    flow:
        'Local transaction → pending outbox row → retrying network worker → acknowledged status',
    caution:
        'This is a local persistence recipe, not a sync engine. A server must deduplicate operation IDs; network calls run after committing, outside the SQLite transaction.',
    code: '''// Own schema: outbox(id TEXT PRIMARY KEY, payload TEXT NOT NULL,
//   state TEXT NOT NULL DEFAULT 'pending', attempts INTEGER NOT NULL DEFAULT 0).
// Register OutboxDao and NotesDao. Encrypt sensitive payload columns.
// operationId comes from your application's stable unique-ID generator.
await database.transaction(() async {
  final noteId = await notes.create(note);
  await outbox.insert({
    'id': operationId,
    'payload': jsonEncode({'noteId': noteId, 'action': 'created'}),
    'state': 'pending', 'attempts': 0,
  });
});
// A separately owned worker reads a bounded batch:
final pending = await outbox.query().where({'state': 'pending'})
    .order(['id'], 'ASC').limit(20).toMap();
Future<void> sendPending(
    Future<void> Function(String payload, String idempotencyKey) send) async {
  for (final item in pending) {
    await send(item['payload'] as String, item['id'] as String);
    // Only after a durable server acknowledgement:
    await outbox.query().where({'id': item['id']}).updateAll({'state': 'sent'});
  }
}
// Persist attempts/backoff and handle failures before continuing in a real worker.''',
  ),
  (
    title: 'Cached catalog',
    use:
        'A product or article list should remain readable while a refresh replaces the cached snapshot.',
    flow:
        'Read cache → fetch remote snapshot → validate → one transaction → publish refreshed UI',
    caution:
        'Do not delete the old cache before a successful fetch. This recipe assumes a dedicated cache table, not a table containing unsynced user edits.',
    code: '''// Own schema: products(id INTEGER PRIMARY KEY, name TEXT NOT NULL,
//   price_cents INTEGER NOT NULL, updated_at TEXT NOT NULL).
// Register ProductsDao with a map/model converter.
final cached = await products.query().order(['id'], 'ASC')
    .limit(30).toMap();
// Render cached immediately. Fetch and validate the remote snapshot separately.
// final validatedRows = await api.fetchValidatedProducts();
await database.transaction(() async {
  await products.destroyAll(); // Dedicated, replaceable cache table only.
  await products.insertAll(validatedRows);
});
final refreshed = await products.query().order(['id'], 'ASC')
    .limit(30).toMap();
final totalCents = await products.query().sumNumber('price_cents');
// Keep integer minor units for money. Persist cache freshness separately.
// Reconcile by key instead when records contain local edits.''',
  ),
  (
    title: 'Search and filters',
    use:
        'A search form composes public title filters while independent widgets issue unrelated queries.',
    flow:
        'Validated search → bound query → metadata projection → detail by primary key',
    caution:
        'LIKE patterns treat % and _ as wildcards. Escape them for literal matching if your UX requires it. Never pass user text as an SQL identifier or raw expression.',
    code: '''final term = searchText.trim();
final matches = await notes.query()
    .where({'title LIKE ?': '%\$term%'})
    .select(['id', 'title'])
    .order(['id'], 'DESC').limit(20).toMap();
// Projections return maps: Note.fromMap expects body too.
final total = await notes.query()
    .where({'title LIKE ?': '%\$term%'}).count();
// Independent scope: no filter leaks into the detail read.
final fullNote = await notes.query().find(selectedId);
// Titles are public metadata. Encrypted bodies cannot be searched this way.
// Debounce input and ignore stale async results in the UI.''',
  ),
  (
    title: 'Preferences and expiry',
    use:
        'Store a small preference or an expiring cache entry using a dedicated Memory owner.',
    flow:
        'Open namespace → await writes → read/default → delete one key → close owner',
    caution:
        'TTL expiry is checked on read, not a background countdown. Treat a missing/expired value as an ordinary empty state.',
    code: '''final store = await Memory().instance(
  memoryKey: 'reader_preferences', encryption: applicationCipher,
);
try {
  await store.setString('theme', 'dark');
  await store.setString('last_search', 'Flutter',
      ttl: const Duration(hours: 1));
  final theme = await store.getString('theme') ?? 'system';
  final recentSearch = await store.getString('last_search');
  await store.deleteMemory('last_search'); // Preserve unrelated preferences.
} finally {
  await store.close();
}
// Open a long-lived owner once for production; this try/finally shows cleanup.
// Supply the same recoverable encryption key when reopening the namespace.''',
  ),
  (
    title: 'Stable keyset pagination',
    use:
        'A changing feed should avoid duplicate rows when new records arrive between page requests.',
    flow:
        'Unique descending ID → bounded first page → last ID cursor → next page',
    caution:
        'Cursors are not snapshots: deleted rows disappear, and records may change filters. Keep projected reads as maps.',
    code:
        "// Complete tested implementation: example/lib/workflow_recipes.dart\nfinal first = await pageBefore(items, pageSize: 20);\nfinal cursor = first.isEmpty ? null : first.last['id'] as int;\nfinal next = cursor == null ? <WorkRow>[] :\n  await pageBefore(items, beforeId: cursor, pageSize: 20);\n// SELECT id, title FROM work_items WHERE archived = 0 AND id < ? ORDER BY id DESC LIMIT 20\n// Stop on empty/short pages; do not restart from a null cursor.",
  ),
  (
    title: 'Atomic inbox replacement',
    use:
        'Replace a dedicated inbox while preserving saved rows and rolling back on conflicts.',
    flow:
        'Validate fetched rows → transaction → scoped delete → insertAll → commit',
    caution:
        'Choose ConflictAlgorithm.abort for rollback on ID conflicts. Fetch outside the transaction. Never replace unsynced user edits indiscriminately.',
    code:
        "// Register WorkItems from example/lib/workflow_recipes.dart first.\nawait replaceInbox(database, items, [\n  {'id': 100, 'title': 'New inbox item', 'bucket': 'inbox'},\n]);\n// The helper uses one database.transaction for deleteWhere + insertAll.\n// A failed insert restores the previous inbox; unrelated buckets survive.\n// See doc/FEATURE_RECIPES.md and test/documentation/workflow_recipes_test.dart.",
  ),
];

extension _RecipePages on _NotesPageState {
  List<Widget> _recipesPage() => [
    _panel(
      'Choose an application context',
      const Text(
        'These recipes explain how storage fits into an application. Notes examples use the gallery model; outbox/catalog examples identify their required schema and network service. They do not execute network requests or mutate your current notes. Source tabs include the connected model/DAO.',
      ),
    ),
    for (final recipe in _contexts)
      _panel(
        recipe.title,
        GalleryExampleScope(
          modelCode: _contextModels[recipe.title],
          viewCode: recipe.title == 'Notes repository'
              ? crudViewSource
              : recipe.title == 'Search and filters'
              ? queryViewSource
              : null,
          terminal: null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                recipe.use,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              GalleryPill(recipe.flow),
              _code(recipe.code),
              Text(
                recipe.caution,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    const GalleryGuidance(
      doText:
          'Adapt schemas and ownership to your feature. Add validation, UI loading/error states and tests around each repository boundary.',
      dontText:
          'Do not copy placeholders for APIs, keys or DAO classes as though the gallery supplied a backend or automatic synchronization.',
    ),
  ];

  Widget _integrationChecklist() => _panel(
    'Integration to-dos',
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${checklist.length} of ${_checkItems.length} complete',
          key: const Key('checklist-progress'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: checklist.length / _checkItems.length),
        const SizedBox(height: 12),
        const Text(
          'Your session checklist, not an automatic audit. Check items after verifying them in your own application.',
        ),
        for (var i = 0; i < _checkItems.length; i++)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: checklist.contains(i),
            title: Text(_checkItems[i], style: const TextStyle(fontSize: 13)),
            onChanged: (value) => _change(() {
              if (value == true) {
                checklist.add(i);
              } else {
                checklist.remove(i);
              }
            }),
          ),
      ],
    ),
  );
}

const notesModelRecipe = """import 'package:quickeydb/quickeydb.dart';

class Note {
  const Note({this.id, required this.title, required this.body});
  final int? id;
  final String title, body;
  Map<String, Object?> toMap() => {'id': id, 'title': title, 'body': body};
  factory Note.fromMap(Map<String?, dynamic> row) => Note(
    id: row['id'] as int?, title: row['title'] as String,
    body: row['body'] as String,
  );
}

class NotesDao extends DataAccessObject<Note> {
  NotesDao() : super(
    'CREATE TABLE notes (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, body TEXT NOT NULL)',
    encryptedColumns: {'body'},
    converter: Converter<Note?>(
      encode: Note.fromMap, decode: (note) => note!.toMap(),
      decodeTable: (note) => note!.toMap(),
    ),
  );
}
// Register NotesDao once with your application's persisted encryption key.
// Read full rows into Note; read metadata-only projections with toMap().
""";

final _contextModels = <String, String>{
  'Stable keyset pagination': workflowRecipeSource,
  'Atomic inbox replacement': workflowRecipeSource,
  'Notes repository': notesModelRecipe,
  'Search and filters': notesModelRecipe,
  'Offline outbox':
      '// Configure payload as an encrypted column when it holds sensitive data.\n${const SqlDaoGenerator().generate("CREATE TABLE outbox (id TEXT PRIMARY KEY, payload TEXT NOT NULL, state TEXT NOT NULL DEFAULT 'pending', attempts INTEGER NOT NULL DEFAULT 0)").source}',
  'Cached catalog': const SqlDaoGenerator()
      .generate(
        'CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT NOT NULL, price_cents INTEGER NOT NULL, updated_at TEXT NOT NULL)',
      )
      .source,
};

const relationSqlSource =
    r'''// HasMany: parents first, then children with bound IDs (chunks <=400).
final result = await projects.query().order(['id'], 'ASC')
  .limit(20).includes([TasksDao]).toMap();
// SELECT projects.* FROM projects ORDER BY id ASC LIMIT 20;
// SELECT tasks.* FROM tasks WHERE project_id IN (?, ?, ?);
// Missing children => tasks: []. The limit applies to parents.

// BelongsTo: current row's FK points at the parent primary key.
final work = await tasks.query().includes([ProjectsDao]).toMap();
// SELECT tasks.* FROM tasks;
// SELECT projects.* FROM projects WHERE id IN (?, ?);
// Missing parent => null. Singular nested keys follow the MODEL type.
// A map model uses the legacy key 'map<string?, dynamic>'.

final joined = await tasks.query().joins([ProjectsDao]).toMap();
// SELECT tasks.*, projects.<column> AS <model>_<column>, ...
// FROM tasks INNER JOIN projects ON projects.id = tasks.project_id;
// INNER JOIN removes unmatched rows. includes() preserves them.
// toSql() previews SQL with bound values redacted:
final template = tasks.query().where({'done': 0}).toSql();''';

const hasOneSource =
    r'''// Add ProfilesDao to registration and HasOne<ProfilesDao>() to ProjectsDao.
class ProfilesDao extends DataAccessObject<Row> {
  ProfilesDao() : super(
    'CREATE TABLE profiles (id INTEGER PRIMARY KEY, '
    'project_id INTEGER NOT NULL UNIQUE, description TEXT, '
    'FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE)',
    converter: rowConverter(), relations: [const BelongsTo<ProjectsDao>()],
  );
}
// UNIQUE(project_id) enforces one-to-one; HasOne alone does not.
final owners = await projects.query().includes([ProfilesDao]).toMap();
// SELECT projects.* FROM projects;
// SELECT profiles.* FROM profiles WHERE project_id IN (?, ?);
// Missing profile => null; named Profile model => nested key 'profile'.
// CASCADE is explicit SQL behavior, not inferred from HasOne.''';

const nestedRelationSource =
    r'''// Complete schema for a join-table model; register its generated DAO.
CREATE TABLE memberships (
  id INTEGER PRIMARY KEY,
  project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(project_id, user_id)
);
CREATE INDEX idx_memberships_user ON memberships(user_id);
// ProjectsDao: HasMany<MembershipsDao>()
// MembershipsDao: BelongsTo<ProjectsDao>(), BelongsTo<UsersDao>()
// UsersDao: HasMany<MembershipsDao>()

// Dart, after defining and registering those named DAOs:
final tree = await projects.query().includes([
  const ProxyInclude<MembershipsDao, UsersDao>(),
]).toMap();
// SELECT projects.* FROM projects;
// SELECT memberships.* FROM memberships WHERE project_id IN (...);
// SELECT users.* FROM users WHERE id IN (...);
// Remove a membership row explicitly; do not delete the shared user.
// No first-class ManyToMany or polymorphic declaration is implemented.
// All writes that must succeed together belong in db.transaction().''';

// Display the same complete recipe file covered by the package contract tests.
const workflowRecipeSource = r"""import 'package:quickeydb/quickeydb.dart';

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
    .updateAll({'archived': 1});""";
