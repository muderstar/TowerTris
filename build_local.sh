#!/usr/bin/env bash
# ============================================================================
# TowerTris 本地一键构建脚本 (Linux)
# ----------------------------------------------------------------------------
# 用途：在本机直接导出 Windows + Linux 版本，无需每次从 GitHub Actions 下载。
#
# 首次运行会自动下载 Godot 4.3 编辑器 + 导出模板（约 150MB，只需一次）。
# 之后每次运行直接本地导出，几秒钟完成。
#
# 用法：
#   ./build_local.sh              # 导出 Windows + Linux 两个平台
#   ./build_local.sh win          # 只导出 Windows
#   ./build_local.sh linux        # 只导出 Linux
#
# 环境变量（可选）：
#   GODOT_VERSION=4.3.0           # 指定 Godot 版本（默认 4.3.0，与 CI 一致）
#   GODOT_BIN=/path/to/godot      # 使用已有的 Godot 可执行文件，跳过自动下载
# ============================================================================
set -euo pipefail

# ---------- 配置 ----------
GODOT_VERSION="${GODOT_VERSION:-4.3.0}"
# GitHub release 标签使用短版本号（如 4.3-stable），下载 URL 据此构造
GODOT_SHORT="${GODOT_VERSION%.*}"
if [[ "$GODOT_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
  GODOT_SHORT="$GODOT_VERSION"
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
TOOLS_DIR="$SCRIPT_DIR/tools"
GODOT_BIN="${GODOT_BIN:-$TOOLS_DIR/godot}"
TEMPLATES_DIR="${TEMPLATES_DIR:-$HOME/.local/share/godot/export_templates}"
ARCH="$(uname -m)"

# ---------- 平台选择 ----------
TARGETS=()
if [ $# -eq 0 ]; then
  TARGETS=(win linux)
else
  for arg in "$@"; do
    case "$arg" in
      win|windows) TARGETS+=(win) ;;
      linux) TARGETS+=(linux) ;;
      *)
        echo "未知平台: $arg (可用: win / linux)" >&2
        exit 1
        ;;
    esac
  done
fi

echo "=================================================="
echo " TowerTris 本地构建"
echo "  项目目录: $PROJECT_DIR"
echo "  Godot版本: $GODOT_VERSION"
echo "  目标平台: ${TARGETS[*]}"
echo "=================================================="

# ---------- 1. 准备 Godot 二进制 ----------
need_download=0
if [ ! -x "$GODOT_BIN" ]; then
  need_download=1
  echo ""
  echo "[1/4] 未找到 Godot，准备下载 Godot $GODOT_VERSION ..."
  mkdir -p "$TOOLS_DIR"

  case "$ARCH" in
    x86_64) godot_arch="x86_64" ;;
    aarch64|arm64) godot_arch="arm64" ;;
    *)
      echo "不支持的架构: $ARCH" >&2
      exit 1
      ;;
  esac

  # Godot 官方下载地址（release 标签用短版本号，如 4.3-stable）
  DOWNLOAD_URL="https://github.com/godotengine/godot/releases/download/${GODOT_SHORT}-stable/Godot_v${GODOT_SHORT}-stable_linux.${godot_arch}.zip"
  echo "  下载: $DOWNLOAD_URL"
  curl -L --fail --retry 3 -o "$TOOLS_DIR/godot.zip" "$DOWNLOAD_URL"
  unzip -o -q "$TOOLS_DIR/godot.zip" -d "$TOOLS_DIR"
  mv "$TOOLS_DIR"/Godot_v${GODOT_SHORT}-stable_linux.${godot_arch} "$GODOT_BIN"
  chmod +x "$GODOT_BIN"
  rm -f "$TOOLS_DIR/godot.zip"
fi

# ---------- 2. 准备导出模板 ----------
TEMPLATE_VERSION="${GODOT_SHORT}.stable"
TPL_FILE="$TEMPLATES_DIR/$TEMPLATE_VERSION/linux_release.x86_64"
if [ ! -f "$TPL_FILE" ]; then
  echo ""
  echo "[2/4] 下载导出模板 $TEMPLATE_VERSION ..."
  mkdir -p "$TEMPLATES_DIR"
  TPL_URL="https://github.com/godotengine/godot/releases/download/${GODOT_SHORT}-stable/Godot_v${GODOT_SHORT}-stable_export_templates.tpz"
  curl -L --fail --retry 3 -o "$TOOLS_DIR/templates.tpz" "$TPL_URL"
  mkdir -p "$TOOLS_DIR/tpl_tmp"
  unzip -o -q "$TOOLS_DIR/templates.tpz" -d "$TOOLS_DIR/tpl_tmp"
  mv "$TOOLS_DIR/tpl_tmp/templates" "$TEMPLATES_DIR/$TEMPLATE_VERSION"
  rm -rf "$TOOLS_DIR/templates.tpz" "$TOOLS_DIR/tpl_tmp"
fi

echo ""
echo "  使用 Godot: $GODOT_BIN"

if [[ " ${TARGETS[*]} " == *" linux "* ]]; then
  echo ""
  echo "[2.5/4] 构建 Linux ColdClear 原生引擎..."
  bash "$PROJECT_DIR/rust/cold_clear_engine/build_native_linux.sh"
fi

# ---------- 3. 重新导入资源（生成 .godot 缓存）----------
echo ""
echo "[3/4] 导入资源（重建 .godot 缓存，修复音效/全局类解析）..."
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --import || {
  echo "  (导入阶段有警告可忽略，继续导出)"
}

# ---------- 4. 导出 ----------
echo ""
echo "[4/4] 开始导出..."

export_target() {
  local platform="$1"
  local preset="$2"
  local outfile="$3"
  echo "  -> 导出 $platform ..."
  mkdir -p "$(dirname "$outfile")"
  "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
    --export-release "$preset" "$outfile"
  echo "  ✅ $platform 完成: $outfile"
}

rm -rf "$PROJECT_DIR/build"
mkdir -p "$PROJECT_DIR/build"

if [[ " ${TARGETS[*]} " == *" win "* ]]; then
  export_target "Windows" "Windows Desktop" "$PROJECT_DIR/build/win/TowerTris.exe"
  # 部署 ColdClear 原生引擎 sidecar（worker + dll 与可执行文件同目录）
  cp -f "$PROJECT_DIR/rust/cold_clear_engine/native/coldclear_worker.exe" "$PROJECT_DIR/build/win/" 2>/dev/null || true
  cp -f "$PROJECT_DIR/rust/cold_clear_engine/native/cold_clear.dll" "$PROJECT_DIR/build/win/" 2>/dev/null || true
  ( cd "$PROJECT_DIR/build/win" && zip -r -q "$PROJECT_DIR/build/TowerTris-Windows.zip" . )
  echo "  📦 压缩包: $PROJECT_DIR/build/TowerTris-Windows.zip"
fi

if [[ " ${TARGETS[*]} " == *" linux "* ]]; then
  export_target "Linux" "Linux" "$PROJECT_DIR/build/linux/TowerTris.x86_64"
  # 部署 ColdClear 原生引擎 sidecar（worker + .so 与可执行文件同目录，保持可执行权限）
  cp -f "$PROJECT_DIR/rust/cold_clear_engine/native/coldclear_worker_linux" "$PROJECT_DIR/build/linux/" 2>/dev/null || true
  cp -f "$PROJECT_DIR/rust/cold_clear_engine/native/libcold_clear.so" "$PROJECT_DIR/build/linux/" 2>/dev/null || true
  chmod +x "$PROJECT_DIR/build/linux/coldclear_worker_linux" 2>/dev/null || true
  ( cd "$PROJECT_DIR/build/linux" && zip -r -q "$PROJECT_DIR/build/TowerTris-Linux.zip" . )
  echo "  📦 压缩包: $PROJECT_DIR/build/TowerTris-Linux.zip"
fi

echo ""
echo "=================================================="
echo " 构建完成！产物在: $PROJECT_DIR/build/"
echo "=================================================="
