/// Stub implementation for non-web platforms
/// These functions do nothing on mobile/desktop

const String _prefsKey = 'app_build_timestamp';

int getLocalTimestamp() {
  // Not implemented for mobile - update service only runs on web
  return 0;
}

void setLocalTimestamp(int timestamp) {
  // Not implemented for mobile - update service only runs on web
}

Future<void> reloadPage() async {
  // Not implemented for mobile - update service only runs on web
}
