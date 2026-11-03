import 'dart:convert';
import 'dart:io';

/// Rebuilds the worker without webdev/build_daemon and downloads matching wasm.
Future<void> main() async {
  final config = File('.dart_tool/package_config.json').absolute;
  final packages =
      (jsonDecode(await config.readAsString()) as Map)['packages'] as List;
  Uri root(String name) => config.uri.resolve(
    (packages.firstWhere((p) => p['name'] == name) as Map)['rootUri'] as String,
  );
  final worker = root(
    'sqflite_common_ffi_web',
  ).resolve('web/sqflite_sw.dart').toFilePath();
  final result = await Process.run(Platform.resolvedExecutable, [
    'compile',
    'js',
    '--packages=${config.path}',
    '-O2',
    '-o',
    'web/sqflite_sw.js',
    worker,
  ]);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) exit(result.exitCode);
  final pubspec = await File.fromUri(
    root('sqlite3').resolve('pubspec.yaml'),
  ).readAsString();
  final version = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspec)!.group(1)!;
  final uri = Uri.parse(
    'https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$version/sqlite3.wasm',
  );
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(uri)).close();
    if (response.statusCode != 200) {
      throw HttpException(
        'Falha ao baixar SQLite: ${response.statusCode}',
        uri: uri,
      );
    }
    final sink = File('web/sqlite3.wasm').openWrite();
    await response.pipe(sink);
    stdout.writeln('Worker e SQLite $version gerados em web/.');
  } finally {
    client.close();
  }
}
