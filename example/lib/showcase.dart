import 'dart:async';
import 'package:flutter/material.dart';
import 'gallery_widgets.dart';
import 'package:sqflite_common/sqlite_api.dart' show DatabaseException;
import 'package:quickeydb/quickeydb.dart';
import 'notes.dart';
import 'package:activity/activity.dart';
import 'gallery_controller.dart';
import 'console.dart';
import 'support_links.dart';
part 'view_samples.dart';
part 'learning_pages.dart';
part 'advanced_pages.dart';
part 'recipes.dart';

class ShowcaseApp extends StatefulWidget {
  const ShowcaseApp({super.key, required this.database});
  final QuickeyDBImpl database;
  @override
  State<ShowcaseApp> createState() => _ShowcaseAppState();
}

class _ShowcaseAppState extends State<ShowcaseApp> {
  late final model = GalleryController(widget.database);
  late final ActivityRouter router = ActivityRouter(
    initialLocation: '/overview',
    routes: [
      ActivityRoute(
        path: '/',
        redirect: (_) => '/overview',
        builder: (_, state) => const SizedBox.shrink(),
      ),
      ActivityRoute(
        path: '/:section',
        name: 'gallery-section',
        redirect: (state) => _slugs.contains(state.pathParameters['section'])
            ? null
            : '/overview',
        builder: (_, state) => NotesPage(
          key: const ValueKey('routed-gallery'),
          database: widget.database,
          controller: model,
          sectionIndex: _slugs.indexOf(state.pathParameters['section']!),
          onNavigate: (index) => router.goNamed(
            'gallery-section',
            pathParameters: {'section': _slugs[index]},
          ),
          themeMode: model.theme.value,
          accent: model.accent.value,
          onThemeChanged: model.theme.call,
          onAccentChanged: model.accent.call,
          onToggleTheme: () => model.theme(
            model.theme.value == ThemeMode.dark
                ? ThemeMode.light
                : ThemeMode.dark,
          ),
        ),
        routes: [
          ActivityRoute(
            path: 'notes/:id',
            name: 'note-detail',
            builder: (_, state) => NoteDetailPage(
              key: ValueKey(state.pathParameters['id']),
              controller: model,
              id: int.tryParse(state.pathParameters['id'] ?? ''),
            ),
          ),
        ],
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Activity<GalleryController>(
    model,
    child: ActivitySelector<GalleryController, (ThemeMode, int)>(
      controller: model,
      select: (c) => (c.theme.value, c.accent.value),
      builder: (context, appearance, _) => MaterialApp.router(
        title: 'QuickeyDB Gallery',
        debugShowCheckedModeBanner: false,
        themeMode: appearance.$1,
        theme: galleryTheme(Brightness.light, appearance.$2),
        darkTheme: galleryTheme(Brightness.dark, appearance.$2),
        routerConfig: router.config,
      ),
    ),
  );
  @override
  void dispose() {
    router.dispose();
    unawaited(model.dispose());
    super.dispose();
  }
}

const _slugs = [
  'overview',
  'crud',
  'queries',
  'transactions',
  'encryption',
  'cookbook',
  'memory',
  'sql-to-dao',
  'guidance',
  'start',
  'schema',
  'storage',
  'pagination',
  'aggregates',
  'conflicts',
  'relations',
  'migrations',
  'recipes',
  'appearance',
];

const _pages = [
  'Overview',
  'CRUD studio',
  'Query playground',
  'Transactions',
  'Encryption',
  'API cookbook',
  'Memory',
  'SQL to DAO',
  'Tips & points',
  'Start here',
  'Schema explorer',
  'Storage & lifecycle',
  'Pagination',
  'Aggregates & projections',
  'Conflicts & bulk writes',
  'Relations',
  'Migrations & indexes',
  'Application recipes',
  'Appearance',
];
const _icons = [
  Icons.dashboard_outlined,
  Icons.edit_note,
  Icons.manage_search,
  Icons.account_tree_outlined,
  Icons.lock_outline,
  Icons.code,
  Icons.memory,
  Icons.auto_fix_high_outlined,
  Icons.tips_and_updates_outlined,
  Icons.school_outlined,
  Icons.table_chart_outlined,
  Icons.storage_outlined,
  Icons.view_list_outlined,
  Icons.analytics_outlined,
  Icons.rule_folder_outlined,
  Icons.hub_outlined,
  Icons.upgrade_outlined,
  Icons.integration_instructions_outlined,
  Icons.palette_outlined,
];
const _descriptions = [
  'A small database. A complete workflow.',
  'Create, read, update and delete real encrypted notes.',
  'Compose independent queries and inspect live results.',
  'Commit related writes together, or roll them all back.',
  'Compare application values with the bytes stored in SQLite.',
  'Patterns to take into your own application.',
  'A separate encrypted key-value store, with optional expiry.',
  'Turn table definitions into ready-to-register Dart DAOs.',
  'Practical habits that keep data and queries predictable.',
  'Your first steps with SQL, SQLite and QuickeyDB.',
  'Inspect the tables and columns behind this application.',
  'Understand persistence, migrations, keys and ownership.',
  'Page through real notes with stable ordering and bounded reads.',
  'Ask focused questions without loading whole models.',
  'Try conflict policies and scoped writes in rolled-back transactions.',
  'Model projects, tasks and foreign keys with complete DAO recipes.',
  'Plan schema upgrades, indexes and verification deliberately.',
  'Connect storage patterns to real Flutter application features.',
  'Choose your Material theme and accent color.',
];
const _groups = [
  'DISCOVER',
  'STATE & DATA',
  'STATE & DATA',
  'STATE & DATA',
  'APP SERVICES',
  'LEARN & BUILD',
  'APP SERVICES',
  'APP SERVICES',
  'LEARN & BUILD',
  'DISCOVER',
  'APP SERVICES',
  'APP SERVICES',
  'STATE & DATA',
  'STATE & DATA',
  'STATE & DATA',
  'APP SERVICES',
  'APP SERVICES',
  'LEARN & BUILD',
  'LEARN & BUILD',
];
const _apis = [
  'QuickeyDB',
  'DataAccessObject<T>',
  'query()',
  'transaction()',
  'ValueEncryption',
  'Converter<T>',
  'Memory',
  'SqlDaoGenerator',
  'Integration checklist',
  'Initialize / Register / Query',
  'sqlite_master',
  'Storage / Lifecycle',
  'limit / offset',
  'count / sumNumber / pluck',
  'ConflictAlgorithm',
  'HasMany / BelongsTo',
  'onUpgrade / indexes',
  'Repositories / Cache / Outbox',
  'ThemeMode / ColorScheme',
];

class NotesPage extends StatefulWidget {
  const NotesPage({
    super.key,
    required this.database,
    this.onToggleTheme,
    this.controller,
    this.sectionIndex,
    this.onNavigate,
    this.themeMode = ThemeMode.light,
    this.accent = 0,
    this.onThemeChanged,
    this.onAccentChanged,
    this.memoryNamespace = 'quickey_gallery_drafts_v1',
  });
  final QuickeyDBImpl database;
  final GalleryController? controller;
  final int? sectionIndex;
  final ValueChanged<int>? onNavigate;
  final VoidCallback? onToggleTheme;
  final ThemeMode themeMode;
  final int accent;
  final ValueChanged<ThemeMode>? onThemeChanged;
  final ValueChanged<int>? onAccentChanged;
  final String memoryNamespace;
  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final title = TextEditingController(),
      body = TextEditingController(),
      search = TextEditingController();
  late final model = widget.controller ?? GalleryController(widget.database);
  int _localPage = 0;
  int get page => widget.sectionIndex ?? _localPage;
  set page(int value) => _localPage = value;
  int? _runningPage;
  int? editing;
  List<Note> get notes => model.notes.value;
  bool get busy => model.actively;
  String? get error => model.lastError.value;
  set error(String? value) => model.lastError(value);
  String get result =>
      model.results[page] ?? 'Run an example to see its result.';
  final Set<int> checklist = {};
  int notePage = 1, pageSize = 3;
  int totalNotes = 0;
  final aggregateTitle = TextEditingController();
  String aggregate = 'Summary';
  String conflictPolicy = 'Abort';
  final migrationVersion = TextEditingController(text: '2');
  final migrationName = TextEditingController(text: 'idx_notes_title');
  String migrationPlan =
      'Generate a plan to review an additive migration. No schema changes are executed.';
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final crudFormKey = GlobalKey();
  String queryOrder = 'ASC', queryColumn = 'id';
  int queryLimit = 0, queryOffset = 0;
  bool queryMetadata = false;
  String preset = 'All notes';
  String contains = '';
  final queryText = TextEditingController();
  final memoryValue = TextEditingController(text: 'My first draft');
  final sqlInput = TextEditingController(text: sampleSql);
  Memory? memory;
  Future<Memory>? memoryOpening;
  String memoryResult =
      'Save a value, then read it back. This store is separate from notes.';
  bool shortTtl = false;
  SqlDaoGeneration? generated;
  List<Map<String, Object?>> get tableDefinitions => model.tables.value;
  int get allocatedBytes => model.allocated.value;
  String get sqliteVersion => model.sqlite.value;

  NotesDao get dao => widget.database.get<NotesDao>()!;

  @override
  void initState() {
    super.initState();
    _run(_reload);
  }

  void _change(VoidCallback action) {
    if (mounted) setState(action);
  }

  Future<void> _reload() => model.reload();

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    final section = page;
    _runningPage = section;
    try {
      await model.run(section, _pages[section], action);
    } finally {
      _runningPage = null;
    }
  }

  void _navigate(int value) {
    if (busy) return;
    if (widget.onNavigate != null) {
      error = null;
      widget.onNavigate!(value);
      return;
    }
    setState(() {
      page = value;
      error = null;
    });
  }

  void _show(Object? value) => model.publish(_runningPage ?? page, value);

  Future<void> _save() async {
    if (title.text.trim().isEmpty) {
      setState(() => error = 'Enter a title before saving.');
      return;
    }
    await _run(() async {
      final note = Note(id: editing, title: title.text.trim(), body: body.text);
      final savedId = await model.save(note);
      _show({
        'operation': editing == null ? 'created' : 'updated',
        'id': savedId,
        'record': {...note.toMap(), 'id': savedId},
        'rows': notes.length,
      });
      if (!mounted) return;
      title.clear();
      body.clear();
      editing = null;
      await _reload();
    });
  }

  Future<void> _query() => _run(() async {
    switch (preset) {
      case 'Title equals':
        _show(await dao.query().where({'title': queryText.text}).toMap());
      case 'Newest three':
        _show(await dao.query().order(['id'], 'DESC').limit(3).toMap());
      case 'Title contains':
        _show(
          await dao
              .query()
              .where({'title LIKE ?': '%${queryText.text}%'})
              .order(['id'], 'DESC')
              .limit(20)
              .toMap(),
        );
      case 'Metadata only':
        _show(
          await dao.query().select(['id', 'title']).order([
            'id',
          ], 'ASC').toMap(),
        );
      case 'Not this title':
        _show(await dao.query().not({'title': queryText.text}).toMap());
      case 'Count':
        _show({'count': await dao.query().count()});
      case 'Titles only':
        _show(await dao.query().pluck(['title']));
      default:
        _show(await _allNotesQuery().toMap());
    }
  });
  String get queryCode => switch (preset) {
    'Title equals' => "await notes.query().where({'title': title}).toMap();",
    'Newest three' =>
      "await notes.query().order(['id'], 'DESC').limit(3).toMap();",
    'Title contains' =>
      "await notes.query().where({'title LIKE ?': '%\$term%'})\n  .order(['id'], 'DESC').limit(20).toMap();",
    'Metadata only' =>
      "await notes.query().select(['id', 'title'])\n  .order(['id'], 'ASC').toMap();",
    'Not this title' => "await notes.query().not({'title': title}).toMap();",
    'Count' => 'await notes.query().count();',
    'Titles only' => "await notes.query().pluck(['title']);",
    _ => _allNotesSource,
  };

  DataAccessObject<Note> _allNotesQuery() {
    final query = dao.query().order(
      queryColumn == 'title' ? ['title', 'id'] : ['id'],
      queryOrder,
    );
    if (queryMetadata) query.select(['id', 'title']);
    if (queryLimit > 0) query.limit(queryLimit).offset(queryOffset);
    return query;
  }

  String get _allNotesSource =>
      """// Selected live query:
final rows = await notes.query()${queryMetadata ? ".select(['id', 'title'])" : ''}
    .order(${queryColumn == 'title' ? "['title', 'id']" : "['id']"}, '$queryOrder')${queryLimit > 0 ? '.limit($queryLimit).offset($queryOffset)' : ''}.toMap();

// All records, ascending and descending (fresh scope for each read):
final oldestFirst = await notes.query().order(['id'], 'ASC').toList();
final newestFirst = await notes.query().order(['id'], 'DESC').toList();
final alphabetical = await notes.query().order(['title', 'id'], 'ASC').toMap();
// Read a page; stable unique ordering prevents ambiguous offsets:
final nextPage = await notes.query().order(['id'], 'ASC')
    .limit(10).offset(10).toList();
// Projections are maps; the Note converter requires body as well:
final metadata = await notes.query().select(['id', 'title']).toMap();
final titles = await notes.query().pluck(['title']);
final count = await notes.query().count();
// Filter public metadata with bound values:
final matches = await notes.query().where({'title': 'Draft'})
    .order(['id'], 'DESC').limit(20).toMap();
// Encrypted body values cannot be filtered, ordered or aggregated.
""";

  Widget _terminal() => GalleryTerminal(model.terminals[page]);

  bool consoleOpen = false;
  void _console() => setState(() => consoleOpen = !consoleOpen);

  Widget _nav(BuildContext navContext) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      child: SizedBox(
        width: 252,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 20),
              child: Row(
                children: [
                  Image.asset(
                    'assets/branding/quickeydb.png',
                    width: 40,
                    height: 40,
                    semanticLabel: 'QuickeyDB logo',
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QuickeyDB',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.8,
                          ),
                        ),
                        Text(
                          'Built With Love',
                          style: TextStyle(fontSize: 9, letterSpacing: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const Key('nav-search'),
                controller: search,
                onChanged: (v) =>
                    setState(() => contains = v.trim().toLowerCase()),
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 19),
                  hintText: 'Find an example',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final group in [
                    'DISCOVER',
                    'STATE & DATA',
                    'APP SERVICES',
                    'LEARN & BUILD',
                  ]) ...[
                    if (contains.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 22, 12, 8),
                        child: Text(
                          group,
                          style: const TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ),
                    for (var i = 0; i < _pages.length; i++)
                      if (_groups[i] == group &&
                          '${_pages[i]} ${_descriptions[i]} ${_apis[i]}'
                              .toLowerCase()
                              .contains(contains))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            key: ValueKey('nav-$i'),
                            dense: true,
                            selected: page == i,
                            selectedTileColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            leading: Icon(_icons[i], size: 19),
                            title: Text(
                              _pages[i],
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: busy
                                ? null
                                : () {
                                    _navigate(i);
                                    if (Scaffold.of(navContext).isDrawerOpen) {
                                      Navigator.pop(navContext);
                                    }
                                  },
                          ),
                        ),
                  ],
                  if (contains.isNotEmpty &&
                      !List.generate(
                        _pages.length,
                        (i) => '${_pages[i]} ${_descriptions[i]} ${_apis[i]}'
                            .toLowerCase(),
                      ).any((s) => s.contains(contains)))
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No examples found. Try a feature or API name.',
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const Icon(Icons.terminal, size: 19),
              title: const Text(
                'Database console',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () {
                if (Scaffold.of(navContext).isDrawerOpen) {
                  Navigator.pop(navContext);
                }
                _console();
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.favorite_outline, size: 19),
              title: const Text(
                'Support aflare.space',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Support open source'),
                  content: const SizedBox(
                    width: 620,
                    child: SingleChildScrollView(child: SupportLinks()),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  GalleryPill('SQLite'),
                  Text('Activity reactive UI', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Activity<GalleryController>(
    model,
    child: Builder(
      builder: (context) {
        Activity.getActivity<GalleryController>(context);
        return GalleryExampleScope(
          modelCode: _modelFor(page),
          viewCode: _viewFor(page),
          terminal: model.terminals[page],
          child: _buildGallery(context),
        );
      },
    ),
  );

  Widget _buildGallery(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      return Scaffold(
        key: scaffoldKey,
        drawer: wide ? null : Drawer(width: 280, child: Builder(builder: _nav)),
        body: Row(
          children: [
            if (wide) ...[
              Builder(builder: _nav),
              const VerticalDivider(width: 1),
            ],
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 64,
                    padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (!wide)
                          IconButton(
                            tooltip: 'Open navigation menu',
                            onPressed: () =>
                                scaffoldKey.currentState!.openDrawer(),
                            icon: const Icon(Icons.menu),
                          ),
                        Icon(_icons[page], size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _pages[page],
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (wide) const GalleryPill('Live examples'),
                        IconButton(
                          tooltip: 'Refresh database stats',
                          onPressed: busy ? null : () => _run(_reload),
                          icon: const Icon(Icons.refresh, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Toggle theme',
                          onPressed: widget.onToggleTheme,
                          icon: Icon(
                            Theme.of(context).brightness == Brightness.dark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            size: 20,
                          ),
                        ),
                        if (wide)
                          IconButton(
                            tooltip: 'Open database console',
                            onPressed: _console,
                            icon: const Icon(Icons.terminal, size: 20),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 36,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          _stat(
                            Icons.table_chart_outlined,
                            '${tableDefinitions.length} ${tableDefinitions.length == 1 ? 'table' : 'tables'}',
                          ),
                          _stat(
                            Icons.notes,
                            '${notes.length} ${notes.length == 1 ? 'note' : 'notes'}',
                          ),
                          _stat(
                            Icons.lock_outline,
                            '${dao.encryptedColumns.length} encrypted field',
                          ),
                          _stat(
                            Icons.storage_outlined,
                            '${(allocatedBytes / 1024).toStringAsFixed(0)} KiB allocated',
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectionArea(
                      child: ListView(
                        key: PageStorageKey('page-$page'),
                        padding: EdgeInsets.all(wide ? 36 : 20),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1120),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'QuickeyDB gallery  /  ${_groups[page].toLowerCase()}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        _pages[page],
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -1,
                                            ),
                                      ),
                                      GalleryPill(_apis[page]),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _descriptions[page],
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          height: 1.6,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 28),
                                  if (busy) const LinearProgressIndicator(),
                                  if (error != null && page != 7)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        error!,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  ..._content(),
                                  const SizedBox(height: 20),
                                  const SupportLinks(),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (consoleOpen)
                    SizedBox(
                      height: (constraints.maxHeight * .35).clamp(140.0, 300.0),
                      child: DatabaseConsole(
                        controller: model,
                        onClose: _console,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _panel(String heading, Widget child) => GalleryPanel(heading, child);
  Widget _code(String code) => GallerySource(code);
  Widget _button(String label, Future<void> Function() action) =>
      FilledButton(onPressed: busy ? null : action, child: Text(label));
  List<Widget> _content() => switch (page) {
    0 => _overview(),
    1 => _crud(),
    2 => _queries(),
    3 => _transactions(),
    4 => _encryption(),
    5 => _cookbook(),
    6 => _memoryPage(),
    7 => _sqlPage(),
    8 => _tipsPage(),
    9 => _introPage(),
    10 => _schemaPage(),
    11 => _storagePage(),
    12 => _paginationPage(),
    13 => _aggregatesPage(),
    14 => _conflictsPage(),
    15 => _relationsPage(),
    16 => _migrationsPage(),
    17 => _recipesPage(),
    _ => _appearancePage(),
  };
  List<Widget> _overview() => [
    Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 24 : 34),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF641437), Color(0xFF98451F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BUILD WITH QUICKEYDB',
            style: TextStyle(
              color: Color(0xFFF8C612),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Local data.\nPractical possibilities.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Real Flutter examples for SQLite, fluent queries and encrypted storage.\nTry a preview. Inspect the source. Build your application.',
            style: TextStyle(
              color: Color(0xFFFFE6D8),
              height: 1.7,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF641437),
                ),
                onPressed: () => _navigate(9),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('New here? Start here'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFF8C612)),
                ),
                onPressed: () => _navigate(8),
                child: const Text("To-dos & don'ts"),
              ),
            ],
          ),
        ],
      ),
    ),
    LayoutBuilder(
      builder: (_, constraints) => Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final stat in [
            ('19', 'Example sections', Icons.widgets_outlined),
            ('Live', 'Local database previews', Icons.touch_app_outlined),
            ('Dart', 'Copyable sample code', Icons.code),
          ])
            SizedBox(
              width: constraints.maxWidth < 650
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 32) / 3,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(
                          stat.$3,
                          color: Theme.of(context).colorScheme.primary,
                          size: 26,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stat.$1,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                stat.$2,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    _panel(
      'How the pieces connect',
      const Text(
        'SQL schema → DAO + Converter → independent query → Dart results.\n\nUse SQLite for structured local records and transactions, and Memory for small named values. The gallery opens one notes database and reuses its original key. Pagination samples persist; conflict and bulk probes always roll back; relation and application recipes return source only.',
      ),
    ),
    LayoutBuilder(
      builder: (_, constraints) {
        final columns = constraints.maxWidth > 950
            ? 3
            : constraints.maxWidth > 620
            ? 2
            : 1;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (var i = 1; i < _pages.length; i++)
              SizedBox(
                width: (constraints.maxWidth - (columns - 1) * 16) / columns,
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _navigate(i),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _icons[i],
                            size: 26,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _pages[i],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward, size: 16),
                            ],
                          ),
                          const SizedBox(height: 9),
                          Text(
                            _descriptions[i],
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(height: 1.6),
                          ),
                          const SizedBox(height: 18),
                          GalleryPill(_apis[i]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
    const SizedBox(height: 24),
    _panel(
      'Your database',
      Text(
        '${notes.length} notes loaded\nTitles and IDs are queryable; bodies use authenticated selected-column encryption.\nWeb: SQLite WASM + IndexedDB. Native: SQLite in private application storage.',
      ),
    ),
    const GalleryGuidance(
      doText:
          'Try a preview, inspect its source and read the effect on saved data before running a sample.',
      dontText:
          'Do not treat recipes as automatic cloud sync, a key-recovery system or full-file encryption.',
    ),
  ];
  List<Widget> _crud() => [
    GalleryDemo(
      key: crudFormKey,
      showTerminalInPreview: true,
      title: editing == null ? 'Create a note' : 'Edit note #$editing',
      description:
          'Try the form, then inspect its API, Flutter view and connected model code.',
      code: crudApiSource,
      child: Column(
        children: [
          TextField(
            key: const Key('crud-title'),
            controller: title,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('crud-body'),
            controller: body,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Encrypted body',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              _button(editing == null ? 'Save note' : 'Update note', _save),
              if (editing != null)
                TextButton(
                  onPressed: () => setState(() {
                    editing = null;
                    title.clear();
                    body.clear();
                  }),
                  child: const Text('Cancel edit'),
                ),
            ],
          ),
        ],
      ),
    ),
    _panel(
      'Stored notes (${notes.length})',
      Column(
        children: [
          if (notes.isEmpty)
            const Text('No notes yet. Create your first note above.'),
          for (final note in notes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: widget.onNavigate == null
                  ? null
                  : () async {
                      final selected = await ActivityRouter.of(context)
                          .pushNamed<String>(
                            'note-detail',
                            pathParameters: {
                              'section': _slugs[page],
                              'id': '${note.id}',
                            },
                          );
                      if (mounted && selected != null) {
                        model.publish(1, {'routeResult': selected});
                      }
                    },
              title: Text(note.title),
              subtitle: Text(note.body),
              leading: CircleAvatar(child: Text('${note.id}')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit ${note.title}',
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            editing = note.id;
                            title.text = note.title;
                            body.text = note.body;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              final target = crudFormKey.currentContext;
                              if (mounted && target != null) {
                                Scrollable.ensureVisible(
                                  target,
                                  duration: const Duration(milliseconds: 200),
                                );
                              }
                            });
                          }),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete ${note.title}',
                    onPressed: busy
                        ? null
                        : () => _run(() async {
                            await dao.destroy(note.id);
                            if (editing == note.id) {
                              editing = null;
                              title.clear();
                              body.clear();
                            }
                            await _reload();
                            _show({
                              'operation': 'deleted',
                              'id': note.id,
                              'remainingRows': notes.length,
                            });
                          }),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
    _panel('Stored-notes view and connected model', _code(crudListSource)),
  ];
  List<Widget> _queries() => [
    GalleryDemo(
      key: const ValueKey('query-demo'),
      showTerminalInPreview: true,
      title: 'Build a query',
      description:
          'Run the selected query; source includes sorting, paging, filtering and projections.',
      code: queryCode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: preset,
            decoration: const InputDecoration(
              labelText: 'Example',
              border: OutlineInputBorder(),
            ),
            items: [
              'All notes',
              'Title equals',
              'Newest three',
              'Count',
              'Titles only',
              'Title contains',
              'Metadata only',
              'Not this title',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: busy ? null : (v) => setState(() => preset = v!),
          ),
          if ([
            'Title equals',
            'Title contains',
            'Not this title',
          ].contains(preset))
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextField(
                controller: queryText,
                decoration: InputDecoration(
                  labelText: preset == 'Title contains'
                      ? 'Title pattern'
                      : 'Exact title',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          if (preset == 'All notes') ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final order in ['ASC', 'DESC'])
                  ChoiceChip(
                    key: ValueKey('query-$order'),
                    label: Text(order == 'ASC' ? 'Ascending' : 'Descending'),
                    selected: queryOrder == order,
                    onSelected: busy
                        ? null
                        : (_) => _change(() => queryOrder = order),
                  ),
                for (final column in ['id', 'title'])
                  ChoiceChip(
                    label: Text('Sort by $column'),
                    selected: queryColumn == column,
                    onSelected: busy
                        ? null
                        : (_) => _change(() => queryColumn = column),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Metadata projection'),
              subtitle: const Text('Only id and title, returned as maps.'),
              value: queryMetadata,
              onChanged: busy
                  ? null
                  : (value) => _change(() => queryMetadata = value),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final limit in [0, 3, 10])
                  ChoiceChip(
                    label: Text(limit == 0 ? 'No limit' : 'Limit $limit'),
                    selected: queryLimit == limit,
                    onSelected: busy
                        ? null
                        : (_) => _change(() {
                            queryLimit = limit;
                            queryOffset = 0;
                          }),
                  ),
              ],
            ),
            if (queryLimit > 0)
              Wrap(
                spacing: 8,
                children: [
                  for (final offset in [0, queryLimit])
                    ChoiceChip(
                      label: Text('Offset $offset'),
                      selected: queryOffset == offset,
                      onSelected: busy
                          ? null
                          : (_) => _change(() => queryOffset = offset),
                    ),
                ],
              ),
          ],
          const SizedBox(height: 16),
          _button('Run query', _query),
        ],
      ),
    ),
    const Text(
      'Each query() creates an independent scope. Values in where maps are bound parameters. Encrypted bodies cannot be filtered, ordered or aggregated; query public metadata instead.',
    ),
  ];
  List<Widget> _transactions() => [
    _panel(
      'Atomic batch',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Insert two sample notes together. Each click adds a new pair to your database.',
          ),
          _code(
            "await notes.createAll([\n  const Note(title: 'Batch A', body: 'First'),\n  const Note(title: 'Batch B', body: 'Second'),\n]);",
          ),
          _button(
            'Insert sample pair',
            () => _run(() async {
              await dao.createAll([
                const Note(title: 'Batch A', body: 'First'),
                const Note(title: 'Batch B', body: 'Second'),
              ]);
              await _reload();
              _show({'inserted': 2, 'notes': notes.length});
            }),
          ),
        ],
      ),
    ),
    _panel(
      'Rollback demonstration',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'A deliberate exception cancels the insert. The before and after counts should match.',
          ),
          _code(
            "await database.transaction(() async {\n  await notes.create(note);\n  throw StateError('Cancel demo');\n}); // No note is committed.",
          ),
          _button(
            'Test rollback',
            () => _run(() async {
              final before = await dao.query().count();
              try {
                await widget.database.transaction(() async {
                  await dao.create(
                    const Note(title: 'Rolled back', body: 'Never committed'),
                  );
                  throw StateError('Cancel demo');
                });
              } on StateError catch (e) {
                if (e.message != 'Cancel demo') rethrow;
              }
              final after = await dao.query().count();
              await _reload();
              _show({
                'before': before,
                'after': after,
                'rolledBack': before == after,
              });
            }),
          ),
        ],
      ),
    ),
    _terminal(),
  ];
  List<Widget> _encryption() => [
    _panel(
      'Application values → protected storage',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Inspect one note using both the DAO and a raw SQLite read. The body is ciphertext on disk; the DAO authenticates and decrypts it. Create a note in CRUD first.',
          ),
          const SizedBox(height: 16),
          _button(
            'Inspect stored note',
            () => _run(() async {
              final rows = await dao
                  .query()
                  .order(['id'], 'DESC')
                  .limit(1)
                  .toMap();
              if (rows.isEmpty) {
                _show({'message': 'Create a note in CRUD first.'});
                return;
              }
              final raw = await widget.database.database!.query(
                'notes',
                where: 'id = ?',
                whereArgs: [rows.first['id']],
              );
              _show({'application': rows.first, 'sqlite': raw.first});
            }),
          ),
          const SizedBox(height: 16),
          _terminal(),
        ],
      ),
    ),
    _code(
      "NotesDao() : super(\n  'CREATE TABLE notes (...)',\n  encryptedColumns: {'body'},\n  converter: converter,\n);\n// Initialize once with a securely persisted 32-byte key.\nvalueEncryption: ValueEncryption(key),\nprivateStorage: true,",
    ),
    _panel(
      'Protection boundaries',
      const Text(
        'Only configured columns are encrypted. Titles, schema and IDs remain visible. Private storage reduces accidental discovery; it does not encrypt the entire database. Keep the key separate and backed up securely. Never generate a replacement key for an existing database. Browser storage belongs to the current origin and can be cleared by the user. Raw SQL bypasses column encryption.',
      ),
    ),
  ];
  List<Widget> _cookbook() => [
    _panel('Model conversion', _code(notesModelRecipe)),
    _panel(
      'Bound filters and pagination',
      _code(
        "await notes.query()\n  .where({'id >= ?': 1})\n  .order(['id'], 'ASC')\n  .limit(10).offset(0).toList();\n\nawait notes.query().where({'title': 'Draft'}).count();\nawait notes.query().where({'title': 'Draft'})\n  .updateAll({'title': 'Published'});\nawait notes.query().where({'title': 'Draft'}).deleteWhere();",
      ),
    ),
    _panel(
      'Relationships',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'In your own schema, declare foreign keys and DAO relations, then eager-load related records. This notes database has a single table; this pattern needs your TaskDao and UserDao.',
          ),
          _code(
            "// TaskDao configuration:\nrelations: [const BelongsTo<UserDao>()],\n\n// Query with related users:\nawait tasks.query().includes([UserDao]).toMap();",
          ),
        ],
      ),
    ),
    _panel(
      'Encrypted key-value storage',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Memory is a separate key-value store. Await writes and close it when its owner is done. This recipe does not change your notes.',
          ),
          _code(
            "final memory = await Memory().instance(\n  memoryKey: 'preferences',\n  encryption: ValueEncryption(key),\n);\nawait memory.setString('draft', 'Hello',\n  ttl: const Duration(hours: 1));\nfinal draft = await memory.getString('draft');\nawait memory.close();",
          ),
        ],
      ),
    ),
    _panel('Activity controller and reactive view', _code(controllerSource)),
    _panel('Activity routes and typed results', _code(routesSource)),
    _panel(
      'Lifecycle and compatibility',
      const Text(
        'Await pending operations before database.close(). Use explicit upgrade callbacks for destructive schema changes. Existing notes and the original secure-storage key are reused by this gallery. For an existing plaintext database, use the documented explicit encryption migration rather than enabling plaintext reads permanently.',
      ),
    ),
  ];
  @override
  void dispose() {
    if (widget.controller == null) unawaited(model.dispose());
    title.dispose();
    body.dispose();
    search.dispose();
    queryText.dispose();
    memoryValue.dispose();
    sqlInput.dispose();
    aggregateTitle.dispose();
    migrationVersion.dispose();
    migrationName.dispose();
    final handle = memory;
    if (handle != null) {
      unawaited(
        handle.close().catchError((Object e) {
          debugPrint('Memory close: $e');
        }),
      );
    }
    super.dispose();
  }
}
