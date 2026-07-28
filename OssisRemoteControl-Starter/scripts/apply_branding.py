#!/usr/bin/env python3
from pathlib import Path
import json, shutil, re, sys

ROOT = Path(__file__).resolve().parents[2]
KIT = Path(__file__).resolve().parents[1]
SETTINGS = json.loads((KIT / "ossis-settings.json").read_text(encoding="utf-8"))
PRODUCT = SETTINGS["product_name"]
EXE = SETTINGS["exe_name"]
COMPANY = SETTINGS["company_name"]
ICON = KIT / "assets" / "ossis.ico"
PNG = KIT / "assets" / "ossis.png"

if not (ROOT / "Cargo.toml").exists() or not (ROOT / "flutter").exists():
    print("HATA: Paket rustdesk kaynak klasörünün içine çıkarılmalı.")
    print("Beklenen örnek: C:/ossis-build/rustdesk/OssisRemoteControl-Starter")
    sys.exit(1)

backup_root = ROOT / ".ossis-backup"
backup_root.mkdir(exist_ok=True)

def backup(path: Path):
    if path.exists():
        dest = backup_root / path.relative_to(ROOT)
        dest.parent.mkdir(parents=True, exist_ok=True)
        if not dest.exists():
            shutil.copy2(path, dest)

def replace_text(path: Path, replacements):
    if not path.exists():
        return False
    backup(path)
    text = path.read_text(encoding="utf-8", errors="ignore")
    old = text
    for pattern, repl, regex in replacements:
        text = re.sub(pattern, repl, text) if regex else text.replace(pattern, repl)
    if text != old:
        path.write_text(text, encoding="utf-8")
        print(f"Güncellendi: {path.relative_to(ROOT)}")
        return True
    return False

# Windows file metadata and bundle metadata
replace_text(ROOT / "Cargo.toml", [
    ('ProductName = "RustDesk"', f'ProductName = "{PRODUCT}"', False),
    ('FileDescription = "RustDesk Remote Desktop"', f'FileDescription = "{PRODUCT}"', False),
    ('OriginalFilename = "rustdesk.exe"', f'OriginalFilename = "{EXE}"', False),
    ('name = "RustDesk"', f'name = "{PRODUCT}"', False),
    ('LegalCopyright = "Copyright © 2026 Purslane Tech Pte. Ltd. All rights reserved."',
     f'LegalCopyright = "Copyright © 2026 {COMPANY}. RustDesk açık kaynak lisans bildirimleri saklıdır."', False),
])

# Flutter Windows version resource
runner_rc = ROOT / "flutter" / "windows" / "runner" / "Runner.rc"
replace_text(runner_rc, [
    ('VALUE "FileDescription", "Open Source Remote Desktop Access Software"', 
     f'VALUE "FileDescription", "{PRODUCT}"', False),
    ('VALUE "ProductName", "RustDesk"', f'VALUE "ProductName", "{PRODUCT}"', False),
    ('VALUE "InternalName", "rustdesk"', 'VALUE "InternalName", "OssisRemoteControl"', False),
    ('VALUE "OriginalFilename", "rustdesk.exe"', f'VALUE "OriginalFilename", "{EXE}"', False),
    ('VALUE "CompanyName", "PURSLANE"', f'VALUE "CompanyName", "{COMPANY}"', False),
])

# Window title / executable target where exact declarations exist
for rel in [
    "flutter/windows/runner/main.cpp",
    "flutter/windows/runner/win32_window.cpp",
    "flutter/windows/CMakeLists.txt",
    "flutter/windows/runner/CMakeLists.txt",
]:
    replace_text(ROOT / rel, [
        ('L"RustDesk"', f'L"{PRODUCT}"', False),
        ('"RustDesk"', f'"{PRODUCT}"', False),
    ])

# Replace likely Windows icons and Flutter runtime icons
icon_targets = [
    ROOT / "flutter/windows/runner/resources/app_icon.ico",
    ROOT / "flutter/windows/runner/resources/rustdesk.ico",
    ROOT / "res/icon.ico",
    ROOT / "flutter/assets/icon.ico",
    ROOT / "flutter/assets/logo.ico",
]
for target in icon_targets:
    if target.exists():
        backup(target)
        shutil.copy2(ICON, target)
        print(f"İkon değiştirildi: {target.relative_to(ROOT)}")

png_targets = [
    ROOT / "flutter/assets/logo.png",
    ROOT / "flutter/assets/icon.png",
    ROOT / "res/128x128.png",
    ROOT / "res/128x128@2x.png",
    ROOT / "res/32x32.png",
]
for target in png_targets:
    if target.exists():
        backup(target)
        shutil.copy2(PNG, target)
        print(f"Logo değiştirildi: {target.relative_to(ROOT)}")

marker = ROOT / ".ossis-branding-applied"
marker.write_text("Ossis Remote Control branding applied\n", encoding="utf-8")
print("\nMarkalama yamaları uygulandı.")
print("Not: RustDesk lisans/atıf metinleri bilinçli olarak kaldırılmadı.")
