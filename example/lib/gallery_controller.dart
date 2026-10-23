import 'dart:convert';
import 'package:activity/activity.dart';
import 'package:flutter/material.dart';
import 'package:quickeydb/quickeydb.dart';
import 'notes.dart';

class TerminalRun {
  const TerminalRun({
    required this.command,
    this.output = '',
    this.error,
    this.running = false,
    this.elapsedMs = 0,
  });
  final String command, output;
  final String? error;
  final bool running;
  final int elapsedMs;
}

/// The app owns this controller; screens borrow it and the database handle.
class GalleryController extends ActiveController {
  GalleryController(this.database) {
    database.queryLogging?.addListener(_recordQuery);
  }
  final queries = ActiveType<List<QueryLogEvent>>(const []);
  void _recordQuery(QueryLogEvent event) {
    if (!isDisposed) {
      queries(List.unmodifiable([event, ...queries.value].take(120)));
    }
  }

  @override
  Future<void> dispose() {
    database.queryLogging?.removeListener(_recordQuery);
    return super.dispose();
  }

  final QuickeyDBImpl database;
  final notes = ActiveType<List<Note>>(const []);
  final tables = ActiveType<List<Map<String, Object?>>>(const []);
  final allocated = ActiveInt(0);
  final sqlite = ActiveString('…');
  final lastError = ActiveType<String?>(null);
  final results = ActiveMap<int, String>({});
  final terminals = ActiveMap<int, TerminalRun>({});
  final operations = ActiveType<List<String>>(const []);
  final theme = ActiveType<ThemeMode>(ThemeMode.light);
  final accent = ActiveInt(0);
  @override
  List<ActiveType> get activities => [
    notes,
    tables,
    allocated,
    sqlite,
    lastError,
    results,
    terminals,
    operations,
    queries,
    theme,
    accent,
  ];
  NotesDao get dao => database.get<NotesDao>()!;

  Future<void> reload() async {
    final rows = await dao.query().order(['id'], 'DESC').toList();
    final definitions = await database.database!.rawQuery(
      "SELECT name, sql FROM sqlite_master WHERE type = 'table' AND name NOT GLOB 'sqlite_*' AND name NOT GLOB '__quickey*' ORDER BY name",
    );
    final pages = await database.database!.rawQuery('PRAGMA page_count');
    final size = await database.database!.rawQuery('PRAGMA page_size');
    final version = await database.database!.rawQuery(
      'SELECT sqlite_version() AS version',
    );
    if (isDisposed) return;
    notes(List.unmodifiable(rows.whereType<Note>()));
    tables(List.unmodifiable(definitions));
    allocated(
      (pages.first.values.first as int) * (size.first.values.first as int),
    );
    sqlite(version.first['version'] as String);
  }

  Future<int> save(Note note) async {
    final id = note.id == null ? await dao.create(note) as int : note.id!;
    if (note.id != null) await dao.update(note);
    await reload();
    return id;
  }

  void publish(int section, Object? value) {
    if (isDisposed) return;
    final output = const JsonEncoder.withIndent('  ').convert(value);
    results.setEntry(section, output);
    final current = terminals[section];
    terminals.setEntry(
      section,
      TerminalRun(
        command: current?.command ?? 'Result',
        output: output,
        running: current?.running ?? false,
      ),
    );
  }

  void record(String message) {
    if (!isDisposed) {
      operations(
        List.unmodifiable(
          [
            '${DateTime.now().toUtc().toIso8601String()} $message',
            ...operations.value,
          ].take(80),
        ),
      );
    }
  }

  Future<void> run(
    int section,
    String command,
    Future<void> Function() action,
  ) async {
    if (isDisposed || actively) return;
    lastError(null);
    terminals.setEntry(section, TerminalRun(command: command, running: true));
    final watch = Stopwatch()..start();
    String? failure;
    try {
      await activeAsync(action, isRunningKey: 'database');
    } catch (error) {
      failure = '$error';
      if (!isDisposed) lastError(failure);
    } finally {
      if (!isDisposed) {
        final current = terminals[section];
        terminals.setEntry(
          section,
          TerminalRun(
            command: command,
            output:
                current?.output.isNotEmpty == true
                    ? current!.output
                    : failure == null
                    ? 'Completed successfully.'
                    : '',
            error: failure,
            elapsedMs: watch.elapsedMilliseconds,
          ),
        );
        record(
          '$command · ${failure == null ? 'completed' : 'failed'} in ${watch.elapsedMilliseconds} ms',
        );
      }
    }
  }
}
