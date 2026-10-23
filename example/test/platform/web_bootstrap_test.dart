@TestOn('vm')
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter owns viewport and bootstrap is included once', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, isNot(contains('name="viewport"')));
    expect('src="flutter_bootstrap.js"'.allMatches(html), hasLength(1));
    expect(html, isNot(contains('flutter.js')));
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    expect(bootstrap, contains("canvasKitBaseUrl: 'canvaskit/'"));
    expect(bootstrap, isNot(contains('removeChild')));
  });
}
