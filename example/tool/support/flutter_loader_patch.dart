/// Backports Flutter PR #192233 only when the exact legacy listener is present.
/// Does not touch application events, DOM prototypes or console error handling.
String repairFlutterWebLoader(String source) {
  const legacy = """document.addEventListener('dart-app-ready', function (e) {
   loader.parentNode.removeChild(loader);
   styleSheet.parentNode.removeChild(styleSheet);
});""";
  const fixed = """document.addEventListener('dart-app-ready', function (e) {
   loader.remove();
   styleSheet.remove();
}, { once: true });""";
  return source.replaceAll(legacy, fixed).replaceAll(
      legacy.replaceAll('\n', '\r\n'), fixed.replaceAll('\n', '\r\n'));
}
