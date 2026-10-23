import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gallery_controller.dart';

const galleryAccents = [
  Color(0xFFEC2182),
  Color(0xFFF38141),
  Color(0xFFF8C612),
  Color(0xFFBE185D),
  Color(0xFFB45309),
];

ThemeData galleryTheme(Brightness brightness, int accent) {
  final scheme = ColorScheme.fromSeed(
    seedColor: galleryAccents[accent],
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: brightness == Brightness.light
        ? const Color(0xFFFFF8F5)
        : const Color(0xFF20171C),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .6)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.all(14),
    ),
    dividerColor: scheme.outlineVariant.withValues(alpha: .55),
  );
}

class GalleryPill extends StatelessWidget {
  const GalleryPill(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final ink = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class GalleryPanel extends StatelessWidget {
  const GalleryPanel(this.title, this.child, {super.key});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(22), child: child),
        ],
      ),
    ),
  );
}

class GalleryCode extends StatelessWidget {
  const GalleryCode(this.code, {super.key});
  final String code;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .04),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Code copied')));
              }
            },
            icon: const Icon(Icons.copy_outlined, size: 16),
            label: const Text('Copy code'),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 440),
          child: SingleChildScrollView(
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.65,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class GalleryDemo extends StatefulWidget {
  const GalleryDemo({
    super.key,
    required this.title,
    required this.description,
    required this.code,
    required this.child,
    this.showTerminalInPreview = false,
  });
  final bool showTerminalInPreview;
  final String title, description, code;
  final Widget child;
  @override
  State<GalleryDemo> createState() => _GalleryDemoState();
}

class _GalleryDemoState extends State<GalleryDemo> {
  bool source = false;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: source ? 'Show live preview' : 'Show source code',
                  onPressed: () => setState(() => source = !source),
                  icon: Icon(source ? Icons.visibility_outlined : Icons.code),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Offstage(offstage: source, child: widget.child),
                if (!source && widget.showTerminalInPreview)
                  GalleryTerminal(GalleryExampleScope.of(context)?.terminal),
                if (source) GallerySource(widget.code, showTerminal: true),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class GalleryGuidance extends StatelessWidget {
  const GalleryGuidance({
    super.key,
    required this.doText,
    required this.dontText,
  });
  final String doText, dontText;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: LayoutBuilder(
      builder: (_, constraints) {
        Widget tile(bool positive) {
          final color = positive
              ? const Color(0xFF087F5B)
              : const Color(0xFFBE344A);
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: .15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  positive
                      ? Icons.check_circle_outline
                      : Icons.do_not_disturb_on_outlined,
                  size: 20,
                  color: color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        positive ? 'Do' : "Don't",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        positive ? doText : dontText,
                        style: const TextStyle(fontSize: 13, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return constraints.maxWidth < 720
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [tile(true), const SizedBox(height: 12), tile(false)],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: tile(true)),
                  const SizedBox(width: 16),
                  Expanded(child: tile(false)),
                ],
              );
      },
    ),
  );
}

/// References belong to the current example, rather than an unrelated cookbook.
class GalleryExampleScope extends InheritedWidget {
  const GalleryExampleScope({
    super.key,
    required this.modelCode,
    required this.viewCode,
    required this.terminal,
    required super.child,
  });
  final String? modelCode, viewCode;
  final TerminalRun? terminal;
  static GalleryExampleScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GalleryExampleScope>();
  @override
  bool updateShouldNotify(GalleryExampleScope oldWidget) =>
      modelCode != oldWidget.modelCode ||
      viewCode != oldWidget.viewCode ||
      terminal != oldWidget.terminal;
}

class GalleryTerminal extends StatelessWidget {
  const GalleryTerminal(this.run, {super.key});
  final TerminalRun? run;
  @override
  Widget build(BuildContext context) {
    final data = run;
    final output = data == null
        ? 'Run this example to see actual database output.'
        : data.error ??
              (data.output.isEmpty && data.running
                  ? 'Awaiting database result…'
                  : data.output);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131D19),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 17, color: Color(0xFFA7F3D0)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Result terminal',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  data == null
                      ? 'Ready'
                      : data.running
                      ? 'Running'
                      : data.error != null
                      ? 'Error'
                      : '${data.elapsedMs} ms',
                  style: TextStyle(
                    color: data?.error != null
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFFA7F3D0),
                    fontSize: 11,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy terminal output',
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: output)),
                  icon: const Icon(
                    Icons.copy_outlined,
                    size: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          if (data != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                '> ${data.command}',
                style: const TextStyle(
                  color: Color(0xFFA7F3D0),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: SingleChildScrollView(
                child: SelectableText(
                  output,
                  style: TextStyle(
                    color: data?.error != null
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFFE2E8E5),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.65,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GallerySource extends StatefulWidget {
  const GallerySource(this.code, {super.key, this.showTerminal = false});
  final String code;
  final bool showTerminal;
  @override
  State<GallerySource> createState() => _GallerySourceState();
}

class _GallerySourceState extends State<GallerySource> {
  String selected = 'API code';
  @override
  Widget build(BuildContext context) {
    final references = GalleryExampleScope.of(context);
    final sources = {
      'API code': widget.code,
      if (references?.viewCode != null) 'View code': references!.viewCode!,
      if (references?.modelCode != null) 'Model / DAO': references!.modelCode!,
    };
    final code = sources[selected] ?? widget.code;
    final pane = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in sources.keys)
              ChoiceChip(
                label: Text(label),
                selected: selected == label,
                onSelected: (_) => setState(() => selected = label),
              ),
          ],
        ),
        GalleryCode(code),
      ],
    );
    if (!widget.showTerminal) return pane;
    return LayoutBuilder(
      builder: (_, constraints) => constraints.maxWidth >= 900
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: pane),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: GalleryTerminal(references?.terminal)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [pane, GalleryTerminal(references?.terminal)],
            ),
    );
  }
}
