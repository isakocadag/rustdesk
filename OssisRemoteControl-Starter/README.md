# Ossis Remote Control – Başlangıç Paketi

Bu paket, mevcut RustDesk kaynak klasörüne eklenmek üzere hazırlanmıştır.

## Klasör konumu

Paketi şu klasöre çıkarın:

C:\ossis-build\rustdesk\OssisRemoteControl-Starter

Yani `Cargo.toml` ile aynı ana klasörün altında bulunmalıdır.

## İlk çalıştırma

Git Bash'i açın:

```bash
cd /c/ossis-build/rustdesk
bash OssisRemoteControl-Starter/scripts/prepare_dependencies.sh
```

Hazırlık tamamlanınca:

```bash
bash OssisRemoteControl-Starter/scripts/build_ossis.sh
```

Başarılı derleme sonunda dosya:

```text
C:\ossis-build\rustdesk\OssisRemoteControl-Starter\output\OssisRemoteControl.exe
```

## Sunucu yapılandırması

Derleme bittikten sonra PowerShell'de:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:\ossis-build\rustdesk\OssisRemoteControl-Starter\scripts\apply_config.ps1"
```

Bu komut çalışan istemciye şu yapılandırmayı uygular:

- ID sunucusu: helpdesk.ossisbilisim.com
- OSSIS sunucu public key'i
- Mevcut dışa aktarılmış RustDesk yapılandırma kodu

## Neleri değiştirir?

- Windows ürün adı ve dosya açıklaması
- Pencere başlığının bilinen Windows kaynakları
- Windows ICO dosyaları
- Flutter içindeki bilinen logo dosyaları
- Çıktı dosya adı: OssisRemoteControl.exe

## Önemli

- `.ossis-backup` klasörü, değiştirilen özgün dosyaların ilk kopyasını tutar.
- RustDesk açık kaynak lisans ve atıf metinleri kaldırılmaz.
- Kaynak yapı zamanla değişebildiği için ilk derlemede bulunamayan bir dosya olursa betik onu atlar; hata çıktısına göre yama güncellenir.
- Kod imzası yoksa Windows SmartScreen uyarısı gösterebilir.
