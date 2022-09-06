extension MapExtension on Map {
  Map<String, dynamic> toUpperKeys() =>
      map((key, value) => MapEntry(key.toUpperCase(), value));

  Map<String, String> toStringValues() =>
      map((key, value) => MapEntry('$key', '$value'));

  void nest(String name, [String symbol = '_']) {
    final Map<String, dynamic> nested = {};

    forEach((key, value) {
      if (key.startsWith('$name$symbol')) {
        if (key != name) {
          final nestedName = key.substring(name.length + symbol.length);

          if (nestedName.isNotEmpty) {
            nested[nestedName] = value;
          }
        } else if (this[name] is Map) {
          (this[name] as Map).forEach((nestKey, nestValue) {
            nested[nestKey] = nestValue;
          });
        }
      }
    });

    if (nested.isNotEmpty) {
      removeWhere((key, _) => key.startsWith('$name$symbol'));
      this[name] = nested;
    }
  }
}
