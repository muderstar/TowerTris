$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Write-Error "cargo was not found in PATH. Install Rust toolchain first: https://rustup.rs"
}

Write-Host "Building c-api (release)..."
cargo build -p c-api --release

$targetDir = Join-Path $root "target\release"
$outDir = Join-Path $root "native"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$dllPath = Join-Path $targetDir "cold_clear.dll"
$libPath = Join-Path $targetDir "cold_clear.lib"
$headerPath = Join-Path $root "c-api\coldclear.h"

if (-not (Test-Path $dllPath)) {
    Write-Error "Build completed but cold_clear.dll was not found at $dllPath"
}

Copy-Item -Force $dllPath (Join-Path $outDir "cold_clear.dll")
if (Test-Path $libPath) {
    Copy-Item -Force $libPath (Join-Path $outDir "cold_clear.lib")
}
if (Test-Path $headerPath) {
    Copy-Item -Force $headerPath (Join-Path $outDir "coldclear.h")
}

Write-Host "Done. Native outputs are in $outDir"
