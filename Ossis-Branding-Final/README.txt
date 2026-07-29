SON İŞLEM

1. Bu klasörü bütünüyle şuraya kopyalayın:
   C:\ossis-build\rustdesk\Ossis-Branding-Final

2. UYGULA_VE_GITHUBA_GONDER.cmd dosyasına çift tıklayın.

3. Ekranın sonunda FINAL BRANDING OK ve BASARILI yazarsa:
   GitHub > isakocadag/rustdesk > Actions >
   Build Ossis Remote Control > Run workflow.

4. Derleme bitince:
   rustdesk-unsigned-windows-x86_64 artifact'ını indirin.

Bu sürüm:
- Görünen RustDesk marka metinlerini Ossis Remote Control olarak değiştirir.
- Windows ürün adı, açıklama ve ikonlarını değiştirir.
- helpdesk.ossisbilisim.com ve OSSIS public key değerlerini kaynakta gömer.
- Sunucu veya key sabiti bulunamazsa yanlış EXE üretmemek için işlemi durdurur.
