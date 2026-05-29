Set-Location "C:\Users\bsc_inf_14_22\Desktop\SAPPT\android"
# Stop any running Gradle daemons
if (Test-Path ".\\gradlew") { .\\gradlew --stop }
# Kill any lingering java processes that may hold ports (e.g., 5005, 5030)
Get-Process -Name java -ErrorAction SilentlyContinue | Stop-Process -Force
# Remove Gradle daemon caches
$gradleDaemonPath = "$HOME\.gradle\daemon"
if (Test-Path $gradleDaemonPath) { Remove-Item -Recurse -Force "$gradleDaemonPath\*" }
# Clean project-specific .gradle folder
$projectGradlePath = "C:\Users\bsc_inf_14_22\Desktop\SAPPT\android\.gradle"
if (Test-Path $projectGradlePath) { Remove-Item -Recurse -Force "$projectGradlePath\*" }
# Ensure gradle.properties disables daemon
$propFile = "C:\Users\bsc_inf_14_22\Desktop\SAPPT\android\gradle.properties"
if (-not (Test-Path $propFile)) {
    Set-Content -Path $propFile -Value "org.gradle.daemon=false"
} else {
    if (-not (Select-String -Path $propFile -Pattern "org\.gradle\.daemon" -Quiet)) {
        Add-Content -Path $propFile -Value "`norg.gradle.daemon=false"
    }
}
Write-Host "Gradle cleanup completed."
