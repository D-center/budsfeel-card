# 无 Gradle 构建 LSPosed 模块（PowerShell 版）：
# javac(含桩) -> d8(只打模块类) -> aapt2 -> zipalign -> apksigner
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# 工具链（如已加入 PATH 可留空字符串自动发现）
$Jdk = 'C:\Users\Administrator.DESKTOP-FN8H4T3\tools\jdk17'
$Sdk = 'C:\Users\Administrator.DESKTOP-FN8H4T3\Android\Sdk'
$BT  = Join-Path $Sdk 'build-tools\36.1.0'
$Jar = Join-Path $Sdk 'platforms\android-35\android.jar'
$Ks  = Join-Path $env:USERPROFILE '.android\debug.keystore'
$OutApk = 'budsfeel-card.apk'

$env:JAVA_HOME = $Jdk
$env:Path = (Join-Path $Jdk 'bin') + ';' + $env:Path

$javac = Join-Path $Jdk 'bin\javac.exe'
$d8    = Join-Path $BT 'd8.bat'
$aapt2 = Join-Path $BT 'aapt2.exe'
$zipalign = Join-Path $BT 'zipalign.exe'
$apksigner = Join-Path $BT 'apksigner.bat'

if (Test-Path build) { Remove-Item build -Recurse -Force }
New-Item -ItemType Directory -Force -Path build\stubs, build\classes, build\dex | Out-Null

$stubSrc = Get-ChildItem -Recurse stubs -Filter *.java | ForEach-Object { $_.FullName }
$modSrc  = Get-ChildItem -Recurse src -Filter *.java | ForEach-Object { $_.FullName }

Write-Host '== javac stubs =='
& $javac -encoding UTF-8 --release 17 -cp $Jar -d build\stubs @stubSrc

Write-Host '== javac module =='
& $javac -encoding UTF-8 --release 17 -cp "$Jar;build\stubs" -d build\classes @modSrc

Write-Host '== d8 =='
$modClasses = Get-ChildItem -Recurse build\classes -Filter *.class | ForEach-Object { $_.FullName }
& $d8 --min-api 33 --lib $Jar --classpath build\stubs --output build\dex @modClasses

Write-Host '== aapt2 =='
& $aapt2 compile --dir res -o build\res.zip
& $aapt2 link -I $Jar --manifest AndroidManifest.xml -A assets -o build\unsigned.apk build\res.zip

Write-Host '== package dex =='
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open((Resolve-Path build\unsigned.apk), 'Update')
try {
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Resolve-Path build\dex\classes.dex), 'classes.dex') | Out-Null
} finally { $zip.Dispose() }

Write-Host '== align & sign =='
& $zipalign -f 4 build\unsigned.apk build\aligned.apk
& $apksigner sign --ks $Ks --ks-pass pass:android --out (Join-Path build $OutApk) build\aligned.apk

Write-Host '== verify =='
& $apksigner verify (Join-Path build $OutApk)
Get-Item (Join-Path build $OutApk) | Select-Object FullName, Length
