#!/usr/bin/env python3
from pathlib import Path
import re, shutil, sys

ROOT = Path(__file__).resolve().parent.parent
KIT = Path(__file__).resolve().parent
PRODUCT = "Ossis Remote Control"
COMPANY = "OSSIS Bilişim"
SERVER = "helpdesk.ossisbilisim.com"
PUBKEY = "7pCbGG6ppWrXlUkfRCwxvtgGcmtpNFRDhgLEJURad0Q="
CONFIG_CODE = "==Qfi0TUPRWYSVlSFx2ZoRkUG5Gc012YHdGd2h3dDJlZrVFbYJ3VwBnNHdkYDB3NiojI5V2aiwiIiojIpBXYiwiIiojI5FGblJnIsISbvNmLtl2cpxWaiNXazN3bus2clRGcsVGaiojI0N3boJye"

if not (ROOT / "Cargo.toml").exists():
    print("HATA: Bu klasör rustdesk kaynak klasörünün içinde olmalı.")
    sys.exit(1)

ICON = KIT / "ossis.ico"
PNG = KIT / "ossis.png"
changed = []
errors = []

def write_text(path, text):
    path.write_text(text, encoding="utf-8")
    changed.append(str(path.relative_to(ROOT)))

def replace_file(path, replacements):
    if not path.exists():
        return
    old = path.read_text(encoding="utf-8", errors="ignore")
    new = old
    for pattern, repl, regex in replacements:
        new = re.sub(pattern, repl, new, flags=re.MULTILINE | re.DOTALL) if regex else new.replace(pattern, repl)
    if new != old:
        write_text(path, new)

# 1) Windows executable resources
replace_file(ROOT / "flutter/windows/runner/Runner.rc", [
    ('VALUE "CompanyName", "PURSLANE"', f'VALUE "CompanyName", "{COMPANY}"', False),
    ('VALUE "FileDescription", "Open Source Remote Desktop Access Software"', f'VALUE "FileDescription", "{PRODUCT}"', False),
    ('VALUE "InternalName", "rustdesk"', 'VALUE "InternalName", "OssisRemoteControl"', False),
    ('VALUE "OriginalFilename", "rustdesk.exe"', 'VALUE "OriginalFilename", "OssisRemoteControl.exe"', False),
    ('VALUE "ProductName", "RustDesk"', f'VALUE "ProductName", "{PRODUCT}"', False),
])

replace_file(ROOT / "flutter/windows/runner/main.cpp", [
    ('L"RustDesk"', f'L"{PRODUCT}"', False),
    ('"RustDesk"', f'"{PRODUCT}"', False),
])

# 2) Visible application/installer text.
# Exact-case "RustDesk" is presentation text. Lowercase crate/package identifiers remain untouched.
text_roots = [
    ROOT / "flutter/lib",
    ROOT / "src",
    ROOT / "res",
    ROOT / "libs/portable",
    ROOT / "libs/hbb_common/src",
]
exts = {".dart", ".rs", ".cpp", ".cc", ".c", ".h", ".hpp", ".rc", ".xml", ".wxs", ".toml", ".yaml", ".yml", ".json", ".py"}
skip_names = {"LICENSE", "LICENSE.md", "COPYING", "README.md"}

for folder in text_roots:
    if not folder.exists():
        continue
    for path in folder.rglob("*"):
        if not path.is_file() or path.name in skip_names or path.suffix.lower() not in exts:
            continue
        old = path.read_text(encoding="utf-8", errors="ignore")
        new = old.replace("RustDesk", PRODUCT)
        # Do not alter legal project URLs or lowercase code identifiers.
        if new != old:
            write_text(path, new)

# 3) Compile-time self-host settings in hbb_common config.
config_files = list((ROOT / "libs").rglob("config.rs"))
server_patched = False
key_patched = False

for path in config_files:
    old = path.read_text(encoding="utf-8", errors="ignore")
    new = old

    patterns_server = [
        (r'pub\s+const\s+DEFAULT_RENDEZVOUS_SERVER\s*:\s*&str\s*=\s*"[^"]*";',
         f'pub const DEFAULT_RENDEZVOUS_SERVER: &str = "{SERVER}";'),
        (r'pub\s+const\s+RENDEZVOUS_SERVER\s*:\s*&str\s*=\s*"[^"]*";',
         f'pub const RENDEZVOUS_SERVER: &str = "{SERVER}";'),
        (r'pub\s+const\s+RENDEZVOUS_SERVERS\s*:\s*&\[&str\]\s*=\s*&\[[^;]*\];',
         f'pub const RENDEZVOUS_SERVERS: &[&str] = &["{SERVER}"];'),
    ]
    for pat, repl in patterns_server:
        n2, count = re.subn(pat, repl, new, flags=re.MULTILINE | re.DOTALL)
        if count:
            server_patched = True
            new = n2

    patterns_key = [
        (r'pub\s+const\s+RS_PUB_KEY\s*:\s*&str\s*=\s*"[^"]*";',
         f'pub const RS_PUB_KEY: &str = "{PUBKEY}";'),
        (r'pub\s+const\s+DEFAULT_RS_PUB_KEY\s*:\s*&str\s*=\s*"[^"]*";',
         f'pub const DEFAULT_RS_PUB_KEY: &str = "{PUBKEY}";'),
    ]
    for pat, repl in patterns_key:
        n2, count = re.subn(pat, repl, new, flags=re.MULTILINE | re.DOTALL)
        if count:
            key_patched = True
            new = n2

    if new != old:
        write_text(path, new)

# 4) Replace all known Windows/UI icon assets that exist.
icon_targets = [
    ROOT / "flutter/windows/runner/resources/app_icon.ico",
    ROOT / "res/icon.ico",
    ROOT / "flutter/assets/icon.ico",
    ROOT / "flutter/assets/logo.ico",
    ROOT / "assets/icon.ico",
]
for target in icon_targets:
    if target.exists():
        shutil.copy2(ICON, target)
        changed.append(str(target.relative_to(ROOT)))

png_targets = [
    ROOT / "res/32x32.png",
    ROOT / "res/128x128.png",
    ROOT / "res/128x128@2x.png",
    ROOT / "flutter/assets/logo.png",
    ROOT / "flutter/assets/icon.png",
]
for target in png_targets:
    if target.exists():
        shutil.copy2(PNG, target)
        changed.append(str(target.relative_to(ROOT)))

# 5) Record the exported config for deployment packaging.
(ROOT / "ossis-client-config.txt").write_text(CONFIG_CODE, encoding="utf-8")
changed.append("ossis-client-config.txt")

print("\nUygulanan değişiklikler:")
for item in sorted(set(changed)):
    print("  " + item)

print("\nKontrol:")
print("  Sunucu sabiti:", "OK" if server_patched else "BULUNAMADI")
print("  Public key sabiti:", "OK" if key_patched else "BULUNAMADI")

# Branding can still build if newer source removed compile-time settings,
# but stop now so we do not falsely claim the config was embedded.
if not server_patched or not key_patched:
    print("\nHATA: Güncel kaynakta sunucu/key sabitlerinin yapısı değişmiş.")
    print("Bu durumda derleme başlatılmadı; yanlış yapılandırılmış EXE üretilmeyecek.")
    sys.exit(2)

print("\nFINAL BRANDING OK")
