# Deployment Guide

This document outlines the versioning and deployment methods available for the Cost Center Accounting application.

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

## 2. Pushing Updates to GitHub (Versioning)
Always push your changes to keep your repository in sync and to backup your work.

### Commands:
```powershell
# 1. Stage your changes
git add .

# 2. Commit with a meaningful message
git commit -m "Brief description of changes (e.g., 'Implemented list generalization')"

# 3. Push to main branch
git push origin main
```

---

## 3. Web Deployment Workflow (MANDATORY)
To ensure version consistency and trigger GitHub release popups/actions, ALWAYS push your code to GitHub whenever you deploy the web app.

### Step-by-Step Deployment:
1.  **Bust Cache (Required)**: Increment the version tag in `web/index.html` (e.g., `<script src="flutter_bootstrap.js?v=87" async></script>`).
2.  **Commit and Push to GitHub (MANDATORY)**:
    ```powershell
    git add .
    git commit -m "Deploying latest UI fixes and version bump"
    git push origin main
    ```
3.  **Deploy to Firebase (If GitHub Actions is not active or for immediate testing)**:
    ```powershell
    flutter build web --release 
    firebase deploy --only hosting
    ```

---

## 4. Manual Android Build (APK)
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
