part of 'showcase.dart';

String? _modelFor(int page) => switch (page) {
  6 || 7 || 8 || 18 => null,
  15 => relationsDaoSource,
  17 => null,
  _ => notesModelRecipe,
};
String? _viewFor(int page) => switch (page) {
  1 => crudViewSource,
  2 => queryViewSource,
  6 => memoryViewSource,
  7 || 8 || 18 => null,
  15 => relationsViewSource,
  _ => reactiveListViewSource,
};

const crudApiSource = '''final notes = database.get<NotesDao>()!;
final id = await notes.create(const Note(title: 'Draft', body: 'Private text'));
final saved = await notes.query().find(id);
await notes.update(Note(id: id as int, title: 'Published', body: 'Updated text'));
final rows = await notes.query().order(['id'], 'DESC').toList();
await notes.destroy(id); // Explicit primary-key deletion.
// Read full rows into Note; projections should use toMap().
// The gallery form retains its draft if a write fails.''';

const crudViewSource = '''import 'package:activity/activity.dart';
import 'package:flutter/material.dart';
import 'gallery_controller.dart';
import 'notes.dart';

// The application creates/owns GalleryController and its database once.
class NotesCrudView extends StatefulWidget {
  const NotesCrudView({super.key, required this.controller});
  final GalleryController controller;
  @override
  State<NotesCrudView> createState() => _NotesCrudViewState();
}
class _NotesCrudViewState extends State<NotesCrudView> {
  final title = TextEditingController(), body = TextEditingController();
  int? editingId;
  @override
  void dispose() { title.dispose(); body.dispose(); super.dispose(); }

  Future<void> save() => widget.controller.run(1, 'Save note', () async {
    if (title.text.trim().isEmpty) throw ArgumentError('A title is required');
    final id = await widget.controller.save(Note(
      id: editingId, title: title.text.trim(), body: body.text));
    widget.controller.publish(1, {'savedId': id});
    if (!mounted) return;
    setState(() { editingId = null; title.clear(); body.clear(); });
  });

  @override
  Widget build(BuildContext context) =>
    ActivitySelector<GalleryController, (List<Note>, bool, String?)>(
      controller: widget.controller,
      select: (c) => (c.notes.value, c.actively, c.lastError.value),
      builder: (context, state, child) => ListView(children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
        TextField(controller: body, decoration: const InputDecoration(labelText: 'Body')),
        FilledButton(onPressed: state.\$2 ? null : save,
          child: Text(editingId == null ? 'Add note' : 'Update note')),
        if (state.\$3 != null) Text(state.\$3!),
        for (final note in state.\$1) ListTile(
          title: Text(note.title), subtitle: Text(note.body),
          onTap: state.\$2 ? null : () => setState(() {
            editingId = note.id; title.text = note.title; body.text = note.body;
          }),
          trailing: IconButton(icon: const Icon(Icons.delete_outline),
            onPressed: state.\$2 ? null : () => widget.controller.run(1, 'Delete note', () async {
              await widget.controller.dao.destroy(note.id);
              await widget.controller.reload();
              widget.controller.publish(1, {'deletedId': note.id});
            })),
        ),
      ]),
    );
}''';

const crudListSource =
    '''// Read a stable list from Activity rather than issuing SQL in build().
ActivitySelector<GalleryController, List<Note>>(
  controller: controller,
  select: (c) => c.notes.value,
  builder: (context, notes, child) => Column(children: [
    if (notes.isEmpty) const Text('Create your first note'),
    for (final note in notes) ListTile(
      title: Text(note.title), subtitle: Text(note.body),
      onTap: () => ActivityRouter.of(context).pushNamed<String>(
        'note-detail', pathParameters: {'section': 'crud', 'id': '\${note.id}'}),
    ),
  ]),
);
// The detail route returns a String through router.pop<String>(result).
// The app owns the controller; this list never closes the shared database.''';

const queryViewSource = '''import 'package:activity/activity.dart';
import 'package:flutter/material.dart';
import 'gallery_controller.dart';
import 'gallery_widgets.dart';

class AllNotesQueryView extends StatefulWidget {
  const AllNotesQueryView({super.key, required this.controller});
  final GalleryController controller;
  @override
  State<AllNotesQueryView> createState() => _AllNotesQueryViewState();
}
class _AllNotesQueryViewState extends State<AllNotesQueryView> {
  String order = 'ASC';
  Future<void> runQuery() => widget.controller.run(2, 'All notes', () async {
    final rows = await widget.controller.dao.query()
        .order(['id'], order).toMap();
    widget.controller.publish(2, rows);
  });
  @override
  Widget build(BuildContext context) =>
    ActivitySelector<GalleryController, (bool, TerminalRun?)>(
      controller: widget.controller,
      select: (c) => (c.actively, c.terminals[2]),
      builder: (context, state, child) => Column(children: [
        Wrap(spacing: 8, children: [
          for (final option in ['ASC', 'DESC']) ChoiceChip(
            label: Text(option), selected: order == option,
            onSelected: state.\$1 ? null : (_) => setState(() => order = option)),
        ]),
        FilledButton(onPressed: state.\$1 ? null : runQuery,
          child: const Text('Run query')),
        GalleryTerminal(state.\$2), // Actual data, errors and execution time.
      ]),
    );
}''';

const reactiveListViewSource = '''import 'package:activity/activity.dart';
import 'package:flutter/material.dart';
import 'gallery_controller.dart';
import 'gallery_widgets.dart';
import 'notes.dart';

// Reusable view pattern for a screen backed by the same Note model.
class ReactiveNotesView extends StatelessWidget {
  const ReactiveNotesView({super.key, required this.controller, required this.section});
  final GalleryController controller;
  final int section;
  @override
  Widget build(BuildContext context) =>
    ActivitySelector<GalleryController, (List<Note>, bool, TerminalRun?)>(
      controller: controller,
      select: (c) => (c.notes.value, c.actively, c.terminals[section]),
      builder: (context, state, child) => Column(children: [
        FilledButton(onPressed: state.\$2 ? null : () => controller.run(
          section, 'Reload notes', () async {
            await controller.reload();
            controller.publish(section, controller.notes.value.map((n) => n.toMap()).toList());
          }), child: const Text('Reload')),
        for (final note in state.\$1) ListTile(title: Text(note.title)),
        GalleryTerminal(state.\$3),
      ]),
    );
}''';

const memoryViewSource =
    '''// Memory stores strings here; no SQL model or DAO is involved.
// Own the store outside build(), and close it after pending writes finish.
TextField(controller: draft, decoration: const InputDecoration(labelText: 'Draft'));
FilledButton(onPressed: busy ? null : () async {
  await store.setString('draft', draft.text, ttl: const Duration(hours: 1));
  final saved = await store.getString('draft');
  if (controller.isDisposed) return;
  controller.publish(6, {'draft': saved});
}, child: const Text('Save draft'));
// Display controller.terminals[6] through an ActivitySelector and GalleryTerminal.''';

const relationsViewSource =
    '''// A projects view uses the ProjectsDao/TasksDao shown in Model / DAO.
// Load outside build(), through the owning Activity controller's async action:
final rows = await projects.query().includes([TasksDao]).toMap();
// Keep an immutable snapshot in an ActiveType<List<Map<String?, dynamic>>>.
// In an ActivitySelector builder:
Column(children: [
  for (final project in rows) ExpansionTile(
    title: Text(project['name'] as String),
    children: [for (final task in project['tasks'] as List)
      ListTile(title: Text(task['title'] as String))],
  ),
]);
// These are standalone relation recipes; the live gallery stores Note rows.''';

const routesSource =
    """// Inside the gallery app owner. _slugs is its section metadata list.
late final model = GalleryController(widget.database);
late final ActivityRouter router = ActivityRouter(
  initialLocation: '/overview',
  routes: [ActivityRoute(path: '/:section', name: 'gallery-section',
    builder: (_, state) => NotesPage(
      database: widget.database, controller: model,
      sectionIndex: _slugs.indexOf(state.pathParameters['section']!),
      onNavigate: (index) => router.goNamed('gallery-section',
        pathParameters: {'section': _slugs[index]}),
    ),
    routes: [ActivityRoute(path: 'notes/:id', name: 'note-detail',
      builder: (_, state) => NoteDetailPage(
        key: ValueKey(state.pathParameters['id']), controller: model,
        id: int.tryParse(state.pathParameters['id'] ?? ''),
      ))],
  )],
);
// MaterialApp.router(routerConfig: router.config)
router.goNamed('gallery-section', pathParameters: {'section': 'queries'});
final result = await router.pushNamed<String>('note-detail',
  pathParameters: {'section': 'crud', 'id': '42'});
// Inside the detail page: ActivityRouter.of(context).pop<String>('Viewed #42');
// Dispose router/model with the app owner. The database has its own owner.
""";

class NoteDetailPage extends StatefulWidget {
  const NoteDetailPage({super.key, required this.controller, required this.id});
  final GalleryController controller;
  final int? id;
  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  late final Future<Note?> note =
      widget.id == null
          ? Future.value(null)
          : widget.controller.dao.query().find(widget.id);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Note #${widget.id ?? '?'}')),
    body: GalleryExampleScope(
      modelCode: notesModelRecipe,
      viewCode: crudListSource,
      terminal: null,
      child: FutureBuilder<Note?>(
        future: note,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          if (snapshot.hasError) {
            return Center(
              child: SelectableText('Cannot read this note: ${snapshot.error}'),
            );
          }
          final value = snapshot.data;
          if (value == null) {
            return const Center(child: Text('Note not found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              GalleryPanel(
                'Typed route + model read',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      value.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(value.body),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed:
                          () => ActivityRouter.of(
                            context,
                          ).pop<String>('Viewed note #${value.id}'),
                      child: const Text('Return note result'),
                    ),
                  ],
                ),
              ),
              const GalleryPanel(
                'Navigation source',
                GallerySource(routesSource),
              ),
            ],
          );
        },
      ),
    ),
  );
}

const controllerSource = '''import 'package:activity/activity.dart';
import 'notes.dart';

class NotesState extends ActiveController {
  NotesState(this.dao);
  final NotesDao dao;
  final records = ActiveType<List<Note>>(const []);
  final lastError = ActiveType<String?>(null);
  @override
  List<ActiveType> get activities => [records, lastError];

  Future<void> reload() async {
    try {
      await activeAsync(() async {
        final rows = await dao.query().order(['id'], 'DESC').toList();
        if (isDisposed) return;
        records(List.unmodifiable(rows.whereType<Note>()));
        lastError(null);
      }, isRunningKey: 'load');
    } catch (error) {
      if (!isDisposed) lastError('\$error');
    }
  }
}
// Create once in the feature owner. Pass it to Activity / ActivitySelector.
// The view selects (records.value, actively, lastError.value).
// Dispose the controller with its owner; the application owns the database.''';
