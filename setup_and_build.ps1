# Setup and Build Script for Cost Center Accounting App

# 1. Detect Flutter
$manualPath = "C:\Users\Anil\Downloads\flutter_windows_3.38.9-stable\flutter\bin"
if (!(Test-Path $manualPath)) {
    $manualPath = "C:\Users\Anil\Downloads\flutter\bin"
    if (!(Test-Path $manualPath)) {
        $manualPath = "C:\Users\Anil\Downloads\flutter_windows_3.38.9-stable\flutter\bin"
    }
}

if (!(Get-Command flutter -ErrorAction SilentlyContinue)) {
    if (Test-Path $manualPath) {
        Write-Host "Detected manual Flutter download at: $manualPath"
        $env:Path += ";$manualPath"
    } else {
        Write-Error "Flutter SDK not found. Please extract your Flutter download and update the 'manualPath' in this script."
        exit
    }
}

# Refresh environment path
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
if (Test-Path $manualPath) { $env:Path += ";$manualPath" }

# 2. Check for Android SDK
Write-Host "`nFlutter is ready. Checking for Android SDK..."

$sdkPaths = @(
    "$env:LOCALAPPDATA\Android\Sdk",
    "C:\Android\sdk",
    "C:\Program Files (x86)\Android\android-sdk",
    "C:\Users\$env:USERNAME\AppData\Local\Android\Sdk"
)

$foundSdk = $null
foreach ($path in $sdkPaths) {
    if (Test-Path "$path\platform-tools") {
        $foundSdk = $path
        break
    }
}

if ($null -eq $foundSdk) {
    Write-Warning "!!! Android SDK NOT FOUND !!!"
    Write-Host "`nTo build an APK, you MUST have the Android SDK installed."
    Write-Host "1. Download Android Studio: https://developer.android.com/studio"
    Write-Host "2. Install it and complete the Setup Wizard (it will download the SDK)."
    Write-Host "3. Once installed, run this script again."
    Write-Host "`nIf you already have it, please enter the path to your Android SDK folder:"
    $inputPath = Read-Host "(Example: C:\Users\Anil\AppData\Local\Android\Sdk)"
    if ($inputPath -and (Test-Path "$inputPath\platform-tools")) {
        $foundSdk = $inputPath
    } else {
        exit
    }
}

Write-Host "Configuring Flutter to use Android SDK at: $foundSdk"
flutter config --android-sdk "$foundSdk"
flutter config --no-analytics

Write-Host "`n[ACTION REQUIRED] Please accept the Android licenses when prompted below:"
Write-Host "Type 'y' and press Enter for every prompt."
flutter doctor --android-licenses

# 3. Build APK
Write-Host "`nInstalling project dependencies..."
flutter pub get

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nBuilding Final APK (Release Mode)..."
    flutter build apk --release

    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n================================================================="
        Write-Host "SUCCESS! Your APK is located at:"
        Write-Host "C:\Users\Anil\Documents\Accounts\build\app\outputs\flutter-apk\app-release.apk"
        Write-Host "================================================================="
    } else {
        Write-Error "Build failed. This usually happens if the Android SDK is incomplete."
    }
} else {
    Write-Error "Failed to install dependencies."
}
