// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

const String _prefsKey = 'app_build_timestamp';

/// Gets the stored timestamp from localStorage
int getLocalTimestamp() {
  try {
    final stored = html.window.localStorage[_prefsKey];
    if (stored != null) {
      return int.tryParse(stored) ?? 0;
    }
  } catch (e) {
    debugPrint('Error reading localStorage: $e');
  }
  return 0;
}

/// Saves the timestamp to localStorage
void setLocalTimestamp(int timestamp) {
  try {
    html.window.localStorage[_prefsKey] = timestamp.toString();
  } catch (e) {
    debugPrint('Error writing localStorage: $e');
  }
}

/// Reloads the page
void reloadPage() {
  html.window.location.reload();
}
