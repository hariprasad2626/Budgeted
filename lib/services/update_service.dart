import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'update_service_stub.dart'
    if (dart.library.html) 'update_service_web.dart' as platform;

class UpdateService {
  static const String _versionUrl = 'version.json';

  /// Checks for updates by comparing local timestamp with server timestamp
  static Future<void> checkForUpdate(BuildContext context, {bool manual = false}) async {
    if (!kIsWeb) return;

    try {
      // 1. Fetch server version.json (bypass cache with timestamp)
      final response = await http.get(Uri.parse('$_versionUrl?t=${DateTime.now().millisecondsSinceEpoch}'));
      
      if (response.statusCode == 200) {
        final serverData = json.decode(response.body);
        final int serverTimestamp = serverData['timestamp'] ?? 0;
        final String serverVersion = serverData['version'] ?? 'Unknown';

        // 2. Get local timestamp from platform-specific storage
        final int localTimestamp = platform.getLocalTimestamp();

        debugPrint('Update Check: Local=$localTimestamp, Server=$serverTimestamp');

        bool hasNewVersion = serverTimestamp > localTimestamp;

        // Special case: If local is 0 (fresh install/clear data), we usually assume we are latest.
        // UNLESS this is a manual check, in which case we might be on a stale cached version.
        if (localTimestamp == 0 && !manual) {
           // Fresh start auto-check: assume we are up to date to avoid annoying new users.
           platform.setLocalTimestamp(serverTimestamp);
           hasNewVersion = false; 
        }

        if (hasNewVersion) {
          if (context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('🌟 New Update Available!'),
                content: Text('Version $serverVersion is available. Please update to see the latest changes.'),
                actions: [
                  if (!manual) 
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Later'),
                    ),
                  ElevatedButton(
                    onPressed: () async {
                       platform.setLocalTimestamp(serverTimestamp);
                       await platform.reloadPage();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    child: const Text('Update Now', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }
        } else if (manual) {
           // Manual check and no update
           if (context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('You are up to date! (Version: $serverVersion)')),
             );
           }
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      if (manual && context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Check failed: $e')),
         );
      }
    }
  }
}
