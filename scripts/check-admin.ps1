# The 管理后台's harness gate (tech plan S22, WP22.5): pub get, analyze, every test and a web build of admin/, by
# appdev's check, as the harness runs app/. Flutter needs an ASCII path here (CLAUDE.md rule 7), and the dashboard
# needs ../app beside it (a path dependency), so the junction points at the repository root, not at admin/ alone.
# rmdir removes only the link, never the target.
param([string]$Build = 'web')

$check = Join-Path $env:USERPROFILE '.claude\skills\appdev\scripts\check.ps1'
if (-not (Test-Path $check)) {
    Write-Output "admin gate: appdev check.ps1 not found at $check"
    exit 1
}
$root = Split-Path -Parent $PSScriptRoot
# Flutter's record of the last build's files, by the path it used: a build through another path deletes them as
# stale, through any junction still there (MISTAKES rule 23). Cleared first, on the real path, so earlier builds
# can't matter. This gate's build goes to admin/build/web; npm run admin:build makes the one served at /admin/.
$record = Join-Path $root 'admin\.dart_tool\flutter_build'
if (Test-Path $record) { Remove-Item -LiteralPath $record -Recurse -Force }
$junction = Join-Path $env:TEMP ('admin-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Junction -Path $junction -Target $root | Out-Null
$code = 1
try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $check -Project (Join-Path $junction 'admin') -Build $Build
    $code = $LASTEXITCODE
} finally {
    & cmd.exe /d /c rmdir "$junction"
}
exit $code
