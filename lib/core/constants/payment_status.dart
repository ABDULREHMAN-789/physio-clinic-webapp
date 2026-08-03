class PaymentStatus {
  static const String paid = 'Paid';
  static const String unpaid = 'Unpaid';
  static const String feeWaiver = 'Fee Waiver';

  static bool isPaid(dynamic status) {
    if (status is bool) return status;
    return status == paid;
  }

  static bool isUnpaid(dynamic status) {
    if (status is bool) return !status;
    return status == unpaid;
  }

  static bool isFeeWaiver(dynamic status) {
    if (status is bool) return false;
    return status == feeWaiver;
  }

  static String parse(dynamic status, {String defaultValue = unpaid}) {
    if (status == null) return defaultValue;
    if (status is bool) {
      return status ? paid : unpaid;
    }
    final s = status.toString().trim();
    if (s.toLowerCase() == 'paid') return paid;
    if (s.toLowerCase() == 'unpaid') return unpaid;
    if (s.toLowerCase().contains('fee') || s.toLowerCase().contains('waiver') || s.toLowerCase().contains('free')) {
      return feeWaiver;
    }
    return defaultValue;
  }
}
