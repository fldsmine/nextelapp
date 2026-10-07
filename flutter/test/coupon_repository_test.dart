import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextel_connect/app/config/app_config.dart';
import 'package:nextel_connect/core/network/api_response.dart';
import 'package:nextel_connect/core/network/nextel_api.dart';
import 'package:nextel_connect/core/security/native_platform_bridge.dart';
import 'package:nextel_connect/features/coupon/data/coupon_repository.dart';

void main() {
  test('uses the public verification endpoint with code as a query parameter', () async {
    final api = _RecordingNextelApi();
    final repository = CouponRepository(api: api);

    final coupon = await repository.verifyCode('PROMO + 42');

    expect(api.path, 'coupons/verify');
    expect(api.queryParameters, {'code': 'PROMO + 42'});
    expect(api.bearerToken, isNull);
    expect(coupon.code, 'PROMO-42');
  });
}

class _RecordingNextelApi extends NextelApi {
  _RecordingNextelApi()
      : super(
          config: const AppConfig(
            webBaseUrl: 'https://nextel.example',
            apiBaseUrl: 'https://nextel.example/api/v1',
            frontBaseUrl: 'https://nextel.example',
            updateApiBaseUrl: 'https://nextel.example/api/v1',
            versionName: 'test',
            versionCode: 1,
            appGateCookieConfigured: false,
          ),
          nativeBridge: NativePlatformBridge(),
          dio: Dio(),
        );

  String? path;
  String? bearerToken;
  Map<String, Object?>? queryParameters;

  @override
  Future<ApiResponse> get(
    String path, {
    String? bearerToken,
    Map<String, Object?>? queryParameters,
  }) async {
    this.path = path;
    this.bearerToken = bearerToken;
    this.queryParameters = queryParameters;
    return const ApiResponse(
      statusCode: 200,
      message: 'OK',
      data: {'code': 'PROMO-42', 'is_valid': true},
    );
  }
}
