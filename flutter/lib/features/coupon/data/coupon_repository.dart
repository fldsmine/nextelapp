import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/nextel_api.dart';
import '../domain/coupon_data.dart';

class CouponRepository {
  const CouponRepository({required NextelApi api}) : _api = api;

  final NextelApi _api;

  Future<CouponData> verifyCode(String code) async {
    final response = await _api.get(
      'coupons/verify',
      queryParameters: {'code': code},
    );
    return CouponData.fromJson(response.data);
  }
}

final couponRepositoryProvider = Provider<CouponRepository>((ref) {
  return CouponRepository(api: ref.watch(nextelApiProvider));
});
