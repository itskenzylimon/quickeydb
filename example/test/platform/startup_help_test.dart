import 'package:example/startup_help.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web instructions take precedence over the browser host OS', () {
    final help = startupHelp(isWeb: true, platform: TargetPlatform.macOS);
    expect(help, contains('localhost or HTTPS'));
    expect(help, isNot(contains('macos/Runner')));
  });
  test('native instructions match the platform and preserve keys', () {
    const expected = {
      TargetPlatform.macOS: 'Keychain Sharing',
      TargetPlatform.iOS: 'iOS Keychain',
      TargetPlatform.linux: 'libsecret/jsoncpp',
      TargetPlatform.windows: 'Visual Studio',
      TargetPlatform.android: 'device logs',
      TargetPlatform.fuchsia: 'not been configured',
    };
    for (final entry in expected.entries) {
      final help = startupHelp(isWeb: false, platform: entry.key);
      expect(help, contains(entry.value));
      expect(help, contains('restore the original key'));
      expect(help, isNot(contains('SQLite worker')));
    }
  });
}
