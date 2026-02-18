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
/// Reloads the page forcefully by clearing service workers first
Future<void> reloadPage() async {
  try {
    // Unregister all service workers to force a clean fetch on next load
    final registrations = await html.window.navigator.serviceWorker?.getRegistrations();
    if (registrations != null) {
      for (var reg in (registrations as List)) {
         await reg.unregister();
         debugPrint('Service worker unregistered');
      }
    }
    // Clear browser cache for this site if possible (Cache API)
    await html.window.caches?.keys().then((keys) {
      return Future.wait(keys.map((key) => html.window.caches!.delete(key)));
    });
  } catch (e) {
    debugPrint('Error during forceful reload: $e');
  }
  
  // Reload bypasses the browser cache
  html.window.location.href = html.window.location.href;
  html.window.location.reload();
}
