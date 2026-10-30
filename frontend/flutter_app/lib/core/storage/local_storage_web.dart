// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'local_storage.dart';

class WebLocalStorage implements LocalStorage {
  @override
  Future<void> setItem(String key, String value) async {
    try {
      html.window.localStorage[key] = value;
    } catch (_) {}
  }

  @override
  Future<String?> getItem(String key) async {
    try {
      return html.window.localStorage[key];
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> removeItem(String key) async {
    try {
      html.window.localStorage.remove(key);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      html.window.localStorage.clear();
    } catch (_) {}
  }
}

LocalStorage createLocalStorage() => WebLocalStorage();
