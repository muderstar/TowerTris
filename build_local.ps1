# ============================================================================
# TowerTris 本地一键构建脚本 (Windows / PowerShell)
# ----------------------------------------------------------------------------
# 用途：在本机直接导出 Windows + Linux 版本，无需每次从 GitHub Actions 下载。
#
# 首次运行会自动下载 Godot 4.3 编辑器 + 导出模板（约 150MB，只需一次）。
# 之后每次运行直接本地导出。
#
# 用法（在 PowerShell 中）：
#   .\build_local.ps1              # 导出 Windows + Linux 两个平台
#   .\build_local.ps1 win          # 只导出 Windows
#   .\build_local.ps1 linux        # 只导出 Linux
#
# 环境变量（可选）：
#   $env:GODOT_VERSION = "4.3.0"   # 指定 Godot 版本（默认 4.3.0，与 CI 一致）
#   $env:GODOT_BIN = "C:\godot\godot.exe"  # 使用已有 Godot，跳过自动下载
# ============================================================================
$ErrorActionPreference = "Stop"

# ---------- 配置 ----------
$GodotVersion = if ($env:GODOT_VERSION) { $env:GODOT_VERSION } else { "4.3.0" }
# GitHub release 标签使用短版本号（如 4.3-stable）
$GodotShort = $GodotVersion
if ($GodotVersion -match "^(\d+\.\d+)\.\d+$") { $GodotShort = $Matches[1] }
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = $ScriptDir
$ToolsDir = Join-Path $ScriptDir "tools"
$GodotBin = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { Join-Path $ToolsDir "godot.exe" }
$TemplatesDir = Join-Path $env:APPDATA "Godot/export_templates"

# ---------- 平台选择 ----------
$Targets = @()
if ($args.Count -eq 0) {
  $Targets = @("win", "linux")
} else {
  foreach ($arg in $args) {
    switch ($arg.ToLower()) {
      "win" { $Targets += "win" }
      "windows" { $Targets += "win" }
      "linux" { $Targets += "linux" }
      default { Write-Error "未知平台: $arg (可用: win / linux)"; exit 1 }
    }
  }
}

Write-Host "=================================================="
Write-Host " TowerTris 本地构建"
Write-Host "  项目目录: $ProjectDir"
Write-Host "  Godot版本: $GodotVersion"
Write-Host "  目标平台: $($Targets -join ', ')"
Write-Host "=================================================="

# ---------- 1. 准备 Godot 二进制 ----------
if (-not (Test-Path $GodotBin)) {
  Write-Host ""
  Write-Host "[1/4] 未找到 Godot，准备下载 Godot $GodotVersion ..."
  New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null

  $DownloadUrl = "https://github.com/godotengine/godot/releases/download/${GodotShort}-stable/Godot_v${GodotShort}-stable_win64.exe.zip"
  $ZipPath = Join-Path $ToolsDir "godot.zip"
  Write-Host "  下载: $DownloadUrl"
  Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath
  Expand-Archive -Path $ZipPath -DestinationPath $ToolsDir -Force
  Get-ChildItem $ToolsDir -Filter "Godot_v*_win64.exe" | Rename-Item -NewName "godot.exe"
  Remove-Item $ZipPath -Force
}

# ---------- 2. 准备导出模板 ----------
$TemplateVersion = "${GodotShort}.stable"
$TplCheck = Join-Path $TemplatesDir "$TemplateVersion/windows_release_x86_64.exe"
if (-not (Test-Path $TplCheck)) {
  Write-Host ""
  Write-Host "[2/4] 下载导出模板 $TemplateVersion ..."
  New-Item -ItemType Directory -Force -Path $TemplatesDir | Out-Null
  $TplUrl = "https://github.com/godotengine/godot/releases/download/${GodotShort}-stable/Godot_v${GodotShort}-stable_export_templates.tpz"
  $TplZip = Join-Path $ToolsDir "templates.tpz"
  Invoke-WebRequest -Uri $TplUrl -OutFile $TplZip
  Expand-Archive -Path $TplZip -DestinationPath $ToolsDir -Force
  # .tpz 实际是 zip 格式
  if (Test-Path (Join-Path $ToolsDir "templates")) {
    Move-Item (Join-Path $ToolsDir "templates") (Join-Path $TemplatesDir "$TemplateVersion") -Force
  }
  Remove-Item $TplZip -Force
}

Write-Host ""
Write-Host "  使用 Godot: $GodotBin"

# ---------- 3. 重新导入资源 ----------
Write-Host ""
Write-Host "[3/4] 导入资源（重建 .godot 缓存，修复音效/全局类解析）..."
& $GodotBin --headless --path $ProjectDir --import 2>&1 | Out-Host

# ---------- 4. 导出 ----------
Write-Host ""
Write-Host "[4/4] 开始导出..."

$BuildDir = Join-Path $ProjectDir "build"
if (Test-Path $BuildDir) { Remove-Item $BuildDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

if ($Targets -contains "win") {
  $WinOut = Join-Path $BuildDir "win/TowerTris.exe"
  New-Item -ItemType Directory -Force -Path (Split-Path $WinOut) | Out-Null
  Write-Host "  -> 导出 Windows ..."
  & $GodotBin --headless --path $ProjectDir --export-release "Windows Desktop" $WinOut
  Write-Host "  ✅ Windows 完成: $WinOut"
  Compress-Archive -Path (Join-Path $BuildDir "win/*") -DestinationPath (Join-Path $BuildDir "TowerTris-Windows.zip") -Force
  Write-Host "  📦 压缩包: $(Join-Path $BuildDir 'TowerTris-Windows.zip')"
}

if ($Targets -contains "linux") {
  $LinuxOut = Join-Path $BuildDir "linux/TowerTris.x86_64"
  New-Item -ItemType Directory -Force -Path (Split-Path $LinuxOut) | Out-Null
  Write-Host "  -> 导出 Linux ..."
  & $GodotBin --headless --path $ProjectDir --export-release "Linux" $LinuxOut
  Write-Host "  ✅ Linux 完成: $LinuxOut"
  Compress-Archive -Path (Join-Path $BuildDir "linux/*") -DestinationPath (Join-Path $BuildDir "TowerTris-Linux.zip") -Force
  Write-Host "  📦 压缩包: $(Join-Path $BuildDir 'TowerTris-Linux.zip')"
}

Write-Host ""
Write-Host "=================================================="
Write-Host " 构建完成！产物在: $BuildDir"
Write-Host "=================================================="
