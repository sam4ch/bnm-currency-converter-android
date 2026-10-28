param([string]$Flutter = 'flutter')
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$buildRoot = Join-Path ([IO.Path]::GetTempPath()) ('currency_lab4_' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($buildRoot) | Out-Null

# Native AOT tools in Flutter 3.47 cannot read Cyrillic paths on Windows.
# Only this project's source files are copied; existing files are never moved.
$files = & git -c "safe.directory=$($projectRoot.Replace('\','/'))" -C $projectRoot ls-files --cached --others --exclude-standard
if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate project source files.' }
foreach ($relative in $files) {
    if ($relative -notmatch '^(lib/|android/|pubspec\.yaml$|pubspec\.lock$|analysis_options\.yaml$|\.metadata$)') { continue }
    $source = [IO.Path]::GetFullPath((Join-Path $projectRoot $relative))
    $destination = [IO.Path]::GetFullPath((Join-Path $buildRoot $relative))
    if (-not $source.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid source path.' }
    if (-not $destination.StartsWith($buildRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid destination path.' }
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination
}
Push-Location $buildRoot
try {
    & $Flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }
    & $Flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'Android release build failed.' }
} finally { Pop-Location }
$artifactDirectory = Join-Path $projectRoot 'artifacts'
[IO.Directory]::CreateDirectory($artifactDirectory) | Out-Null
$apk = Join-Path $artifactDirectory 'CurrencyInsights-Android.apk'
Copy-Item -LiteralPath (Join-Path $buildRoot 'build\app\outputs\flutter-apk\app-release.apk') -Destination $apk
$hash = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash
@{ apk = $apk; sha256 = $hash; bytes = (Get-Item -LiteralPath $apk).Length; buildDirectory = $buildRoot; builtAtUtc = [DateTime]::UtcNow.ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $artifactDirectory 'build-info.json') -Encoding utf8
Write-Output "APK: $apk"
Write-Output "SHA256: $hash"
Write-Output "Build cache: $buildRoot"
