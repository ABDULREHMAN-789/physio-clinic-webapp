import 'package:web/web.dart' as web;

/// Web implementation of local storage utility.
/// Uses package:web (dart:js_interop) — the modern replacement for dart:html.
String? getLocalStorageItem(String key) {
  try {
    final value = web.window.localStorage.getItem(key);
    return value;
  } catch (_) {
    return null;
  }
}

void setLocalStorageItem(String key, String value) {
  try {
    web.window.localStorage.setItem(key, value);
  } catch (_) {}
}

void removeLocalStorageItem(String key) {
  try {
    web.window.localStorage.removeItem(key);
  } catch (_) {}
}
