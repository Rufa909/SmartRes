param(
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
  [string]$AvdName = 'Medium_Phone',
  [switch]$SkipBuild,
  [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$properties = @{}
$propertiesFile = Join-Path $ProjectRoot 'smartresapp\android\local.properties'
if (Test-Path -LiteralPath $propertiesFile) {
  foreach ($line in Get-Content -LiteralPath $propertiesFile) {
    if ($line -match '^(sdk\.dir|flutter\.sdk)=(.*)$') {
      $properties[$matches[1]] = $matches[2].Replace('\\', '\').Replace('\:', ':')
    }
  }
}
$sdkCandidates = @(
  $env:ANDROID_HOME,
  $env:ANDROID_SDK_ROOT,
  $properties['sdk.dir'],
  (Join-Path $env:USERPROFILE 'AppData\Local\Android\Sdk'),
  (Join-Path $env:LOCALAPPDATA 'Android\Sdk')
)
$sdk = $sdkCandidates | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'platform-tools\adb.exe')) } | Select-Object -First 1
if (-not $sdk) { $sdk = Join-Path $env:USERPROFILE 'AppData\Local\Android\Sdk' }
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emulator = Join-Path $sdk 'emulator\emulator.exe'
$flutterCommand = Get-Command flutter.bat -ErrorAction SilentlyContinue
$flutter = if ($flutterCommand) { $flutterCommand.Source } elseif ($properties['flutter.sdk']) {
  Join-Path $properties['flutter.sdk'] 'bin\flutter.bat'
} else { 'C:\flutter\bin\flutter.bat' }
$apiUrl = 'http://127.0.0.1:4000/api/health'

function Test-ApiReady {
  try {
    & curl.exe --silent --fail --max-time 2 $apiUrl | Out-Null
    return $LASTEXITCODE -eq 0
  } catch { return $false }
}

function Fail($message) {
  Write-Host "`n[LOI] $message" -ForegroundColor Red
  if (-not $CheckOnly) { Read-Host 'Nhan Enter de dong' }
  exit 1
}

if (-not (Test-Path $ProjectRoot)) { Fail "Khong tim thay thu muc du an: $ProjectRoot" }
if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot 'apps\api\package.json'))) { Fail "Thu muc khong phai du an SmartRes: $ProjectRoot" }
if (-not (Test-Path $adb)) { Fail "Khong tim thay adb: $adb`nHay mo Android Studio va cai Android SDK Platform-Tools." }
if (-not (Test-Path $emulator)) { Fail "Khong tim thay Android Emulator: $emulator" }
if (-not (Test-Path $flutter)) { Fail "Khong tim thay Flutter tai $flutter" }
if (-not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) { Fail 'Khong tim thay npm. Hay cai Node.js va them vao PATH.' }

Write-Host "Du an: $ProjectRoot"
Write-Host "Flutter: $flutter"
Write-Host "Android SDK: $sdk"
Write-Host "May ao: $AvdName"
if ($CheckOnly) {
  $avds = @(& $emulator -list-avds)
  if ($LASTEXITCODE -ne 0 -or $avds -notcontains $AvdName) { Fail "Khong tim thay AVD '$AvdName'. May ao hien co: $($avds -join ', ')" }
  Write-Host 'Cac duong dan va may ao hop le.' -ForegroundColor Green
  exit 0
}

Write-Host '[1/5] Kiem tra va khoi dong backend...' -ForegroundColor Cyan
if (-not (Test-ApiReady)) {
  $staffCommand = "Set-Location -LiteralPath '{0}'; npm.cmd --workspace apps/api run dev:staff" -f $ProjectRoot.Replace("'", "''")
  Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile','-Command',('"' + $staffCommand + '"')
  $ready = $false
  for ($i = 0; $i -lt 60 -and -not $ready; $i++) {
    Start-Sleep -Seconds 1
    if (Test-ApiReady) { $ready = $true }
  }
  if (-not $ready) { Fail 'Backend chua san sang sau 60 giay. Kiem tra cua so backend va MySQL.' }
}

Write-Host '[2/5] Khoi dong may ao Android...' -ForegroundColor Cyan
& $adb start-server | Out-Null
$devices = (& $adb devices) | Select-String 'emulator-\d+\s+device'
if (-not $devices) {
  $avds = (& $emulator -list-avds)
  if ($avds -notcontains $AvdName) { Fail "Khong tim thay AVD '$AvdName'. Mo Android Studio > Device Manager de tao/doi ten may ao." }
  Start-Process -FilePath $emulator -WindowStyle Hidden -ArgumentList '-avd',$AvdName,'-no-snapshot-load' | Out-Null
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
if ($LASTEXITCODE -ne 0) { Fail 'Cai APK that bai. Kiem tra ket noi may ao.' }

Write-Host '[4/5] Mo app SmartRes Nhan vien...' -ForegroundColor Cyan
& $adb -s $serial shell am force-stop com.example.smartresapp
& $adb -s $serial shell monkey -p com.example.smartresapp 1 | Out-Null
Write-Host '[5/5] Hoan tat. Backend, may ao va app da san sang.' -ForegroundColor Green
Write-Host "Thiet bi: $serial | API trong may ao: http://10.0.2.2:4000"
Read-Host 'Nhan Enter de dong cua so nay'
