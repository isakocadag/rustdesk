import 'dart:io';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _referenceVerificationUrl =
    'https://servis.ossisbilisim.com:8443/api/v1/reference/validate/';

const _contractedSupportUrl =
    'https://servis.ossisbilisim.com:8443/api/v1/support/contracted/';

class OssisReferenceGate extends StatefulWidget {
  const OssisReferenceGate({
    super.key,
    this.initialReference,
    required this.child,
    required this.onApproved,
  });

  final String? initialReference;

  final Widget child;
  final Future<void> Function() onApproved;

  @override
  State<OssisReferenceGate> createState() => _OssisReferenceGateState();
}

class _OssisReferenceGateState extends State<OssisReferenceGate> {
  final _controller = TextEditingController();
  final _companyCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _focusNode = FocusNode();
  bool _approved = false;
  bool _busy = false;
  bool _contractedMode = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    final initialReference = widget.initialReference?.trim().toUpperCase();

    if (initialReference != null &&
        RegExp(r'^[A-Z0-9-]{4,64}$').hasMatch(initialReference)) {
      _controller.text = initialReference;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _verify();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _companyCodeController.dispose();
    _passwordController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy) return;

    final code = _controller.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9-]{4,64}$').hasMatch(code)) {
      setState(() {
        _error = 'Geçerli bir referans kodu girin.';
      });
      _focusNode.requestFocus();
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final windowsInfo = await DeviceInfoPlugin().windowsInfo;
      final deviceId = windowsInfo.deviceId.trim();
      final deviceName = windowsInfo.computerName.trim();

      if (deviceId.isEmpty) {
        throw const _ReferenceRejected(
          'Bu bilgisayarın cihaz kimliği alınamadı.',
        );
      }
      final response = await http
          .post(
            Uri.parse(_referenceVerificationUrl),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'reference_code': code,
              'client': 'ossis-remote-control',
              'platform': 'windows',
              'version': packageInfo.version,
              'device_id': deviceId,
              'device_name': deviceName,
            }),
          )
          .timeout(const Duration(seconds: 12));

      Map<String, dynamic>? payload;
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) payload = decoded;
      } on FormatException {
        payload = null;
      }

      if (response.statusCode == 200 && payload?['valid'] == true) {
        await widget.onApproved();
        if (!mounted) return;
        setState(() {
          _approved = true;
          _busy = false;
        });
        return;
      }

      final errorCode = payload?['error']?.toString();
      final errorMessage = switch (errorCode) {
        'invalid_reference' => 'Referans kodu geçersiz.',
        'inactive_reference' => 'Referans kodu devre dışı bırakılmış.',
        'expired_reference' => 'Referans kodunun kullanım süresi dolmuş.',
        'device_limit_reached' =>
          'Bu referans kodu başka bir bilgisayarda etkinleştirilmiş.',
        'device_disabled' =>
          'Bu bilgisayar için bağlantı yetkisi devre dışı bırakılmış.',
        'device_id_required' => 'Bilgisayar kimliği sunucuya gönderilemedi.',
        'reference_code_required' => 'Referans kodu zorunludur.',
        _ => 'Referans kodu doğrulanamadı.',
      };
      throw _ReferenceRejected(errorMessage);
    } on _ReferenceRejected catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
      _focusNode.requestFocus();
    } on TimeoutException {
      _showConnectionError();
    } on http.ClientException {
      _showConnectionError();
    } catch (_) {
      _showConnectionError();
    }
  }

  Future<void> _startContractedSupport() async {
    if (_busy) return;

    final companyCode = _companyCodeController.text.trim().toUpperCase();
    final password = _passwordController.text;

    if (companyCode.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Firma kodu ve şifre zorunludur.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse(_contractedSupportUrl),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'company_code': companyCode,
              'password': password,
              'subject': 'Ossis Remote Control destek talebi',
              'description':
                  'Sözleşmeli müşteri Ossis Remote Control üzerinden destek başlattı.',
            }),
          )
          .timeout(const Duration(seconds: 12));

      Map<String, dynamic>? payload;
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        }
      } on FormatException {
        payload = null;
      }

      if (response.statusCode != 200 || payload?['valid'] != true) {
        final errorCode = payload?['error']?.toString();
        final message = switch (errorCode) {
          'invalid_credentials' => 'Firma kodu veya şifre hatalı.',
          'company_code_and_password_required' =>
            'Firma kodu ve şifre zorunludur.',
          'reference_creation_disabled' =>
            'Bu müşteri hesabı için destek başlatma yetkisi kapalı.',
          _ => 'Destek oturumu başlatılamadı. Lütfen tekrar deneyin.',
        };
        throw _ReferenceRejected(message);
      }

      final referenceCode =
          payload?['reference_code']?.toString().trim().toUpperCase();

      if (referenceCode == null || referenceCode.isEmpty) {
        throw const _ReferenceRejected(
          'Sunucudan referans kodu alınamadı.',
        );
      }

      _controller.text = referenceCode;

      if (!mounted) return;
      setState(() {
        _busy = false;
      });

      await _verify();
    } on _ReferenceRejected catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } on TimeoutException {
      _showConnectionError();
    } on http.ClientException {
      _showConnectionError();
    } catch (_) {
      _showConnectionError();
    }
  }

  void _showConnectionError() {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error =
          'Referans doğrulama servisine ulaşılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.';
    });
    _focusNode.requestFocus();
  }

  Future<void> _openSupportTicket() async {
    final uri = Uri.parse('https://ossisbilisim.com/support/ticket/');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_approved) return widget.child;

    const accent = Color(0xFFD32F2F);
    const background = Color(0xFF121418);
    const panel = Color(0xFF1B1D22);
    const panelSoft = Color(0xFF22252B);
    const border = Color(0xFF3A3E46);
    const textSoft = Color(0xFFB9BDC6);

    return Scaffold(
      backgroundColor: background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final veryCompact = constraints.maxWidth < 400;

          final maxWidth = compact ? 376.0 : 620.0;
          final horizontalPadding = compact ? 8.0 : 22.0;
          final cardPadding = compact ? 12.0 : 28.0;
          final logoSize = compact ? 52.0 : 82.0;
          final titleSize = compact ? 22.0 : 34.0;
          final sectionGap = compact ? 10.0 : 20.0;

          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: compact ? 18 : 28,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Container(
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(compact ? 18 : 22),
                    border: Border.all(color: border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      cardPadding,
                      compact ? 24 : 34,
                      cardPadding,
                      compact ? 20 : 28,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          'assets/icon.png',
                          height: logoSize,
                          width: logoSize,
                        ),
                        SizedBox(height: compact ? 14 : 18),
                        Text(
                          'Ossis Remote Control',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: titleSize,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _contractedMode
                              ? 'Sözleşmeli Müşteri Girişi'
                              : 'Destek Referansı Gerekli',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textSoft,
                            fontSize: compact ? 17 : 21,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: compact ? 24 : 30),
                        Container(
                          height: compact ? 58 : 66,
                          decoration: BoxDecoration(
                            color: panelSoft,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildModeButton(
                                  selected: !_contractedMode,
                                  icon: Icons.vpn_key_outlined,
                                  label: 'Referans Kodum Var',
                                  onTap: _busy
                                      ? null
                                      : () {
                                          setState(() {
                                            _contractedMode = false;
                                            _error = null;
                                          });
                                          _focusNode.requestFocus();
                                        },
                                ),
                              ),
                              Expanded(
                                child: _buildModeButton(
                                  selected: _contractedMode,
                                  icon: Icons.people_alt_outlined,
                                  label: 'Sözleşmeli Müşteriyim',
                                  onTap: _busy
                                      ? null
                                      : () {
                                          setState(() {
                                            _contractedMode = true;
                                            _error = null;
                                          });
                                        },
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: sectionGap),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 16 : 22,
                            vertical: compact ? 14 : 18,
                          ),
                          decoration: BoxDecoration(
                            color: panelSoft,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: compact ? 38 : 44,
                                height: compact ? 38 : 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accent,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.info_outline,
                                  color: accent,
                                ),
                              ),
                              SizedBox(width: compact ? 12 : 16),
                              Expanded(
                                child: Text(
                                  _contractedMode
                                      ? 'FİRMA KODUNUZU VE ŞİFRENİZİ GİRİNİZ'
                                      : 'LÜTFEN REFERANS NUMARANIZI GİRİN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: compact ? 15 : 18,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: sectionGap),
                        if (!_contractedMode) ...[
                          _buildDarkField(
                            controller: _controller,
                            focusNode: _focusNode,
                            autofocus: true,
                            enabled: !_busy,
                            label: 'Referans Kodu',
                            hint: 'Örn. OSSIS-XXXX-XXXX',
                            icon: Icons.vpn_key_outlined,
                            errorText: _error,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.done,
                            maxLength: 64,
                            onSubmitted: (_) => _verify(),
                          ),
                          SizedBox(height: compact ? 16 : 18),
                          _buildPrimaryButton(
                            busy: _busy,
                            height: compact ? 56 : 66,
                            icon: Icons.verified_user_outlined,
                            label: 'Doğrula ve Uygulamayı Aç',
                            fontSize: compact ? 17 : 20,
                            onPressed: _verify,
                          ),
                        ] else ...[
                          _buildDarkField(
                            controller: _companyCodeController,
                            enabled: !_busy,
                            label: 'Firma Kodu',
                            hint: 'Firma kodunuzu girin',
                            icon: Icons.business_outlined,
                            errorText: null,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.next,
                          ),
                          SizedBox(height: compact ? 12 : 14),
                          _buildDarkField(
                            controller: _passwordController,
                            enabled: !_busy,
                            label: 'Şifre',
                            hint: 'Şifrenizi girin',
                            icon: Icons.lock_outline,
                            errorText: _error,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _startContractedSupport(),
                          ),
                          SizedBox(height: compact ? 16 : 18),
                          _buildPrimaryButton(
                            busy: _busy,
                            height: compact ? 56 : 66,
                            icon: Icons.support_agent_outlined,
                            label: 'Destek Başlat',
                            fontSize: compact ? 17 : 20,
                            onPressed: _startContractedSupport,
                          ),
                        ],
                        SizedBox(height: compact ? 12 : 14),
                        SizedBox(
                          height: compact ? 50 : 58,
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : () => exit(0),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: panelSoft,
                              side: const BorderSide(color: border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.cancel_outlined),
                            label: Text(
                              'Bağlantıyı İptal Et',
                              style: TextStyle(
                                fontSize: compact ? 16 : 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 18 : 22),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _openSupportTicket,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 12 : 16,
                                vertical: compact ? 11 : 14,
                              ),
                              decoration: BoxDecoration(
                                color: panelSoft,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0x66D32F2F),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.language,
                                    color: accent,
                                    size: 26,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _contractedMode
                                          ? 'Destek talebi oluşturmak veya Ossis Bilişim ile iletişime geçmek için tıklayın.'
                                          : 'Referans kodunuz yoksa Ossis Bilişim destek ekibiyle iletişime geçin.',
                                      style: TextStyle(
                                        color: textSoft,
                                        fontSize: veryCompact ? 12.0 : 13.5,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: accent,
                                    size: 26,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModeButton({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    const accent = Color(0xFFD32F2F);
    const textSoft = Color(0xFFB9BDC6);

    return SizedBox.expand(
      child: Material(
        color: selected ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: selected ? Colors.white : textSoft,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFE1E3E8),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDarkField({
    required TextEditingController controller,
    required bool enabled,
    required String label,
    required String hint,
    required IconData icon,
    required TextInputAction textInputAction,
    FocusNode? focusNode,
    bool autofocus = false,
    String? errorText,
    bool obscureText = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
    ValueChanged<String>? onSubmitted,
  }) {
    const accent = Color(0xFFD32F2F);
    const panel = Color(0xFF191B20);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      maxLength: maxLength,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        counterText: '',
        filled: true,
        fillColor: panel,
        labelStyle: const TextStyle(
          color: Color(0xFFE3E5E9),
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF777C86),
        ),
        prefixIcon: Icon(icon, color: accent),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: accent,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFE53935),
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF3A3E46),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFFF6B6B),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFFF6B6B),
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required bool busy,
    required double height,
    required IconData icon,
    required String label,
    required double fontSize,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: height,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFD32F2F),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF7A2A2A),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        label: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ReferenceRejected implements Exception {
  const _ReferenceRejected(this.message);

  final String message;
}
