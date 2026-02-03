$env:Path += ";C:\Users\Anil\Downloads\flutter_windows_3.38.9-stable\flutter\bin"

Write-Host "Searching for active Android Emulator..."
$devices = flutter devices | Out-String

# Look for standard emulator IDs or names
if ($devices -match "(emulator-\d+)") {
    $emulatorId = $matches[1]
    Write-Host "Found Emulator: $emulatorId"
    Write-Host "Starting Debug Mode..."
    flutter run -d $emulatorId
}
else {
    Write-Warning "No running emulator found!"
    Write-Host "Please open Android Studio AVD Manager and launch your emulator first."
    Write-Host "Available devices:"
    Write-Host $devices
}
