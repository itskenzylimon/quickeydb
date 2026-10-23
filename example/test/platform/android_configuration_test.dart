@TestOn('vm')
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android has one Gradle DSL and uses the declarative Flutter plugin',
      () {
    for (final stem in [
      'settings.gradle',
      'build.gradle',
      'app/build.gradle'
    ]) {
      expect(File('android/$stem').existsSync(), isFalse,
          reason: 'Groovy files shadow the Kotlin configuration.');
      expect(File('android/$stem.kts').existsSync(), isTrue);
    }
    final settings = File('android/settings.gradle.kts').readAsStringSync();
    expect(settings, contains('dev.flutter.flutter-plugin-loader'));
    expect(settings, isNot(contains('app_plugin_loader.gradle')));
    final app = File('android/app/build.gradle.kts').readAsStringSync();
    expect(app, contains('dev.flutter.flutter-gradle-plugin'));
    expect(app, contains('org.jetbrains.kotlin.android'));
    final wrapper = File('android/gradle/wrapper/gradle-wrapper.properties')
        .readAsStringSync();
    final major = int.parse(RegExp(r'gradle-(\d+)\.').firstMatch(wrapper)![1]!);
    final agpMajor = int.parse(
        RegExp(r'com.android.application"\) version "(\d+)\.')
            .firstMatch(settings)![1]!);
    expect(major, greaterThanOrEqualTo(agpMajor),
        reason: 'Gradle 7 cannot load AGP 9.');
  });
}
