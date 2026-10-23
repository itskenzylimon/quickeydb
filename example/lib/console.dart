import 'package:activity/activity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gallery_controller.dart';
import 'package:quickeydb/quickeydb.dart';

/// IDE-style dock with bounded history retained when closed.
class DatabaseConsole extends StatefulWidget {
  const DatabaseConsole({
    super.key,
    required this.controller,
    required this.onClose,
  });
  final GalleryController controller;
  final VoidCallback onClose;
  @override
  State<DatabaseConsole> createState() => _DatabaseConsoleState();
}

class _DatabaseConsoleState extends State<DatabaseConsole> {
  bool sqlTab = false;
  @override
  Widget build(
    BuildContext context,
  ) => ActivitySelector<GalleryController, (List<String>, List<QueryLogEvent>)>(
    controller: widget.controller,
    select: (c) => (c.operations.value, c.queries.value),
    builder: (context, entriesState, _) {
      final model = widget.controller;
      final logging = model.database.queryLogging;
      final entries =
          sqlTab
              ? model.queries.value.map((e) => e.toString()).toList()
              : model.operations.value;
      return Material(
        color: const Color(0xff111820),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Color(0xffd7e3ee),
            fontFamily: 'monospace',
            fontSize: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xff49616e))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.terminal,
                              size: 17,
                              color: Colors.tealAccent,
                            ),
                            TextButton(
                              onPressed: () => setState(() => sqlTab = false),
                              child: Text(
                                'OUTPUT ${model.operations.value.length}',
                                style: TextStyle(
                                  color:
                                      !sqlTab
                                          ? Colors.tealAccent
                                          : Colors.white70,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() => sqlTab = true),
                              child: Text(
                                'SQL ${model.queries.value.length}',
                                style: TextStyle(
                                  color:
                                      sqlTab
                                          ? Colors.tealAccent
                                          : Colors.white70,
                                ),
                              ),
                            ),
                            if (kDebugMode && logging != null) ...[
                              Checkbox(
                                value: logging.includeSql,
                                onChanged:
                                    (value) => setState(
                                      () => logging.includeSql = value!,
                                    ),
                              ),
                              const Text('Raw SQL templates'),
                            ],
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy console',
                      color: Colors.white70,
                      onPressed:
                          () => Clipboard.setData(
                            ClipboardData(text: entries.join('\n\n')),
                          ),
                      icon: const Icon(Icons.copy, size: 16),
                    ),
                    IconButton(
                      tooltip: 'Clear console',
                      color: Colors.white70,
                      onPressed: () {
                        if (sqlTab) {
                          model.queries(const []);
                        } else {
                          model.operations(const []);
                        }
                      },
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Close console',
                      color: Colors.white70,
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  !kDebugMode
                      ? 'SQL diagnostics are disabled in production builds.'
                      : sqlTab
                      ? 'DAO statements only · values redacted · enable SQL before running a command'
                      : 'quickeydb > operation history · newest first',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (entries.isEmpty)
                      const SelectableText(
                        '> Run an example to see output here.',
                      ),
                    for (final entry in entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SelectableText('> $entry'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
