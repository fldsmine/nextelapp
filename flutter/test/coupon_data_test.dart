import 'package:flutter_test/flutter_test.dart';
import 'package:nextel_connect/features/coupon/domain/coupon_data.dart';
import 'package:nextel_connect/features/coupon/domain/coupon_validation.dart';

void main() {
  group('Coupon API model parsing', () {
    test('preserves coupon state and nested API details', () {
      final coupon = CouponData.fromJson({
        'id': 12,
        'code': 'NEXTEL-2026',
        'type': 'package',
        'type_name': 'Data bundle',
        'price': 3500,
        'region': 'nigeria',
        'is_special': 'true',
        'is_valid': true,
        'status': 'available',
        'package': {
          'id': 8,
          'name': 'Monthly bundle',
          'price': 3500,
          'duration': '30 days',
          'storage_size': '10 GB',
        },
        'additional_minute_plan': {'name': 'Voice pack'},
        'batch': {
          'reference': 'BATCH-42',
          'type_name': 'Retail',
          'region': 'foreign',
          'created_at': '2026-06-01T10:30:00Z',
        },
        'agent': {'name': 'Ada Agent', 'username': 'ada'},
        'redeemer': {'name': 'Sam Customer'},
        'verification': {
          'is_valid': true,
          'status': 'valid',
          'message': 'Ready to redeem',
        },
      });

      expect(coupon.id, '12');
      expect(coupon.price, '3500');
      expect(coupon.isSpecial, isTrue);
      expect(coupon.isValid, isTrue);
      expect(coupon.product?.name, 'Monthly bundle');
      expect(coupon.batch?.reference, 'BATCH-42');
      expect(coupon.agent?.username, 'ada');
      expect(coupon.redeemer?.name, 'Sam Customer');
      expect(coupon.verification?.message, 'Ready to redeem');
    });

    test('defaults absent values without inventing a valid coupon', () {
      final coupon = CouponData.fromJson(null);

      expect(coupon.isValid, isFalse);
      expect(coupon.isSpecial, isFalse);
      expect(coupon.product, isNull);
      expect(coupon.code, isNull);
    });
  });

  group('Coupon code validation', () {
    test('trims and validates required/minimum length', () {
      expect(CouponValidation.codeError('  '), 'Please enter a coupon code.');
      expect(CouponValidation.codeError(' ab '), 'Coupon code is too short.');
      expect(CouponValidation.codeError(' abc '), isNull);
    });

    test('matches the legacy input maximum', () {
      expect(
        CouponValidation.codeError(List.filled(101, 'X').join()),
        'Coupon code is too long.',
      );
      expect(CouponValidation.maxCodeLength, 100);
    });
  });
}
