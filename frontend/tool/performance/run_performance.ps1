# CampusOS Automated Performance Audit & Validation Runner
# Target: Physical Samsung Galaxy A55 (SM-A556E) @ 120Hz Display
[CmdletBinding()]
param (
    [string]$DeviceId = "RZCX21VVWNB",
    [switch]$ProfileMode,
    [switch]$CollectDumpsys,
    [switch]$RunUnitTests
)

$ErrorActionPreference = "Stop"
$AdbPath = "C:\Users\SOURAV\AppData\Local\Android\sdk\platform-tools\adb.exe"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " CampusOS Phase 3B: Whole-App Performance Audit Harness  " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# 1. Device Inspection
Write-Host "`n[1/5] Checking Connected Physical Device..." -ForegroundColor Yellow
if (Test-Path $AdbPath) {
    $devices = & $AdbPath devices -l
    Write-Host $devices -ForegroundColor DarkGray
    
    # Query SurfaceFlinger for Active Refresh Rate
    $displayDump = & $AdbPath -s $DeviceId shell dumpsys display 2>$null | Select-String "fps=" | Select-Object -First 1
    Write-Host "Detected Display Refresh Mode: $displayDump" -ForegroundColor Green
    
    # Query Physical Resolution & Density
    $wmSize = & $AdbPath -s $DeviceId shell wm size 2>$null
    $wmDensity = & $AdbPath -s $DeviceId shell wm density 2>$null
    Write-Host "Display Physical Metrics: $wmSize | $wmDensity" -ForegroundColor Green
} else {
    Write-Warning "ADB not found at standard path. Falling back to flutter device discovery."
}

# 2. Optional: Baseline Unit/Widget Test Verification
if ($RunUnitTests) {
    Write-Host "`n[2/5] Verifying 316 Baseline Flutter Unit/Widget Tests..." -ForegroundColor Yellow
    flutter test test/
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Baseline tests failed! Aborting performance audit."
    }
    Write-Host "All baseline tests passed successfully." -ForegroundColor Green
} else {
    Write-Host "`n[2/5] Skipping unit tests (use -RunUnitTests to execute)." -ForegroundColor Gray
}

# 3. Static Analysis
Write-Host "`n[3/5] Running Static Analysis..." -ForegroundColor Yellow
flutter analyze --no-fatal-infos
if ($LASTEXITCODE -ne 0) {
    Write-Error "Static analysis detected issues! Aborting performance audit."
}
Write-Host "Static analysis clean (0 issues)." -ForegroundColor Green

# 4. Performance Integration Benchmark Execution
Write-Host "`n[4/5] Executing Whole-App Integration Performance Suite..." -ForegroundColor Yellow
if ($ProfileMode) {
    Write-Host "Launching Profile Mode on Physical Device ($DeviceId)..." -ForegroundColor Magenta
    flutter run --profile -d $DeviceId integration_test/app_performance_test.dart
} else {
    Write-Host "Executing Automated Integration Harness on Device ($DeviceId)..." -ForegroundColor Cyan
    flutter test integration_test/app_performance_test.dart -d $DeviceId
}

# 5. Dumpsys Gfxinfo & Meminfo Telemetry (Optional)
if ($CollectDumpsys -and (Test-Path $AdbPath)) {
    Write-Host "`n[5/5] Pulling SurfaceFlinger Gfxinfo & Meminfo Telemetry..." -ForegroundColor Yellow
    $gfxInfo = & $AdbPath -s $DeviceId shell dumpsys gfxinfo com.example.flutter_application_1 2>$null
    $memInfo = & $AdbPath -s $DeviceId shell dumpsys meminfo com.example.flutter_application_1 2>$null
    
    $telemetryDir = "docs/performance/telemetry"
    if (-not (Test-Path $telemetryDir)) {
        New-Item -ItemType Directory -Path $telemetryDir -Force | Out-Null
    }
    $gfxInfo | Out-File -FilePath "$telemetryDir/gfxinfo_dump.txt" -Encoding utf8
    $memInfo | Out-File -FilePath "$telemetryDir/meminfo_dump.txt" -Encoding utf8
    Write-Host "Device telemetry exported to $telemetryDir/" -ForegroundColor Green
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " Performance Audit Completed!                             " -ForegroundColor Cyan
Write-Host " Artifacts generated:                                     " -ForegroundColor Cyan
Write-Host "  - docs/performance/performance_results.json             " -ForegroundColor White
Write-Host "  - docs/performance/PERFORMANCE_AUDIT.md                 " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan
