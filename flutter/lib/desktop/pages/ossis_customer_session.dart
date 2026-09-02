import 'ossis_entitlement_state.dart';

class OssisCustomerSession extends OssisEntitlementState {
  OssisCustomerSession._();

  static final instance = OssisCustomerSession._();

  String customerName = 'OSSIS Müşterisi';
  String referenceText = '';
  String usageToken = '';

  void updateFromPayload(
    Map<String, dynamic> payload, {
    String? reference,
  }) {
    customerName = OssisEntitlementState.firstText(payload, const [
          'customer_name',
          'company_name',
          'display_name',
          'name',
        ]) ??
        customerName;
    referenceText = reference?.trim().isNotEmpty == true
        ? reference!.trim()
        : (OssisEntitlementState.firstText(
                payload, const ['reference_code', 'reference']) ??
            referenceText);
    usageToken = OssisEntitlementState.firstText(
          payload,
          const ['usage_token'],
        ) ??
        usageToken;
    updateEntitlement(payload);
  }
}
