#!/usr/bin/env bash
# ============================================================================
# 构建 ColdClear 原生引擎（跨平台 worker + C ABI 库）
# ----------------------------------------------------------------------------
# 在项目 rust/cold_clear_engine/ 下执行：
#   构建 Linux:   ./build_native_linux.sh
#   构建 Windows: powershell -File build_c_api.ps1（需 MinGW + rust target）
#
# 产物输出到 rust/cold_clear_engine/native/：
#   Linux:   coldclear_worker_linux + libcold_clear.so
#   Windows: coldclear_worker.exe  + cold_clear.dll
# ============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "=== [1/3] 构建 C ABI 库 (libcold_clear.so) ==="
cargo build -p c-api --release

echo "=== [2/3] 构建 Linux worker ==="
gcc -O2 -o native/coldclear_worker_linux native/coldclear_worker_linux.c -ldl

echo "=== [3/3] 部署产物到 native/ ==="
cp -f target/release/libcold_clear.so native/libcold_clear.so
chmod +x native/coldclear_worker_linux

echo ""
echo "✅ 完成。native/ 目录内容:"
ls -la native/ | grep -E "coldclear_worker_linux|libcold_clear.so"
