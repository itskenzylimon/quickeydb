import 'package:collection/collection.dart' show IterableExtension;

extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull {
    try {
      return first;
    } catch (_) {
      return null;
    }
  }

  T? get lastOrNull {
    try {
      return last;
    } catch (_) {
      return null;
    }
  }

  bool hasIndex(var index) => indexOrNull(index) != null;

  T? indexOrNull(final int index) {
    try {
      return elementAt(index);
    } catch (e) {
      return null;
    }
  }

  bool isExists(bool Function(T element) test) {
    try {
      return find(test) != null;
    } catch (e) {
      return false;
    }
  }

  T? find(bool Function(T element) test) {
    return firstWhereOrNull(test);
  }

  List<dynamic> get flatten {
    final flattened = [];

    for (final item in this) {
      item is List ? flattened.addAll(item.flatten) : flattened.add(item);
    }

    return flattened;
  }

  Map<K, List<T>> groupBy<K>(K Function(T) fn) => fold(
      <K, List<T>>{},
      (Map<K, List<T>> map, T element) =>
          map..putIfAbsent(fn(element), () => <T>[]).add(element));
}
