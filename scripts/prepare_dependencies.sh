#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
KIT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== Ossis Remote Control bağımlılık hazırlığı =="

if ! command -v git >/dev/null; then echo "Git bulunamadı."; exit 1; fi
if ! command -v python3 >/dev/null; then echo "Python 3 bulunamadı."; exit 1; fi
if ! command -v cargo >/dev/null; then echo "Cargo bulunamadı."; exit 1; fi
if ! command -v cmake >/dev/null; then echo "CMake bulunamadı."; exit 1; fi

export LIBCLANG_PATH="${LIBCLANG_PATH:-/c/Program Files/LLVM/bin}"

VCPKG_DIR="/c/ossis-build/vcpkg"
if [ ! -d "$VCPKG_DIR/.git" ]; then
  git clone https://github.com/microsoft/vcpkg "$VCPKG_DIR"
fi
"$VCPKG_DIR/bootstrap-vcpkg.bat"
export VCPKG_ROOT="$VCPKG_DIR"

"$VCPKG_DIR/vcpkg.exe" install \
  libvpx:x64-windows-static \
  libyuv:x64-windows-static \
  opus:x64-windows-static \
  aom:x64-windows-static

SCITER_DLL="$ROOT/sciter.dll"
if [ ! -f "$SCITER_DLL" ]; then
  echo "sciter.dll indiriliyor..."
  curl -L "https://raw.githubusercontent.com/c-smile/sciter-sdk/master/bin.win/x64/sciter.dll" -o "$SCITER_DLL"
fi

python3 "$KIT/scripts/apply_branding.py"

cat > "$KIT/.env.generated" <<EOF
VCPKG_ROOT=$VCPKG_ROOT
LIBCLANG_PATH=$LIBCLANG_PATH
EOF

echo
echo "Hazırlık tamamlandı."
echo "Sonraki komut: bash OssisRemoteControl-Starter/scripts/build_ossis.sh"
