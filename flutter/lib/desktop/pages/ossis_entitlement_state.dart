import 'dart:async';

import 'package:flutter/foundation.dart';

abstract class OssisEntitlementState extends ChangeNotifier {
  Timer? _countdown;
  int? credit;
  int? remainingSeconds;

  String get creditText => credit?.toString() ?? 'Sunucudan alınmadı';

  String get remainingTimeText {
    final seconds = remainingSeconds;
    if (seconds == null) return 'Sunucudan alınmadı';
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return '$minutes dk';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours sa' : '$hours sa $rest dk';
  }

  bool get hasServerEntitlement => credit != null || remainingSeconds != null;
  bool get isExhausted => credit == 0 || remainingSeconds == 0;

  void updateEntitlement(Map<String, dynamic> payload) {
    final creditValue = firstNumber(payload, const [
      'credit',
      'credits',
      'balance',
      'credit_balance',
      'remaining_credit',
    ]);
    final secondsValue = firstNumber(payload, const [
      'remaining_seconds',
      'seconds_remaining',
      'remaining_time_seconds',
    ]);
    final minutesValue = firstNumber(payload, const [
      'remaining_minutes',
      'minutes_remaining',
      'remaining_time_minutes',
      'available_minutes',
      'minute_balance',
    ]);
    final expiresAtValue = firstText(payload, const [
      'expires_at',
      'support_expires_at',
      'entitlement_expires_at',
    ]);

    if (creditValue != null) {
      credit = creditValue.floor().clamp(0, 1 << 31).toInt();
    }
    if (secondsValue != null) {
      remainingSeconds =
          secondsValue.floor().clamp(0, 1 << 31).toInt();
    } else if (minutesValue != null) {
      remainingSeconds =
          (minutesValue * 60).floor().clamp(0, 1 << 31).toInt();
    } else if (expiresAtValue != null) {
      final expiresAt = DateTime.tryParse(expiresAtValue);
      if (expiresAt != null) {
        remainingSeconds = expiresAt
            .difference(DateTime.now())
            .inSeconds
            .clamp(0, 1 << 31)
            .toInt();
      }
    }
    _syncCountdown();
  }

  void _syncCountdown() {
    _countdown?.cancel();
    if (remainingSeconds == null || remainingSeconds! <= 0) {
      notifyListeners();
      return;
    }
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = remainingSeconds;
      if (current == null || current <= 1) {
        remainingSeconds = 0;
        timer.cancel();
      } else {
        remainingSeconds = current - 1;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  static dynamic firstValue(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    for (final key in keys) {
      if (payload[key] != null) return payload[key];
    }
    for (final value in payload.values) {
      if (value is Map) {
        final nested = firstValue(Map<String, dynamic>.from(value), keys);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  static String? firstText(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    final text = firstValue(payload, keys)?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static num? firstNumber(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    final value = firstValue(payload, keys);
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }
}
