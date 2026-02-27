# Deployment Guide

This document outlines the three methods available to deploy or build the Cost Center Accounting application.

---

## 1. Automated Deployment (GitHub Actions)
This is the **preferred method** for the Web application.

*   **Trigger**: Any push or merge to the `main` branch.
*   **Process**: 
    1.  GitHub Actions detects the change.
    2.  It installs the Flutter environment.
    3.  It builds the web application release.
    4.  It automatically deploys the build to Firebase Hosting.
*   **Verification**: Check the [GitHub Actions tab](https://github.com/hariprasad2626/Budgeted/actions) to monitor the progress.

---

## 2. Manual Web Deployment (Local Terminal)
Use this if you want to deploy immediately without pushing to GitHub, or for testing.

**Prerequisites**: Firebase CLI initialized (`firebase login`).

### Step-by-Step:
1.  **Build the Web App**:
    ```powershell
    flutter build web --release --no-tree-shake-icons
    ```
2.  **Deploy to Firebase**:
    ```powershell
    firebase deploy --only hosting
    ```
3.  **Bust Cache (Optional but Recommended)**: Increment the `appVersion` in `lib/providers/accounting_provider.dart` and the version tag in `web/index.html` (e.g., `?v=71`) before building.

---

## 3. Manual Android Build (APK)
To generate a release APK for mobile devices.

### Using the Automated Script:
Run the provided PowerShell script in the root directory:
```powershell
.\setup_and_build.ps1
```
This script will:
*   Locate your Flutter SDK.
*   Check for the Android SDK.
*   Run `flutter pub get`.
*   Generate the release APK at: `build\app\outputs\flutter-apk\app-release.apk`.

### Manual Command:
```powershell
flutter build apk --release
```

---

## Important Links
*   **Live Web App**: [https://accounts-app-c87ea.web.app](https://accounts-app-c87ea.web.app)
*   **Firebase Console**: [https://console.firebase.google.com/project/accounts-app-c87ea/overview](https://console.firebase.google.com/project/accounts-app-c87ea/overview)
*   **GitHub Repository**: [https://github.com/hariprasad2626/Budgeted](https://github.com/hariprasad2626/Budgeted)
