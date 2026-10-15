param(
  [string]$ProjectRoot = 'D:\DoAn4\SmartRes',
  [string]$AvdName = 'Medium_Phone',
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emulator = Join-Path $sdk 'emulator\emulator.exe'
$flutter = 'C:\flutter\bin\flutter.bat'
$apiUrl = 'http://127.0.0.1:4000/api/health'

function Test-ApiReady {
  try {
    & curl.exe --silent --fail --max-time 2 $apiUrl | Out-Null
    return $LASTEXITCODE -eq 0
  } catch { return $false }
}

function Fail($message) {
  Write-Host "`n[LOI] $message" -ForegroundColor Red
  Read-Host 'Nhan Enter de dong'
  exit 1
}

if (-not (Test-Path $ProjectRoot)) { Fail "Khong tim thay thu muc du an: $ProjectRoot" }
if (-not (Test-Path $adb)) { Fail "Khong tim thay adb: $adb`nHay mo Android Studio va cai Android SDK Platform-Tools." }
if (-not (Test-Path $emulator)) { Fail "Khong tim thay Android Emulator: $emulator" }
if (-not (Test-Path $flutter)) { Fail "Khong tim thay Flutter tai $flutter" }

Write-Host '[1/5] Kiem tra va khoi dong backend...' -ForegroundColor Cyan
if (-not (Test-ApiReady)) {
  Start-Process powershell.exe -ArgumentList '-NoExit','-NoProfile','-Command',("Set-Location -LiteralPath '{0}'; npm --workspace apps/api run dev:staff" -f $ProjectRoot)
  $ready = $false
  1..60 | ForEach-Object {
    Start-Sleep -Seconds 1
    if (Test-ApiReady) { $ready = $true; break }
  }
  if (-not $ready) { Fail 'Backend chua san sang sau 60 giay. Kiem tra cua so backend va MySQL.' }
}

Write-Host '[2/5] Khoi dong may ao Android...' -ForegroundColor Cyan
& $adb start-server | Out-Null
$devices = (& $adb devices) | Select-String 'emulator-\d+\s+device'
if (-not $devices) {
  $avds = (& $emulator -list-avds)
  if ($avds -notcontains $AvdName) { Fail "Khong tim thay AVD '$AvdName'. Mo Android Studio > Device Manager de tao/doi ten may ao." }
  Start-Process -FilePath $emulator -ArgumentList '-avd',$AvdName,'-no-snapshot-load' | Out-Null
  $connected = $false
  for ($i = 0; $i -lt 90 -and -not $connected; $i++) {
    Start-Sleep -Seconds 2
    $devices = (& $adb devices) | Select-String 'emulator-\d+\s+device'
    if ($devices) { $connected = $true }
  }
  if (-not $connected) { Fail 'May ao khong ket noi sau 3 phut.' }
}
$serial = (($devices -split '\s+')[0])
$bootReady = $false
for ($i = 0; $i -lt 90 -and -not $bootReady; $i++) {
  $boot = (& $adb -s $serial shell getprop sys.boot_completed 2>$null).Trim()
  if ($boot -eq '1') { $bootReady = $true } else { Start-Sleep -Seconds 2 }
}
if (-not $bootReady) { Fail 'May ao da ket noi nhung Android chua khoi dong xong.' }
& $adb -s $serial reverse tcp:4000 tcp:4000 2>$null | Out-Null

Write-Host '[3/5] Nap lai APK app nhan vien...' -ForegroundColor Cyan
$apk = Join-Path $ProjectRoot 'smartresapp\build\app\outputs\flutter-apk\app-debug.apk'
if (-not $SkipBuild -or -not (Test-Path $apk)) {
  Push-Location (Join-Path $ProjectRoot 'smartresapp')
  try { & $flutter build apk --debug --target-platform android-x64 -t lib/main_staff.dart; if ($LASTEXITCODE -ne 0) { Fail 'Build APK that bai.' } }
  finally { Pop-Location }
}
& $adb -s $serial install -r $apk | Out-Null

Write-Host '[4/5] Mo app SmartRes Nhan vien...' -ForegroundColor Cyan
& $adb -s $serial shell am force-stop com.example.smartresapp
& $adb -s $serial shell monkey -p com.example.smartresapp 1 | Out-Null
Write-Host '[5/5] Hoan tat. Backend, may ao va app da san sang.' -ForegroundColor Green
Write-Host "Thiet bi: $serial | API trong may ao: http://10.0.2.2:4000"
Read-Host 'Nhan Enter de dong cua so nay'
