import 'dart:html' as html;

/// Web implementation of local storage utility.
/// Operates directly on the browser's window.localStorage.
String? getLocalStorageItem(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void setLocalStorageItem(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {}
}

void removeLocalStorageItem(String key) {
  try {
    html.window.localStorage.remove(key);
  } catch (_) {}
}
