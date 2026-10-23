part of 'showcase.dart';

const sampleSql = '''CREATE TABLE projects (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL
);
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER,
  title TEXT NOT NULL,
  done INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (project_id) REFERENCES projects (id)
);''';

extension _LearningPages on _NotesPageState {
  Widget _stat(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(right: 20),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );

  Future<Memory> _openMemory() async {
    final existing = memoryOpening;
    if (existing != null) return existing;
    final opening = () async {
      final handle = await Memory().instance(
        memoryKey: widget.memoryNamespace,
        encryption: widget.database.valueEncryption,
      );
      if (!mounted) {
        await handle.close();
        throw StateError('Gallery was closed.');
      }
      memory = handle;
      return handle;
    }();
    memoryOpening = opening;
    try {
      return await opening;
    } catch (_) {
      if (identical(memoryOpening, opening)) memoryOpening = null;
      rethrow;
    }
  }

  Future<void> _memoryAction(String action) => _run(() async {
    final store = await _openMemory();
    String message;
    switch (action) {
      case 'save':
        await store.setString(
          'draft',
          memoryValue.text,
          ttl: shortTtl ? const Duration(seconds: 10) : null,
        );
        message =
            shortTtl
                ? 'Saved. Expires 10 seconds after this write. Read again after expiry.'
                : 'Saved without an expiry. Reads survive app reloads.';
      case 'delete':
        await store.deleteMemory('draft');
        message = 'Draft removed. Other keys were preserved.';
      default:
        final value = await store.getString('draft');
        message =
            value == null
                ? 'No draft found (missing or expired).'
                : 'Stored draft: $value';
    }
    if (mounted) {
      _change(() => memoryResult = message);
      _show({'action': action, 'result': message});
    }
  });

  List<Widget> _memoryPage() => [
    _panel(
      'A key and a value',
      const Text(
        'Use Memory for a small preference, draft or cached value. It is independent of SQLite tables and DAO transactions. This demo stores only the “draft” key in its own namespace, encrypted with the same persisted application key. It never logs the key.',
      ),
    ),
    _panel(
      'Try durable storage',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('memory-value'),
            controller: memoryValue,
            decoration: const InputDecoration(
              labelText: 'Draft value',
              border: OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Expire after 10 seconds'),
            subtitle: const Text(
              'Expiry is checked when reading; this is not a background timer.',
            ),
            value: shortTtl,
            onChanged: busy ? null : (value) => _change(() => shortTtl = value),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _button('Save memory', () => _memoryAction('save')),
              OutlinedButton(
                onPressed: busy ? null : () => _memoryAction('read'),
                child: const Text('Read memory'),
              ),
              TextButton(
                onPressed: busy ? null : () => _memoryAction('delete'),
                child: const Text('Delete draft'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(memoryResult),
          _terminal(),
        ],
      ),
    ),
    _code(
      "final memory = await Memory().instance(\n  memoryKey: 'drafts', encryption: ValueEncryption(key),\n);\nawait memory.setString('draft', 'Hello',\n  ttl: const Duration(minutes: 30));\nfinal draft = await memory.getString('draft');\nawait memory.deleteMemory('draft');\nawait memory.close();",
    ),
    _panel(
      'Choose the right store',
      const Text(
        'Use SQLite/DAOs for records, relationships, filters and atomic groups of writes. Use Memory for simple named values. Await setters for durability. Opening an existing namespace with a different key/configuration fails. Close the owner before changing configuration. Memory without ValueEncryption keeps the legacy encoding, which is not strong encryption.',
      ),
    ),
  ];

  List<Widget> _sqlPage() => [
    _panel(
      'From schema to Dart',
      const Text(
        'Paste one or more ordinary CREATE TABLE statements. QuickeyDB generates named map-based DAO classes, ready to copy into your application and register. Generation is local and never executes the SQL, creates tables or changes these notes.',
      ),
    ),
    _panel(
      'SQL input',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('sql-input'),
            controller: sqlInput,
            minLines: 8,
            maxLines: 18,
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: const InputDecoration(
              labelText: 'CREATE TABLE SQL',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _button(
            'Generate DAOs',
            () => _run(() async {
              _change(() => generated = null);
              final output = const SqlDaoGenerator().generate(sqlInput.text);
              if (mounted) {
                _change(() => generated = output);
                _show({
                  'tables': output.tables.map((t) => t.tableName).toList(),
                  'registration': output.registration,
                  'executedSql': false,
                });
              }
            }),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    if (generated != null) ...[
      _panel('Ready DAO source', _code(generated!.source)),
      _panel(
        'Register with QuickeyDB',
        _code(
          "// Import the saved generated file first.\nfinal database = await QuickeyDB.initialize(\n  dbName: 'my_app', dbVersion: 1,\n  dataAccessObjects: ${generated!.registration},\n);",
        ),
      ),
      _panel(
        'Next steps',
        Text(
          '${generated!.tables.length} DAO classes generated. Save the source in lib/, format it, then register the DAO instances. Use database.get<YourDao>()! to retrieve a DAO. Map keys must match the SQL column names. Add typed models, Converter implementations, relations and encryptedColumns explicitly as your application grows.',
        ),
      ),
    ],
    _code(
      "final output = const SqlDaoGenerator().generate(sql);\nprint(output.source);       // Named Dart DAO classes.\nprint(output.registration); // [ProjectsDao(), TasksDao()]\nprint(output.tables.first.tableName);",
    ),
    _panel(
      'Supported input and boundaries',
      const Text(
        'This is a schema-to-source helper, not a full SQLite parser or a migration runner. Each table needs a single primary key. Table names use letters, digits and underscores, beginning with a letter. SQL strings and comments can include semicolons. Composite keys, table options, indexes, triggers, views and INSERT/UPDATE/DELETE statements are rejected. Keep indexes and explicit migrations separate. Foreign keys stay in SQL; eager-loading relations are not inferred. Generated DAOs use maps, not generated domain models. Review SQL validity and application constraints before running it.',
      ),
    ),
  ];

  List<Widget> _introPage() => [
    _panel(
      '1. What is a database?',
      const Text(
        'A database keeps structured data after the app closes. A table is like a spreadsheet: columns describe fields, and each row is one record. In this demo the notes table contains id, title and body. SQLite is the local database engine; SQL is the language it understands.',
      ),
    ),
    _panel(
      '2. Describe the table',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INTEGER is a whole number. TEXT is text. PRIMARY KEY uniquely identifies a row. AUTOINCREMENT lets SQLite assign the ID. NOT NULL requires a value.',
          ),
          _code(
            'CREATE TABLE notes (\n  id INTEGER PRIMARY KEY AUTOINCREMENT,\n  title TEXT NOT NULL,\n  body TEXT NOT NULL\n);',
          ),
        ],
      ),
    ),
    _panel(
      '3. What does QuickeyDB add?',
      const Text(
        'A DAO (Data Access Object) represents a table in Dart. A Converter translates database maps to your models and back. Register DAOs once when opening the database, then retrieve them by type. You can generate map-based DAOs in SQL to DAO before learning model conversion.',
      ),
    ),
    _panel(
      '4. Learn CRUD',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create adds a row. Read fetches rows. Update changes an existing row using its ID. Delete removes it. Try the CRUD studio, then use the title filter in Query playground.',
          ),
          _code(
            "await notes.create(const Note(title: 'First', body: 'Hello'));\nfinal rows = await notes.query().toList();\nawait notes.update(Note(id: id, title: 'Updated', body: 'Hello'));\nawait notes.destroy(id);",
          ),
        ],
      ),
    ),
    _panel(
      '5. Ask a question',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WHERE filters rows. ORDER BY sorts them. LIMIT caps the number returned. Values belong in bound parameters rather than joined into SQL text.',
          ),
          _code(
            "// SQL idea: SELECT * FROM notes WHERE title = ? LIMIT 3\nawait notes.query().where({'title': 'First'}).limit(3).toList();",
          ),
        ],
      ),
    ),
    _panel(
      'Your learning path',
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton(
            onPressed: () => _navigate(1),
            child: const Text('Try CRUD'),
          ),
          OutlinedButton(
            onPressed: () => _navigate(7),
            child: const Text('Try SQL to DAO'),
          ),
          TextButton(
            onPressed: () => _navigate(8),
            child: const Text('Read the tips'),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _tipsPage() => [
    _integrationChecklist(),
    const GalleryGuidance(
      doText:
          "Use fresh scopes, await transactions, preserve drafts on errors and test upgrade paths.",
      dontText:
          "Do not overwrite encryption keys, search ciphertext or assume REPLACE behaves like UPDATE.",
    ),
    _panel(
      'Do: make operations deliberate',
      const Text(
        '• Create a fresh query() for independent work.\n• Await writes, batches and transactions.\n• Bind filter values through where maps.\n• Use a primary key to identify records for updates.\n• Validate input and handle errors without losing the user’s draft.\n• Use a transaction when writes must succeed together.\n• Add indexes to frequently searched public columns through a migration.',
      ),
    ),
    _panel(
      'Don’t: make hidden assumptions',
      const Text(
        '• Don’t concatenate user input into raw SQL.\n• Don’t assume privateStorage encrypts the entire file.\n• Don’t filter, sort or aggregate encrypted columns.\n• Don’t regenerate a lost key for an existing encrypted database.\n• Don’t use destroyAll() when you mean filtered deletion; use deleteWhere().\n• Don’t assume the default REPLACE conflict strategy is a harmless update: it can delete and reinsert a conflicting row. Choose abort when appropriate.\n• Don’t close the database while operations are still running.',
      ),
    ),
    _panel(
      'Encryption is a boundary',
      const Text(
        'Titles and IDs are visible in this example. Body encryption protects selected values, not schema, filenames, row counts or every byte in a backup. Keep recoverable keys separate from data. On web, scripts in the same origin can access application storage. Raw SQL bypasses DAO encryption.',
      ),
    ),
    _panel(
      'Performance starts with the query',
      const Text(
        'Select only the columns you need, paginate large lists and use count() instead of loading every record to count it. Batch related inserts rather than awaiting unrelated transactions one by one. Test with realistic data sizes. The gallery loads every note for its small learning dataset; copy pagination patterns into production lists.',
      ),
    ),
  ];

  List<Widget> _schemaPage() => [
    _panel(
      'Live SQLite schema',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SQLite $sqliteVersion • ${tableDefinitions.length} application tables\nInternal SQLite and QuickeyDB security tables are excluded. This page is read-only.',
          ),
          const SizedBox(height: 12),
          _button('Refresh schema', () => _run(_reload)),
        ],
      ),
    ),
    for (final table in tableDefinitions)
      _panel('${table['name']}', _code('${table['sql']}')),
    _panel(
      'Notes column guide',
      const Text(
        'id → primary key, generated by SQLite\ntitle → required public text; available to queries\nbody → required text; configured for DAO encryption\n\nAn SQL type alone does not enable encryption. encryptedColumns is DAO configuration; the key is provided at initialization.',
      ),
    ),
    _panel(
      'What the top bar measures',
      const Text(
        'Tables: application tables from sqlite_master. Notes: rows currently loaded from the notes DAO. Encrypted field: configured protected columns in NotesDao. Allocated KiB: SQLite page_count × page_size, including internal tables and free pages. It is not the browser’s total IndexedDB usage, a count of Memory values or an exact filesystem file size. Refresh after external changes.',
      ),
    ),
  ];

  List<Widget> _storagePage() => [
    _panel(
      'Where data lives',
      const Text(
        'Native SQLite uses private application-support/.quickeydb storage in this example. Browser SQLite uses a virtual filename and persists through IndexedDB. Browser data and its key are bound to the current origin: scheme, hostname and port. Keep a fixed localhost port while developing. Memory uses a separate store and namespace.',
      ),
    ),
    _panel(
      'One owner, one lifecycle',
      _code(
        'final database = await openNotesDatabase();\n// Pass the handle to the UI. Await all work before closing.\nawait database.transaction(() async {\n  await notes.create(first);\n  await notes.create(second);\n});\n// On logout/shutdown, after pending operations finish:\nawait database.close();',
      ),
    ),
    _panel(
      'Evolve the schema safely',
      const Text(
        'Increase dbVersion when changing persisted schema. Supported additive migrations preserve existing rows; destructive changes and downgrades need explicit callbacks. Back up both data and recoverable keys before migrations. Test upgrades from the oldest supported version, not only fresh installs. Keep CREATE TABLE definitions aligned with the final schema.',
      ),
    ),
    _panel(
      'Troubleshooting checklist',
      const Text(
        'No lib/main.dart? Run from example/. Missing SQLite worker or WASM? Run the web setup helper. Data vanished on a different port? Return to the original origin. Secure storage failed? Inspect the startup error and configure the platform plugin. Wrong key? Restore the original key; do not overwrite it. Native test hooks fail before tests load? Check the local Xcode SDK and license setup.',
      ),
    ),
  ];
}
