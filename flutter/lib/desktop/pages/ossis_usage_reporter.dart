import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ossis_customer_session.dart';
import 'ossis_personnel_session.dart';

const _referenceConnectionUrl =
    'https://servis.ossisbilisim.com:8443/api/v1/reference/connection/';

class OssisUsageReporter {
  OssisUsageReporter._();

  static final instance = OssisUsageReporter._();

  DateTime? _lastReportAt;
  bool? _lastConnected;
  String _lastConnectionKey = '';
  bool _busy = false;

  Future<bool> reportCustomer({
    required bool connected,
    required String connectionKey,
  }) {
    final session = OssisCustomerSession.instance;
    return _report(
      role: 'customer',
      connected: connected,
      connectionKey: connectionKey,
      credentialKey: 'usage_token',
      credential: session.usageToken,
      onUsage: session.updateEntitlement,
    );
  }

  Future<bool> reportPersonnel({
    required bool connected,
    required String connectionKey,
  }) {
    final session = OssisPersonnelSession.instance;
    return _report(
      role: 'personnel',
      connected: connected,
      connectionKey: connectionKey,
      credentialKey: 'personnel_token',
      credential: session.token,
      onUsage: session.updateEntitlement,
    );
  }

  Future<bool> _report({
    required String role,
    required bool connected,
    required String connectionKey,
    required String credentialKey,
    required String credential,
    required void Function(Map<String, dynamic>) onUsage,
  }) async {
    if (_busy || credential.isEmpty) return false;
    if (connectionKey.isNotEmpty) _lastConnectionKey = connectionKey;
    final effectiveConnectionKey =
        connectionKey.isEmpty ? _lastConnectionKey : connectionKey;
    final now = DateTime.now();
    if (_lastConnected == connected &&
        _lastReportAt != null &&
        now.difference(_lastReportAt!) < const Duration(seconds: 9)) {
      return true;
    }
    _busy = true;
    try {
      final response = await http
          .post(
            Uri.parse(_referenceConnectionUrl),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'role': role,
              'connected': connected,
              'connection_key': effectiveConnectionKey,
              credentialKey: credential,
            }),
          )
          .timeout(const Duration(seconds: 8));
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map || response.statusCode != 200) return false;
      final payload = Map<String, dynamic>.from(decoded);
      if (payload['valid'] != true) return false;
      // Entitlement alanlari usage/data/entitlement veya top-level olabilir.
      // Parser recursive oldugu icin basarili cevabin tamamini isle.
      onUsage(payload);
      _lastConnected = connected;
      _lastReportAt = now;
      return true;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }
}
