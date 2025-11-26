import 'dart:js_interop';

@JS('window.localStorage.getItem')
external JSString? _getItem(JSString key);

@JS('window.localStorage.setItem')
external void _setItem(JSString key, JSString value);

@JS('window.localStorage.removeItem')
external void _removeItem(JSString key);

@JS('window.localStorage.clear')
external void _clear();

class WebStorage {
  static String? getItem(String key) {
    final v = _getItem(key.toJS);
    return v == null ? null : v.toDart;
  }

  static void setItem(String key, String value) {
    _setItem(key.toJS, value.toJS);
  }

  static void removeItem(String key) {
    _removeItem(key.toJS);
  }

  static void clear() {
    _clear();
  }
}
