import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drain real SQLite/worker futures before testing the resulting UI state.
/// pumpAndSettle alone cannot complete host I/O in the widget fake-async zone.
Future<void> settleGallery(WidgetTester tester) async {
  for (var i = 0; i < 400; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final loading = find.byWidgetPredicate(
      (widget) => widget is LinearProgressIndicator && widget.value == null,
    );
    if (loading.evaluate().isEmpty && !tester.binding.hasScheduledFrame) {
      return;
    }
  }
  throw StateError('Gallery operation did not settle within 10 seconds.');
}

/// Keep the real failure and stack in CLI output for browser widget tests.
void reportBrowserWidgetFailures() {
  reportTestException =
      (details, description) => Zone.current.handleUncaughtError(
        details.exception,
        details.stack ?? StackTrace.current,
      );
}
