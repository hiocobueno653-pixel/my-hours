# 一键出包：版本递增 → 静态检查 → 测试 → 分 ABI 构建 → 校验签名 → 汇总产物。
#
#   .\tool\release.ps1                      # 当前版本，full，不改版本号
#   .\tool\release.ps1 -Bump patch          # 1.3.0+6 → 1.3.1+7
#   .\tool\release.ps1 -Flavor hours -Bump minor -DartDefine HOURS_ONLY=true
#
# 为什么需要脚本：双 flavor、分 ABI、签名校验、产物命名这几步手工做一次就会漏一步，
# 而漏掉 versionCode 递增的后果是用户升不了级。

[CmdletBinding()]
param(
    [ValidateSet('full', 'hours')]
    [string]$Flavor = 'full',

    [ValidateSet('none', 'patch', 'minor', 'major')]
    [string]$Bump = 'none',

    [string[]]$DartDefine = @(),

    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$flutter = if ($env:FLUTTER_BIN) { $env:FLUTTER_BIN } else { 'E:\tools\flutter\bin\flutter.bat' }
if (-not (Test-Path $flutter)) { throw "Flutter 未找到：$flutter（可用 FLUTTER_BIN 指定）" }

# ---- 1. 读取当前版本（真正的递增放在验证通过之后） ---------------------------
$pubspecPath = Join-Path $root 'pubspec.yaml'
$pubspec = Get-Content $pubspecPath -Raw
if ($pubspec -notmatch '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)') {
    throw 'pubspec.yaml 的 version 不是 x.y.z+n 形式'
}
$currentVersion = "$($Matches[1]).$($Matches[2]).$($Matches[3])+$($Matches[4])"
Write-Host "当前版本: $currentVersion" -ForegroundColor DarkGray

# flavor 与编译期开关必须一致：hours 变体少了 HOURS_ONLY 会产出
# 「名字是工时版、功能是完整版、数据写进独立 applicationId」的错包，
# 三件事都不报错，只有用户会发现数据不通。
if ($Flavor -eq 'hours' -and ($DartDefine -notcontains 'HOURS_ONLY=true')) {
    $DartDefine += 'HOURS_ONLY=true'
    Write-Host '已自动补上 --dart-define=HOURS_ONLY=true（hours 变体必需）' -ForegroundColor DarkGray
}
if ($Flavor -eq 'full' -and ($DartDefine -contains 'HOURS_ONLY=true')) {
    throw 'full 变体不应带 HOURS_ONLY=true：请改用 -Flavor hours'
}

# ---- 2. 检查 ---------------------------------------------------------------
Write-Host "`n[1/5] flutter analyze" -ForegroundColor Cyan
& $flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'analyze 未通过' }

if (-not $SkipTests) {
    Write-Host "`n[2/5] flutter test" -ForegroundColor Cyan
    & $flutter test
    if ($LASTEXITCODE -ne 0) { throw '测试未通过' }
} else {
    Write-Host "`n[2/5] 跳过测试（-SkipTests）" -ForegroundColor DarkYellow
}

# ---- 3. 递增版本号（只在前面的检查全部通过后改文件） -------------------------
# 原来先改 pubspec 再跑测试：一旦测试失败，工作区留下一个已递增却没出包的版本，
# 下次构建的 versionCode 就白跳一格。
if ($Bump -ne 'none') {
    $major = [int]$Matches[1]; $minor = [int]$Matches[2]
    $patch = [int]$Matches[3]; $build = [int]$Matches[4]
    switch ($Bump) {
        'patch' { $patch++; }
        'minor' { $minor++; $patch = 0; }
        'major' { $major++; $minor = 0; $patch = 0; }
    }
    $build++
    $newVersion = "$major.$minor.$patch+$build"
    $pubspec = $pubspec -replace '(?m)^version:\s*\d+\.\d+\.\d+\+\d+', "version: $newVersion"
    Set-Content $pubspecPath $pubspec -NoNewline
    Write-Host "版本: $currentVersion → $newVersion" -ForegroundColor Green
} else {
    Write-Host "版本: $currentVersion（未改）" -ForegroundColor DarkGray
}

# ---- 4. 构建 ---------------------------------------------------------------
Write-Host "`n[4/5] build apk --release --flavor $Flavor --split-per-abi" -ForegroundColor Cyan
$args = @('build', 'apk', '--release', '--flavor', $Flavor, '--split-per-abi')
foreach ($d in $DartDefine) { $args += '--dart-define=' + $d }
& $flutter @args
if ($LASTEXITCODE -ne 0) { throw '构建失败' }

# ---- 4. 校验与汇总 ----------------------------------------------------------
$outDir = Join-Path $root 'build\app\outputs\flutter-apk'
$apks = Get-ChildItem $outDir -Filter "*-$Flavor-release.apk" | Sort-Object Name
if (-not $apks) { throw "没有找到产物：$outDir" }

Write-Host "`n[5/5] 产物" -ForegroundColor Cyan
$summary = foreach ($apk in $apks) {
    [pscustomobject]@{
        File   = $apk.Name
        MB     = [math]::Round($apk.Length / 1MB, 1)
        SHA256 = (Get-FileHash $apk.FullName -Algorithm SHA256).Hash.Substring(0, 16)
    }
}
$summary | Format-Table -AutoSize

$apksigner = Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools'
$apksigner = Get-ChildItem $apksigner -Directory -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending |
    Select-Object -First 1 |
    ForEach-Object { Join-Path $_.FullName 'apksigner.bat' }

if ($apksigner -and (Test-Path $apksigner)) {
    foreach ($apk in $apks) {
        $verify = & $apksigner verify --print-certs $apk.FullName 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "签名校验失败：$($apk.Name)`n$verify"
        }
        $subject = ($verify | Select-String 'Subject:' | Select-Object -First 1).Line
        # debug 证书同样能通过 apksigner 校验，但装到已安装用户身上会
        # INSTALL_FAILED_UPDATE_INCOMPATIBLE，只能卸载重装（本地数据全丢）。
        if ($subject -match 'CN=Android Debug') {
            throw "$($apk.Name) 用的是 debug 签名，不能分发；请检查 android/keystore.properties 与 myhours-release.keystore"
        }
        Write-Host "  ✓ $($apk.Name) 已签名  $($subject -replace '\s+', ' ')" -ForegroundColor Green
    }
} else {
    Write-Warning '未找到 apksigner，跳过签名校验（建议设置 ANDROID_SDK_ROOT 后重试）'
}

Write-Host "`n完成。产物目录：$outDir" -ForegroundColor Green
