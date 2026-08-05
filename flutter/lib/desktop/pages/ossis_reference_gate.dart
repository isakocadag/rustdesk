import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

const _referenceVerificationUrl =
    'https://servis.ossisbilisim.com/api/reference/verify';

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
  final _focusNode = FocusNode();
  bool _approved = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
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

      final serverMessage = payload?['message'];
      throw _ReferenceRejected(
        serverMessage is String && serverMessage.trim().isNotEmpty
            ? serverMessage.trim()
            : 'Referans kodu geçersiz veya kullanım süresi dolmuş.',
      );
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
                      'Destek Referansı Gerekli',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ossis Remote Control uygulamasını açmak için size iletilen geçerli referans kodunu girin.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 26),
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
                    const SizedBox(height: 16),
                    Text(
                      'Referans kodunuz yoksa Ossis Bilişim destek ekibiyle iletişime geçin.',
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
