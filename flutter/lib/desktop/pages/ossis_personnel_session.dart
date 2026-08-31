import 'package:flutter/foundation.dart';

class OssisPersonnelSession extends ChangeNotifier {
  OssisPersonnelSession._();

  static final instance = OssisPersonnelSession._();

  String displayName = 'Personel';
  String username = '';
  String creditText = 'Sunucudan alınmadı';
  String remainingTimeText = 'Sunucudan alınmadı';
  String planText = 'Standart';

  void updateFromPayload(Map<String, dynamic> payload) {
    displayName = _firstText(payload, const [
          'display_name',
          'full_name',
          'name',
          'personnel_name',
        ]) ??
        displayName;
    username = _firstText(payload, const [
          'username',
          'user_name',
          'email',
        ]) ??
        username;
    planText = _firstText(payload, const [
          'plan_name',
          'package_name',
          'subscription_name',
        ]) ??
        planText;

    final credit = _firstValue(payload, const [
      'credit',
      'credits',
      'balance',
      'credit_balance',
      'remaining_credit',
    ]);
    if (credit != null) {
      creditText = credit.toString();
    }

    final remainingMinutes = _firstNumber(payload, const [
      'remaining_minutes',
      'minutes_remaining',
      'remaining_time_minutes',
      'available_minutes',
      'minute_balance',
    ]);
    final remainingSeconds = _firstNumber(payload, const [
      'remaining_seconds',
      'seconds_remaining',
      'remaining_time_seconds',
    ]);
    if (remainingMinutes != null) {
      remainingTimeText = _formatMinutes(remainingMinutes.round());
    } else if (remainingSeconds != null) {
      remainingTimeText = _formatMinutes((remainingSeconds / 60).ceil());
    } else {
      final formatted = _firstText(payload, const [
        'remaining_time',
        'time_remaining',
        'duration_remaining',
      ]);
      if (formatted != null) remainingTimeText = formatted;
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
        final nested = _firstValue(
          Map<String, dynamic>.from(value),
          keys,
        );
        if (nested != null) return nested;
      }
    }
    return null;
  }
}
