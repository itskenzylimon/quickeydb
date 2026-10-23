// Run directly: dart tool/repair_web_debug.dart --check
// Apply the upstream fix: dart tool/repair_web_debug.dart --apply
// Optional SDK override: --sdk=/absolute/path/to/flutter
import 'dart:io';
import 'support/flutter_loader_patch.dart';

void main(List<String> args) {
  if (args.any(
      (a) => a != '--apply' && a != '--check' && !a.startsWith('--sdk='))) {
    stderr.writeln(
        'Usage: dart tool/repair_web_debug.dart [--check|--apply] [--sdk=PATH]');
    exitCode = 64;
    return;
  }
  final override = args.where((a) => a.startsWith('--sdk=')).firstOrNull;
  Directory? sdk = override == null ? null : Directory(override.substring(6));
  if (sdk == null) {
    var candidate = File(Platform.resolvedExecutable).parent;
    while (true) {
      if (File(
              '${candidate.path}/packages/flutter_tools/lib/src/web/bootstrap.dart')
          .existsSync()) {
        sdk = candidate;
        break;
      }
      if (candidate.parent.path == candidate.path) {
        break;
      }
      candidate = candidate.parent;
    }
  }
  if (sdk == null) {
    throw StateError('Cannot locate Flutter SDK. Pass --sdk=PATH.');
  }
  final bootstrap =
      File('${sdk.path}/packages/flutter_tools/lib/src/web/bootstrap.dart');
  final original = bootstrap.readAsStringSync();
  final repaired = repairFlutterWebLoader(original);
  if (original == repaired) {
    stdout.writeln(
        'No known legacy Flutter loader listener found; SDK unchanged.');
    return;
  }
  if (!args.contains('--apply')) {
    stdout.writeln(
        'Affected Flutter SDK: ${sdk.path}\nUse --apply to backport Flutter PR #192233.');
    exitCode = 1;
    return;
  }
  final backup = File('${bootstrap.path}.quickeydb-backup');
  if (!backup.existsSync()) backup.writeAsStringSync(original, flush: true);
  bootstrap.writeAsStringSync(repaired, flush: true);
  // Invalidate the CLI snapshot so the next Flutter invocation uses the repair.
  for (final name in ['flutter_tools.snapshot', 'flutter_tools.stamp']) {
    final cached = File('${sdk.path}/bin/cache/$name');
    if (cached.existsSync()) cached.deleteSync();
  }
  stdout.writeln(
      'Applied upstream loader fix. Backup: ${backup.path}\nRestart flutter run; the Flutter CLI will rebuild its snapshot.');
}
