import 'package:dio/dio.dart';

import '../../app/config/app_config.dart';
import '../errors/api_failure.dart';
import '../security/native_platform_bridge.dart';
import 'api_response.dart';

/// Thin Laravel JSON client. Repositories own endpoint names and response
/// models; this class owns the shared envelope, timeout, and WebView-cookie
/// behavior used by the original OkHttp client.
class NextelApi {
  NextelApi({
    required AppConfig config,
    required NativePlatformBridge nativeBridge,
    Dio? dio,
  })  : _config = config,
        _nativeBridge = nativeBridge,
        _dio = dio ?? _createDio(config) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_config.isTrustedApiUri(options.uri)) {
            try {
              final cookie = await _nativeBridge.getCookieHeader(options.uri);
              if (cookie != null && cookie.isNotEmpty) {
                options.headers['cookie'] = cookie;
              }
            } catch (_) {
              // The API remains usable without a web cookie when the backend
              // does not require the app-gate or Laravel session cookie.
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          await _storeResponseCookies(response);
          handler.next(response);
        },
        onError: (error, handler) async {
          final response = error.response;
          if (response != null) await _storeResponseCookies(response);
          handler.next(error);
        },
      ),
    );
  }

  final AppConfig _config;
  final NativePlatformBridge _nativeBridge;
  final Dio _dio;

  Future<ApiResponse> get(
    String path, {
    String? bearerToken,
    Map<String, Object?>? queryParameters,
  }) =>
      _request(
        'GET',
        path,
        bearerToken: bearerToken,
        queryParameters: queryParameters,
      );

  Future<ApiResponse> post(
    String path, {
    Map<String, Object?> body = const {},
    String? bearerToken,
  }) =>
      _request(
        'POST',
        path,
        bearerToken: bearerToken,
        body: body,
      );

  Future<ApiResponse> _request(
    String method,
    String path, {
    String? bearerToken,
    Object? body,
    Map<String, Object?>? queryParameters,
  }) async {
    final headers = <String, Object>{'accept': 'application/json'};
    if (bearerToken != null && bearerToken.isNotEmpty) {
      headers['authorization'] = 'Bearer $bearerToken';
    }

    try {
      final response = await _dio.request<Object?>(
        path.replaceFirst(RegExp(r'^/+'), ''),
        data: body,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          headers: headers,
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          validateStatus: (status) => status != null,
        ),
      );
      return _parseResponse(response);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw _failureFromDio(error);
    } catch (_) {
      throw const ApiFailure(
        statusCode: 0,
        message: 'The server returned an invalid response.',
      );
    }
  }

  ApiResponse _parseResponse(Response<Object?> response) {
    final status = response.statusCode ?? 0;
    final envelope = _asStringMap(response.data);
    final message = _nonEmptyString(envelope['message']) ??
        (status >= 200 && status < 300
            ? 'Request completed.'
            : 'The request could not be completed.');
    final declaredSuccess = envelope['success'] is bool
        ? envelope['success']! as bool
        : status >= 200 && status < 300;

    if (status >= 200 && status < 300 && declaredSuccess) {
      final rawCookies = response.headers['set-cookie'] ?? const <String>[];
      return ApiResponse(
        statusCode: status,
        message: message,
        data: envelope['data'] ?? const <String, Object?>{},
        cookies: List.unmodifiable(rawCookies),
      );
    }

    throw ApiFailure(
      statusCode: status,
      message: message,
      fieldErrors: _parseFieldErrors(envelope['errors']),
      retryAfterSeconds: _retryAfterSeconds(response.headers),
      data: envelope['data'] ?? const <String, Object?>{},
    );
  }

  ApiFailure _failureFromDio(DioException error) {
    final response = error.response;
    if (response != null) {
      try {
        _parseResponse(response);
      } on ApiFailure catch (failure) {
        return failure;
      } catch (_) {
        // Fall through to the transport fallback below.
      }
    }

    final message = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'The server took too long to respond. Please try again.',
      DioExceptionType.connectionError => 'Unable to reach the server.',
      _ => error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : 'Unable to complete the request. Please try again.',
    };
    return ApiFailure(
      statusCode: response?.statusCode ?? 0,
      message: message,
    );
  }

  Future<void> _storeResponseCookies(Response<Object?> response) async {
    final cookies = response.headers['set-cookie'];
    if (cookies == null || cookies.isEmpty ||
        !_config.isTrustedNextelUri(response.requestOptions.uri)) {
      return;
    }
    try {
      await _nativeBridge.setCookies(response.requestOptions.uri, cookies);
    } catch (_) {
      // Cookie failures are surfaced explicitly by the web-session handoff;
      // unrelated API responses are not discarded because of one cookie.
    }
  }

  static Dio _createDio(AppConfig config) => Dio(
        BaseOptions(
          baseUrl: '${config.apiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}/',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          headers: const {'accept': 'application/json'},
        ),
      );

  static Map<String, Object?> _asStringMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static Map<String, List<String>> _parseFieldErrors(Object? value) {
    final errors = _asStringMap(value);
    return errors.map((key, messages) {
      final normalized = switch (messages) {
        List values => values.map((item) => item.toString()).toList(),
        null => const <String>[],
        _ => <String>[messages.toString()],
      };
      return MapEntry(
        key,
        normalized.where((message) => message.isNotEmpty).toList(),
      );
    })..removeWhere((_, values) => values.isEmpty);
  }

  static String? _nonEmptyString(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value;
  }

  static int? _retryAfterSeconds(Headers headers) =>
      int.tryParse(headers.value('retry-after') ?? '');
}
