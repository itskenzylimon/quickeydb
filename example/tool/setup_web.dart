// Run from example/: dart run tool/setup_web.dart
// Compiles the upstream worker without build_runner and fetches matching WASM.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

Future<void> main() async {
  final configFile = File('.dart_tool/package_config.json').absolute;
  final config = jsonDecode(await configFile.readAsString()) as Map;
  Uri packageRoot(String name) {
    final entry = (config['packages'] as List)
        .cast<Map>()
        .singleWhere((p) => p['name'] == name);
    final root = configFile.uri.resolve(entry['rootUri'] as String).toString();
    return Uri.parse(root.endsWith('/') ? root : '$root/');
  }

  final workerRoot = packageRoot('sqflite_common_ffi_web');
  final sqliteRoot = packageRoot('sqlite3');
  final pubspec =
      await File.fromUri(sqliteRoot.resolve('pubspec.yaml')).readAsString();
  final version =
      RegExp(r'^version:\s*[\x27\x22]?([^\s\x27\x22]+)', multiLine: true)
          .firstMatch(pubspec)![1]!;
  await Directory('web').create(recursive: true);
  final result = await Process.run(Platform.resolvedExecutable, [
    'compile',
    'js',
    '--packages=${configFile.path}',
    '--no-source-maps',
    '-O2',
    '-o',
    'web/sqflite_sw.js',
    workerRoot.resolve('web/sqflite_sw.dart').toFilePath(),
  ]);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    exitCode = result.exitCode;
    return;
  }
  final client = HttpClient();
  final target = File('web/sqlite3.wasm');
  final temporary = File('${target.path}.download');
  try {
    final uri = Uri.parse(
        'https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$version/sqlite3.wasm');
    stdout
        .writeln('Downloading SQLite $version WASM from its official release.');
    final response = await (await client.getUrl(uri)).close();
    if (response.statusCode != 200) {
      throw HttpException('WASM download returned ${response.statusCode}',
          uri: uri);
    }
    final bytes = BytesBuilder();
    await for (final chunk in response) {
      bytes.add(chunk);
    }
    final data = bytes.takeBytes();
    if (data.length < 8 ||
        data[0] != 0 ||
        data[1] != 97 ||
        data[2] != 115 ||
        data[3] != 109) {
      throw const FormatException('Downloaded file is not WebAssembly.');
    }
    await temporary.writeAsBytes(data, flush: true);
    await temporary.rename(target.path);
    stdout.writeln('SQLite worker and WASM are ready in web/.');
  } finally {
    client.close(force: true);
    if (await temporary.exists()) await temporary.delete();
    for (final suffix in ['.deps', '.map']) {
      final generated = File('web/sqflite_sw.js$suffix');
      if (await generated.exists()) await generated.delete();
    }
  }
}
