import 'package:flutter/foundation.dart';

class OssisCustomerSession extends ChangeNotifier {
  OssisCustomerSession._();

  static final instance = OssisCustomerSession._();

  String customerName = 'OSSIS Müşterisi';
  String creditText = 'Sunucudan alınmadı';
  String remainingTimeText = 'Sunucudan alınmadı';
  String referenceText = '';

  void updateFromPayload(
    Map<String, dynamic> payload, {
    String? reference,
  }) {
    customerName = _firstText(payload, const [
          'customer_name',
          'company_name',
          'display_name',
          'name',
        ]) ??
        customerName;
    referenceText = reference?.trim().isNotEmpty == true
        ? reference!.trim()
        : (_firstText(payload, const ['reference_code', 'reference']) ??
            referenceText);

    final credit = _firstValue(payload, const [
      'credit',
      'credits',
      'balance',
      'credit_balance',
      'remaining_credit',
    ]);
    if (credit != null) creditText = credit.toString();

    final minutes = _firstNumber(payload, const [
      'remaining_minutes',
      'minutes_remaining',
      'available_minutes',
      'minute_balance',
    ]);
    final seconds = _firstNumber(payload, const [
      'remaining_seconds',
      'seconds_remaining',
    ]);
    if (minutes != null) {
      remainingTimeText = _formatMinutes(minutes.round());
    } else if (seconds != null) {
      remainingTimeText = _formatMinutes((seconds / 60).ceil());
    } else {
      remainingTimeText = _firstText(payload, const [
            'remaining_time',
            'time_remaining',
            'duration_remaining',
          ]) ??
          remainingTimeText;
    }
    notifyListeners();
  }

  static String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes dk';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours sa' : '$hours sa $rest dk';
  }

  static String? _firstText(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    final value = _firstValue(payload, keys);
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static num? _firstNumber(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    final value = _firstValue(payload, keys);
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }

  static dynamic _firstValue(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    for (final key in keys) {
      if (payload[key] != null) return payload[key];
    }
    for (final value in payload.values) {
      if (value is Map) {
        final nested = _firstValue(Map<String, dynamic>.from(value), keys);
        if (nested != null) return nested;
      }
    }
    return null;
  }
}
