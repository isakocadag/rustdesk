import 'dart:io';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

const _referenceVerificationUrl =
    'https://servis.ossisbilisim.com:8443/api/v1/reference/validate/';

const _contractedSupportUrl =
    'https://servis.ossisbilisim.com:8443/api/v1/support/contracted/';

class OssisReferenceGate extends StatefulWidget {
  const OssisReferenceGate({
    super.key,
    required this.child,
    required this.onApproved,
  });

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

  @override
  Widget build(BuildContext context) {
    if (_approved) return widget.child;

    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(36, 34, 36, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/icon.png', height: 64, width: 64),
                    const SizedBox(height: 22),
                    Text(
                      'Ossis Remote Control',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _contractedMode
                          ? 'Sözleşmeli Müşteri Girişi'
                          : 'Destek Referansı Gerekli',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: _contractedMode
                              ? OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () {
                                          setState(() {
                                            _contractedMode = false;
                                            _error = null;
                                          });
                                          _focusNode.requestFocus();
                                        },
                                  child: const Text('Referans Kodum Var'),
                                )
                              : FilledButton(
                                  onPressed: null,
                                  child: const Text('Referans Kodum Var'),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _contractedMode
                              ? FilledButton(
                                  onPressed: null,
                                  child: const Text('Sözleşmeli Müşteriyim'),
                                )
                              : OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () {
                                          setState(() {
                                            _contractedMode = true;
                                            _error = null;
                                          });
                                        },
                                  child: const Text('Sözleşmeli Müşteriyim'),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (!_contractedMode) ...[
                      Text(
                        'Ossis Remote Control uygulamasını açmak için size iletilen geçerli referans kodunu girin.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        enabled: !_busy,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        maxLength: 64,
                        decoration: InputDecoration(
                          labelText: 'Referans kodu',
                          hintText: 'Örn. OSSIS-XXXX-XXXX',
                          errorText: _error,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                          counterText: '',
                        ),
                        onSubmitted: (_) => _verify(),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _busy ? null : _verify,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: _busy
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: colors.onPrimary,
                                ),
                              )
                            : const Text('Doğrula ve Uygulamayı Aç'),
                      ),
                    ] else ...[
                      Text(
                        'Firma kodunuz ve şifreniz ile doğrudan destek başlatabilirsiniz.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _companyCodeController,
                        enabled: !_busy,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Firma kodu',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        enabled: !_busy,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          errorText: _error,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                        onSubmitted: (_) => _startContractedSupport(),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _busy ? null : _startContractedSupport,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: _busy
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: colors.onPrimary,
                                ),
                              )
                            : const Text('Destek Başlat'),
                      ),
                    ],
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _busy ? null : () => exit(0),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text('Bağlantıyı İptal Et'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _contractedMode
                          ? 'Sözleşmeli müşteriler firma kodu ve şifre ile ek onay beklemeden destek başlatabilir.'
                          : 'Referans kodunuz yoksa Ossis Bilişim destek ekibiyle iletişime geçin.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
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
