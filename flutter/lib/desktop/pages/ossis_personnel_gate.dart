import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _personnelLoginUrl =
    'https://servis.ossisbilisim.com:8443/api/v1/personnel/login/';

const _personnelSessionUrl =
    'https://servis.ossisbilisim.com:8443/api/v1/personnel/session/';

class OssisPersonnelGate extends StatefulWidget {
  const OssisPersonnelGate({
    super.key,
    required this.child,
    required this.onApproved,
  });

  final Widget child;
  final Future<void> Function() onApproved;

  @override
  State<OssisPersonnelGate> createState() => _OssisPersonnelGateState();
}

class _OssisPersonnelGateState extends State<OssisPersonnelGate> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();

  bool _approved = false;
  bool _busy = false;
  bool _passwordVisible = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _decodeResponse(
    http.Response response,
  ) async {
    try {
      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      // Sunucudan JSON olmayan cevap gelirse null döner.
    }

    return null;
  }

  Future<void> _login() async {
    if (_busy) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Kullanıcı adı ve şifre zorunludur.';
      });

      if (username.isEmpty) {
        _usernameFocusNode.requestFocus();
      }

      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse(_personnelLoginUrl),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final payload = await _decodeResponse(response);

      if (response.statusCode != 200 ||
          payload?['valid'] != true) {
        final errorCode = payload?['error']?.toString();

        final message = switch (errorCode) {
          'credentials_required' =>
            'Kullanıcı adı ve şifre zorunludur.',
          'invalid_credentials' =>
            'Kullanıcı adı veya şifre hatalı.',
          'personnel_access_denied' =>
            'Bu hesabın Ossis Remote personel erişimi yok.',
          _ =>
            'Personel girişi doğrulanamadı.',
        };

        throw _PersonnelRejected(message);
      }

      final token = payload?['token']?.toString().trim() ?? '';

      if (token.isEmpty) {
        throw const _PersonnelRejected(
          'Sunucudan geçerli personel oturumu alınamadı.',
        );
      }

      // Tokenı ayrıca session endpoint'i üzerinden doğrula.
      final sessionResponse = await http
          .post(
            Uri.parse(_personnelSessionUrl),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'token': token,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final sessionPayload =
          await _decodeResponse(sessionResponse);

      if (sessionResponse.statusCode != 200 ||
          sessionPayload?['valid'] != true) {
        throw const _PersonnelRejected(
          'Personel oturumu doğrulanamadı.',
        );
      }

      // Şifre artık gerekli değil; bellekte tutma.
      _passwordController.clear();

      await widget.onApproved();

      if (!mounted) return;

      setState(() {
        _approved = true;
        _busy = false;
        _error = null;
      });
    } on _PersonnelRejected catch (e) {
      if (!mounted) return;

      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _busy = false;
        _error =
            'Ossis sunucusuna bağlanılamadı. '
            'İnternet bağlantınızı kontrol edin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_approved) {
      return widget.child;
    }

    return Material(
      color: const Color(0xFF101317),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 460,
            ),
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: const Color(0xFF181D22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF30363D),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 30,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'OSSIS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFE62B2F),
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'REMOTE SERVICE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF9DA7B0),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Personel Girişi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ossis personel kullanıcı bilgilerinizle '
                    'oturum açın.',
                    style: TextStyle(
                      color: Color(0xFF939DA7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _usernameController,
                    focusNode: _usernameFocusNode,
                    enabled: !_busy,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(
                      label: 'Kullanıcı Adı',
                      icon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _passwordController,
                    enabled: !_busy,
                    obscureText: !_passwordVisible,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
                    decoration: _inputDecoration(
                      label: 'Şifre',
                      icon: Icons.lock_outline,
                    ).copyWith(
                      suffixIcon: IconButton(
                        onPressed: _busy
                            ? null
                            : () {
                                setState(() {
                                  _passwordVisible =
                                      !_passwordVisible;
                                });
                              },
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF939DA7),
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF351B1E),
                        borderRadius:
                            BorderRadius.circular(7),
                        border: Border.all(
                          color: const Color(0xFF713038),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFFFB9BC),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFE62B2F),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFF6B292C),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 21,
                              height: 21,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'GİRİŞ YAP',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w800,
                                letterSpacing: .4,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(
                    color: Color(0xFF30363D),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ossis Bilişim Teknolojileri',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF727C85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF9DA7B0),
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF9DA7B0),
      ),
      filled: true,
      fillColor: const Color(0xFF111519),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFF3A424A),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFFE62B2F),
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _PersonnelRejected implements Exception {
  const _PersonnelRejected(this.message);

  final String message;
}