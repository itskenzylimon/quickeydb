// Run from example/: dart run tool/test_web.dart
import 'dart:io';

Future<void> main(List<String> args) async {
  final fixtures = Directory('test/.web-assets');
  await fixtures.create(recursive: true);
  try {
    for (final name in ['sqlite3.wasm', 'sqflite_sw.js']) {
      await File('web/$name').copy('${fixtures.path}/$name');
    }
    final process = await Process.start('flutter', [
      'test',
      '--no-pub',
      '--platform',
      'chrome',
      ...(args.isEmpty ? ['test/browser'] : args),
    ]);
    await Future.wait(
        [stdout.addStream(process.stdout), stderr.addStream(process.stderr)]);
    exitCode = await process.exitCode;
  } finally {
    await fixtures.delete(recursive: true);
  }
}
