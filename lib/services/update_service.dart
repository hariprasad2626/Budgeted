import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class UpdateService {
  static const String _versionUrl = 'version.json';
  static const String _prefsKey = 'app_build_timestamp';

  /// Checks for updates by comparing local timestamp with server timestamp
  static Future<void> checkForUpdate(BuildContext context) async {
    if (!kIsWeb) return;

    try {
      // 1. Fetch server version.json (bypass cache with timestamp)
      final response = await http.get(Uri.parse('$_versionUrl?t=${DateTime.now().millisecondsSinceEpoch}'));
      
      if (response.statusCode == 200) {
        final serverData = json.decode(response.body);
        final int serverTimestamp = serverData['timestamp'] ?? 0;

        // 2. Get local timestamp
        final prefs = await SharedPreferences.getInstance();
        final int localTimestamp = prefs.getInt(_prefsKey) ?? 0;

        debugPrint('Update Check: Local=$localTimestamp, Server=$serverTimestamp');

        // 3. If server is newer, prompt user
        // 3. If server is newer, prompt user
        if (serverTimestamp > localTimestamp) {
          if (context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('🌟 New Update Available!'),
                content: const Text('A new version of the app is ready. Please update to see the latest changes.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Later'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                       await prefs.setInt(_prefsKey, serverTimestamp);
                       html.window.location.reload();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    child: const Text('Update Now', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }
        } else {
           // If first run, sync with server
           if (localTimestamp == 0) {
             await prefs.setInt(_prefsKey, serverTimestamp);
           }
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }
}
