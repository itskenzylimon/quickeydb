part of 'showcase.dart';

class _ProbeRollback implements Exception {
  const _ProbeRollback();
}

extension _AdvancedPages on _NotesPageState {
  Future<void> _loadNotePage() async {
    final total = await dao.query().count() ?? 0;
    final maxPage = total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;
    final current = notePage > maxPage ? maxPage : notePage;
    final rows = await dao
        .query()
        .order(['id'], 'ASC')
        .limit(pageSize)
        .offset((current - 1) * pageSize)
        .toMap();
    if (!mounted) return;
    _change(() {
      totalNotes = total;
      notePage = current;
    });
    _show({
      'page': current,
      'pageSize': pageSize,
      'total': total,
      'rows': rows,
    });
  }

  List<Widget> _paginationPage() => [
    GalleryDemo(
      title: 'Bounded pages with stable order',
      description:
          'Read only the requested page. Count separately so the last page can be clamped after deletions.',
      code: '''// notes is database.get<NotesDao>()!.
const pageSize = 3;
final total = await notes.query().count() ?? 0;
final lastPage = total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;
final current = requestedPage.clamp(1, lastPage);
final rows = await notes.query()
    .order(['id'], 'ASC') // Unique order makes pages deterministic.
    .limit(pageSize)
    .offset((current - 1) * pageSize)
    .toMap();
// Keep the previous UI visible during refresh; handle errors separately.''',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Uses your saved notes. Adding samples creates six real encrypted notes; remove them individually in CRUD when finished.',
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final size in [3, 6, 10])
                ChoiceChip(
                  label: Text('$size per page'),
                  selected: pageSize == size,
                  onSelected: busy
                      ? null
                      : (_) {
                          _change(() {
                            pageSize = size;
                            notePage = 1;
                          });
                          _run(_loadNotePage);
                        },
                ),
              _button('Load page', () => _run(_loadNotePage)),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => _run(() async {
                        await dao.createAll(
                          List.generate(
                            6,
                            (i) => Note(
                              title: 'Paging sample ${i + 1}',
                              body: 'Encrypted sample ${i + 1}',
                            ),
                          ),
                        );
                        await _reload();
                        await _loadNotePage();
                      }),
                child: const Text('Add six paging notes'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: busy || notePage <= 1
                    ? null
                    : () {
                        _change(() => notePage--);
                        _run(_loadNotePage);
                      },
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous page'),
              ),
              GalleryPill('Page $notePage'),
              OutlinedButton.icon(
                onPressed: busy || notePage * pageSize >= totalNotes
                    ? null
                    : () {
                        _change(() => notePage++);
                        _run(_loadNotePage);
                      },
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next page'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _terminal(),
        ],
      ),
    ),
    _panel(
      'Cursor pagination for changing feeds',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Offset pagination suits small lists and page-number UIs. For a growing feed, keep the last ID and request larger IDs. A cursor needs a unique, stable ordering key; changing filters invalidates the cursor.',
          ),
          _code(
            "final next = await notes.query()\n    .where({'id > ?': lastSeenId})\n    .order(['id'], 'ASC').limit(20).toList();\nfinal models = next.whereType<Note>().toList();\nif (models.isNotEmpty) lastSeenId = models.last.id!;",
          ),
        ],
      ),
    ),
    const GalleryGuidance(
      doText:
          'Count with count(), order by a unique key and bound each read. Reset page/cursor when filters change.',
      dontText:
          'Do not load every row for page counts or assume offsets remain stable while other writers insert/delete records.',
    ),
  ];

  Future<void> _aggregateNotes() => _run(() async {
    DataAccessObject<Note> scope() {
      final query = dao.query();
      if (aggregateTitle.text.isNotEmpty) {
        query.where({'title': aggregateTitle.text});
      }
      return query;
    }

    switch (aggregate) {
      case 'Titles':
        _show(await scope().order(['id'], 'ASC').pluck(['title']));
      case 'Distinct titles':
        _show(
          await scope().select(['title']).distinct().order([
            'title',
          ], 'ASC').toMap(),
        );
      case 'Duplicate titles':
        _show(
          await scope()
              .select(['title'])
              .group(['title'])
              .having('COUNT(*) > 1')
              .toMap(),
        );
      default:
        _show({
          'count': await scope().count(),
          'minimumId': await scope().minimum('id'),
          'maximumId': await scope().maximum('id'),
          'sumIds': await scope().sumNumber('id'),
          'averageId': await scope().average('id'),
        });
    }
  });

  List<Widget> _aggregatesPage() => [
    GalleryDemo(
      title: 'Shape results for the question',
      description:
          'Each calculation uses a fresh scope. Only public metadata is filtered, grouped or aggregated.',
      code: '''final count = await notes.query().count();
final titles = await notes.query().order(['id'], 'ASC').pluck(['title']);
final unique = await notes.query().select(['title']).distinct().toMap();
final duplicates = await notes.query().select(['title'])
    .group(['title']).having('COUNT(*) > 1').toMap();
// A fresh query() for every terminal call:
final firstId = await notes.query().minimum('id');
final lastId = await notes.query().maximum('id');
final sum = await notes.query().sumNumber('id');
final mean = await notes.query().average('id');
// For money/measurements use an appropriate numeric column in your own schema.
// sumNumber preserves real values; legacy sum expects an integer result.''',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: aggregate,
            decoration: const InputDecoration(labelText: 'Result shape'),
            items: [
              'Summary',
              'Titles',
              'Distinct titles',
              'Duplicate titles',
            ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: busy
                ? null
                : (value) => _change(() => aggregate = value!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: aggregateTitle,
            key: const Key('aggregate-title'),
            decoration: const InputDecoration(
              labelText: 'Exact title filter (optional)',
              helperText: 'An empty field includes all notes.',
            ),
          ),
          const SizedBox(height: 16),
          _button('Calculate result', _aggregateNotes),
          const SizedBox(height: 16),
          _terminal(),
          const SizedBox(height: 12),
          const Text(
            'ID statistics teach the methods; IDs are identifiers, not business measurements. Empty averages/min/max can be null.',
          ),
        ],
      ),
    ),
    const GalleryGuidance(
      doText:
          'Select maps/projections when you need a subset of columns. Use full rows when converting to a model that requires every field.',
      dontText:
          'Do not aggregate encrypted body values or interpolate user input into having() expressions. This demo uses a fixed trusted expression.',
    ),
  ];

  Future<void> _conflictProbe() => _run(() async {
    final before = await dao.query().count();
    final policy = switch (conflictPolicy) {
      'Ignore' => ConflictAlgorithm.ignore,
      'Replace' => ConflictAlgorithm.replace,
      _ => ConflictAlgorithm.abort,
    };
    final probe = NotesDao(insertConflictAlgorithm: policy);
    Map<String, Object?> snapshot = {};
    try {
      await widget.database.transaction(() async {
        final id = await dao.create(
          const Note(title: 'Conflict probe', body: 'Original protected value'),
        );
        String outcome = 'Duplicate accepted';
        try {
          await probe.create(
            Note(
              id: id as int,
              title: 'Replacement probe',
              body: 'Replacement protected value',
            ),
          );
        } on DatabaseException {
          outcome = 'Duplicate rejected';
        }
        final observed = await dao.query().where({'id': id}).toMap();
        snapshot = {
          'policy': conflictPolicy,
          'outcome': outcome,
          'observed': observed,
        };
        throw const _ProbeRollback();
      });
    } on _ProbeRollback {
      /* Deliberate cleanup of every probe write. */
    }
    _show({
      ...snapshot,
      'before': before,
      'after': await dao.query().count(),
      'rolledBack': true,
    });
  });

  Future<void> _bulkProbe() => _run(() async {
    final before = await dao.query().count();
    Map<String, Object?> snapshot = {};
    try {
      await widget.database.transaction(() async {
        final a = await dao.create(
          const Note(title: 'Draft probe', body: 'First private body'),
        );
        final b = await dao.create(
          const Note(title: 'Draft probe', body: 'Second private body'),
        );
        final updated = await dao
            .query()
            .where({
              'id IN (?, ?)': [a, b],
            })
            .updateAll({'title': 'Published probe'});
        final published = await dao.query().where({
          'id IN (?, ?)': [a, b],
        }).toMap();
        final deleted = await dao.query().where({'id': a}).deleteWhere();
        snapshot = {
          'updated': updated,
          'deleted': deleted,
          'published': published,
        };
        throw const _ProbeRollback();
      });
    } on _ProbeRollback {
      /* Probe records never persist. */
    }
    _show({
      ...snapshot,
      'before': before,
      'after': await dao.query().count(),
      'rolledBack': true,
    });
  });

  List<Widget> _conflictsPage() => [
    GalleryDemo(
      title: 'See duplicate primary-key behavior',
      description:
          'Creates a new probe row, attempts a duplicate ID, inspects the outcome, then rolls back the entire probe.',
      code: '''// NotesDao forwards insertConflictAlgorithm to super(...).
final strict = NotesDao(insertConflictAlgorithm: ConflictAlgorithm.abort);
final ignore = NotesDao(insertConflictAlgorithm: ConflictAlgorithm.ignore);
final replace = NotesDao(insertConflictAlgorithm: ConflictAlgorithm.replace);
// Use the same encryptedColumns and Converter on each instance.
// abort: duplicate insert throws; existing row stays.
// ignore: duplicate insert is skipped; existing row stays.
// replace: conflicting row can be deleted and reinserted.
await strict.create(note);
// Usually prefer updating an existing record by primary key:
await notes.update(Note(id: existingId, title: 'Changed', body: 'Private'));
// Set the application default at QuickeyDB.initialize:
// conflictAlgorithm: ConflictAlgorithm.abort''',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final policy in ['Abort', 'Ignore', 'Replace'])
                ChoiceChip(
                  label: Text(policy),
                  selected: conflictPolicy == policy,
                  onSelected: busy
                      ? null
                      : (_) => _change(() => conflictPolicy = policy),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _button('Run conflict probe', _conflictProbe),
        ],
      ),
    ),
    GalleryDemo(
      title: 'Scoped update and delete',
      description:
          'Updates two temporary IDs, deletes one, and rolls back. Existing saved notes remain outside the filter.',
      code: '''await database.transaction(() async {
  final firstId = await notes.create(first);
  final secondId = await notes.create(second);
  final updated = await notes.query()
      .where({'id IN (?, ?)': [firstId, secondId]})
      .updateAll({'title': 'Published'});
  final deleted = await notes.query().where({'id': firstId}).deleteWhere();
  // Let the callback return to commit. Throw to roll back all writes.
});
// Never call destroyAll() for a filtered deletion.''',
      child: _button('Run bulk probe', _bulkProbe),
    ),
    _panel('Probe result', _terminal()),
    const GalleryGuidance(
      doText:
          'Choose a conflict policy deliberately, await transaction work and scope updates/deletes by stable identifiers.',
      dontText:
          'Do not treat REPLACE as a merge. Do not trigger another database handle or an unawaited operation inside the transaction.',
    ),
  ];

  List<Widget> _relationsPage() => [
    _panel(
      'Projects own many tasks',
      const Text(
        'Use this standalone recipe when records belong together. A SQL foreign key enforces integrity; HasMany and BelongsTo describe eager loading. The gallery notes database remains a single-table database. These recipes are not executed here.',
      ),
    ),
    _panel(
      'All relation types and their SQL',
      const Text(
        'HasMany loads a list through the child foreign key. HasOne loads one map (or null) through a UNIQUE child foreign key. BelongsTo follows the current row’s foreign key to one parent. Each include is a separate, batched SELECT; joins uses INNER JOIN and removes unmatched rows. These declarations do not create SQL constraints.',
      ),
    ),
    _panel('1. Complete map-based DAOs', _code(relationsDaoSource)),
    _panel(
      '2. Open, seed and query in a standalone app',
      _code(relationsUsageSource),
    ),
    _panel(
      '3. Inspect the data shape',
      const Text(
        'projects.query().includes([TasksDao]).toMap() returns parent maps with a tasks list. A project with no tasks has an empty child list. Map-based belongs-to results use the package’s model-type-derived nested key; inspect the returned map or define typed model converters for your application. joins() uses SQL joins; choose includes() when you want grouped children.',
      ),
    ),
    _panel(
      '4. SQL translations: eager loading versus joins',
      _code(relationSqlSource),
    ),
    _panel('5. One-to-one: enforce uniqueness in SQL', _code(hasOneSource)),
    _panel(
      '6. Nested includes and explicit many-to-many memberships',
      _code(nestedRelationSource),
    ),
    _panel(
      'Capability boundaries',
      const Text(
        'ProxyInclude, ProxyInclude0 and ProxyInclude1 load one, two or three child DAO types below an intermediate DAO. Use HasMany declarations plus these explicit include requests. Legacy ProxyHasMany variants do not provide automatic nested loading. Many-to-many uses an explicit membership DAO; there is no polymorphic loader, association append/replace API, composite-key model or general LEFT JOIN builder. Updates do not auto-save child collections. Register every DAO, preserve keys in projections, and test converters against empty/null children.',
      ),
    ),
    const GalleryGuidance(
      doText:
          'Enable foreignKeys, declare the actual SQL FK, register each named DAO and use transaction() when parent/child creation must be atomic.',
      dontText:
          'Do not assume adding HasMany creates a foreign key, that the generator infers relations, or that a second QuickeyDB instance can open while the current owner is active.',
    ),
  ];

  Future<void> _planMigration() => _run(() async {
    _change(
      () => migrationPlan =
          'Review the inputs and generate a new plan. No DDL has been executed.',
    );
    final oldVersion =
        (await widget.database.database!.rawQuery(
              'PRAGMA user_version',
            )).first.values.first
            as int;
    final version = int.tryParse(migrationVersion.text);
    final name = migrationName.text.trim();
    if (version == null || version <= oldVersion) {
      throw ArgumentError(
        'Choose a version greater than the current version $oldVersion.',
      );
    }
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) {
      throw ArgumentError('Use a simple SQL identifier for the index name.');
    }
    _change(
      () => migrationPlan =
          '''// REVIEW ONLY. Update NotesDao CREATE TABLE to include archived first.
// For a new application, include archived in its initial schema too.
final database = await QuickeyDB.initialize(
  dbName: 'private_notes', dbVersion: $version,
  dataAccessObjects: [NotesDao()],
  valueEncryption: existingEncryption, privateStorage: true,
  conflictAlgorithm: ConflictAlgorithm.abort,
  onUpgrade: (db, from, to) async {
    if (from < $version) {
      await db.execute('ALTER TABLE notes ADD COLUMN archived INTEGER NOT NULL DEFAULT 0');
      await db.execute('CREATE INDEX IF NOT EXISTS $name ON notes(title)');
    }
  },
);
await database.database!.execute('CREATE INDEX IF NOT EXISTS $name ON notes(title)');
// This post-open index installation also handles fresh databases.
// The callback is already transactional; do not call the DAO singleton inside it.
// Verify old rows and decryption, user_version, PRAGMA table_info(notes),
// PRAGMA index_list(notes), and PRAGMA foreign_key_check.
// Handle each historical version separately as your schema grows.''',
    );
    _show({
      'generatedOnly': true,
      'fromVersion': oldVersion,
      'toVersion': version,
      'index': name,
      'schemaChanged': false,
    });
  });

  List<Widget> _migrationsPage() => [
    GalleryDemo(
      title: 'Generate a reviewable upgrade plan',
      description:
          'Reads the current version and generates source only. It does not execute DDL or change your notes schema.',
      code: migrationRecipe,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('migration-version'),
            controller: migrationVersion,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Target database version',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('migration-index'),
            controller: migrationName,
            decoration: const InputDecoration(
              labelText: 'Public-title index name',
            ),
          ),
          const SizedBox(height: 16),
          _button('Generate migration plan', _planMigration),
        ],
      ),
    ),
    _panel('Review before applying', _code(migrationPlan)),
    _panel(
      'Query-plan inspection',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Inspect the actual current database. A SCAN is expected if there is no title index. For a tiny table SQLite may still prefer a scan even when an index exists.',
          ),
          const SizedBox(height: 16),
          _button(
            'Inspect current query plan',
            () => _run(
              () async => _show(
                await widget.database.database!.rawQuery(
                  'EXPLAIN QUERY PLAN SELECT id, title FROM notes WHERE title = ?',
                  ['Sample title'],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _terminal(),
        ],
      ),
    ),
    const GalleryGuidance(
      doText:
          'Test fresh installs and upgrades from every supported version. Keep DAO schema, callbacks and converters aligned, and verify existing encrypted rows with their original key.',
      dontText:
          'Do not rename/drop columns through guessed mappings, index encrypted ciphertext for plaintext search, or assume creating an index in onUpgrade also covers fresh installs.',
    ),
  ];

  List<Widget> _appearancePage() => [
    _panel(
      'Material appearance',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Built reactively by Activity. Appearance changes are local to this app session.',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in ThemeMode.values)
                ChoiceChip(
                  label: Text(switch (mode) {
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                    _ => 'System',
                  }),
                  selected:
                      (widget.controller == null
                          ? widget.themeMode
                          : model.theme.value) ==
                      mode,
                  onSelected: widget.onThemeChanged == null
                      ? null
                      : (_) => widget.onThemeChanged!(mode),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < galleryAccents.length; i++)
                Tooltip(
                  message: ['Pink', 'Orange', 'Yellow', 'Rose', 'Amber'][i],
                  child: InkWell(
                    onTap: widget.onAccentChanged == null
                        ? null
                        : () => widget.onAccentChanged!(i),
                    borderRadius: BorderRadius.circular(24),
                    child: CircleAvatar(
                      backgroundColor: galleryAccents[i],
                      child:
                          (widget.controller == null
                                  ? widget.accent
                                  : model.accent.value) ==
                              i
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          _code(
            "MaterialApp(\n  themeMode: themeMode,\n  theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: accent)),\n  darkTheme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark)),\n  home: NotesPage(database: database),\n);",
          ),
        ],
      ),
    ),
    const GalleryGuidance(
      doText:
          'Keep database ownership above the shell so appearance and navigation changes reuse the same handle.',
      dontText:
          'Do not reopen the database or regenerate encryption keys when rebuilding a widget or changing a theme.',
    ),
  ];
}
