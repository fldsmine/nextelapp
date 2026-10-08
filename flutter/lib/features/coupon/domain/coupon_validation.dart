abstract final class CouponValidation {
  static const int minCodeLength = 3;
  static const int maxCodeLength = 100;

  static String? codeError(String value) {
    final code = value.trim();
    if (code.isEmpty) return 'Please enter a coupon code.';
    if (code.length < minCodeLength) return 'Coupon code is too short.';
    if (code.length > maxCodeLength) return 'Coupon code is too long.';
    return null;
  }
}
