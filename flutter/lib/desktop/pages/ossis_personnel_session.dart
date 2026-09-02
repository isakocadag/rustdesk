import 'ossis_entitlement_state.dart';

class OssisPersonnelSession extends OssisEntitlementState {
  OssisPersonnelSession._();

  static final instance = OssisPersonnelSession._();

  String displayName = 'Personel';
  String username = '';
  String planText = 'Standart';
  String token = '';

  void updateFromPayload(Map<String, dynamic> payload) {
    token = OssisEntitlementState.firstText(payload, const ['token']) ?? token;
    displayName = OssisEntitlementState.firstText(payload, const [
          'display_name',
          'full_name',
          'name',
          'personnel_name',
        ]) ??
        displayName;
    username = OssisEntitlementState.firstText(payload, const [
          'username',
          'user_name',
          'email',
        ]) ??
        username;
    planText = OssisEntitlementState.firstText(payload, const [
          'plan_name',
          'package_name',
          'subscription_name',
        ]) ??
        planText;

    updateEntitlement(payload);
  }
}
