import 'package:flutter_test/flutter_test.dart';
import '../../example/tool/support/flutter_loader_patch.dart';

void main() {
  test(
      'upstream loader fix is narrow, safe to repeat and handles repeated readiness',
      () {
    const old = """prefix
 document.addEventListener('unrelated', () => {});
document.addEventListener('dart-app-ready', function (e) {
   loader.parentNode.removeChild(loader);
   styleSheet.parentNode.removeChild(styleSheet);
});
suffix""";
    final result = repairFlutterWebLoader(old);
    expect(result, contains('loader.remove();'));
    expect(result, contains('styleSheet.remove();'));
    expect(result, contains('{ once: true }'));
    expect(result, isNot(contains('parentNode.removeChild')));
    expect(
        result, startsWith("prefix\n document.addEventListener('unrelated'"));
    expect(result, endsWith('suffix'));
    expect(repairFlutterWebLoader(result), result);
    final windows = repairFlutterWebLoader(old.replaceAll('\n', '\r\n'));
    expect(windows, contains('loader.remove();\r\n'));
    expect(windows, isNot(contains('parentNode.removeChild')));
    expect(
        repairFlutterWebLoader('different SDK layout'), 'different SDK layout');
  });
}
