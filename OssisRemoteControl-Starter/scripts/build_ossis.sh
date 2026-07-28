#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
KIT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export VCPKG_ROOT="${VCPKG_ROOT:-/c/ossis-build/vcpkg}"
export LIBCLANG_PATH="${LIBCLANG_PATH:-/c/Program Files/LLVM/bin}"
export VCPKG_DEFAULT_TRIPLET="x64-windows-static"
export VCPKG_DEFAULT_HOST_TRIPLET="x64-windows-static"
export VCPKGRS_TRIPLET="x64-windows-static"
export CARGO_BUILD_TARGET="x86_64-pc-windows-msvc"

python "$KIT/scripts/apply_branding.py"

echo "Flutter tabanlı Windows release derlemesi başlatılıyor..."
cargo build --locked --features flutter --lib --release --target x86_64-pc-windows-msvc

FOUND=""
for p in \
  "$ROOT/flutter/build/windows/x64/runner/Release/rustdesk.exe" \
  "$ROOT/flutter/build/windows/runner/Release/rustdesk.exe" \
  "$ROOT/target/release/rustdesk.exe"
do
  if [ -f "$p" ]; then FOUND="$p"; break; fi
done

if [ -z "$FOUND" ]; then
  FOUND="$(find "$ROOT/flutter/build/windows" "$ROOT/target/release" -iname 'rustdesk.exe' -type f 2>/dev/null | head -n 1 || true)"
fi

if [ -z "$FOUND" ]; then
  echo "HATA: Derleme tamamlandı fakat rustdesk.exe bulunamadı."
  exit 1
fi

mkdir -p "$KIT/output"
cp -f "$FOUND" "$KIT/output/OssisRemoteControl.exe"
cp -f "$KIT/ossis-settings.json" "$KIT/output/ossis-settings.json"

echo
echo "EXE hazır:"
echo "$KIT/output/OssisRemoteControl.exe"
echo
echo "Sunucu ayarını bu bilgisayarda uygulamak için:"
echo "powershell.exe -ExecutionPolicy Bypass -File \"OssisRemoteControl-Starter/scripts/apply_config.ps1\""
