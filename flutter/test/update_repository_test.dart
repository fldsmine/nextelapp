import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextel_connect/app/config/app_config.dart';
import 'package:nextel_connect/core/security/native_platform_bridge.dart';
import 'package:nextel_connect/features/update/data/update_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final Future<ResponseBody> Function(RequestOptions options) respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeNativeBridge extends NativePlatformBridge {
  _FakeNativeBridge(this.backgroundState);

  final Map<String, Object?>? backgroundState;

  @override
  Future<Map<String, Object?>?> readBackgroundUpdateState() async =>
      backgroundState;
}

const _config = AppConfig(
  webBaseUrl: 'https://nextel.example',
  apiBaseUrl: 'https://nextel.example/api/v1',
  frontBaseUrl: 'https://nextel.example',
  updateApiBaseUrl: 'https://updates.example/api/v1',
  versionName: '3.5.alpha',
  versionCode: 4,
  appGateCookieConfigured: false,
);

Map<String, Object?> _upgradeResponse({
  bool updateAvailable = true,
  bool updateRequired = false,
  bool forceUpdate = false,
}) => {
      'success': true,
      'data': {
        'update_available': updateAvailable,
        'update_required': updateRequired,
        'latest': {
          'version_name': '3.6.0',
          'build_number': 5,
          'minimum_supported_build': 0,
          'force_update': forceUpdate,
          'title': 'Nextel update',
          'release_notes': 'Stability improvements',
          'server_download_url': 'https://updates.example/nextel.apk',
          'play_store_url': null,
          'published_at': null,
        },
      },
    };

Map<String, Object?> _cachedUpdate({bool updateRequired = false}) => {
      'current_build': 4,
      'update_required': updateRequired,
      'version_name': '3.6.0',
      'build_number': 5,
      'minimum_supported_build': 0,
      'force_update': false,
      'title': 'Nextel update',
      'release_notes': 'Stability improvements',
      'server_download_url': 'https://updates.example/nextel.apk',
      'play_store_url': null,
      'published_at': null,
    };

Future<ResponseBody> _jsonResponse(Object? data) async =>
    ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: const {Headers.contentTypeHeader: ['application/json']},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UpdateRepository', () {
    test('uses the Kotlin endpoint query contract and stores an available update',
        () async {
      final preferences = await SharedPreferences.getInstance();
      final fixedNow = DateTime.utc(2026, 10, 8, 12);
      final adapter = _FakeAdapter((_) => _jsonResponse(_upgradeResponse()));
      final dio = Dio(BaseOptions(baseUrl: 'https://updates.example/api/v1/'))
        ..httpClientAdapter = adapter;
      final repository = UpdateRepository(
        config: _config,
        preferences: preferences,
        dio: dio,
        clock: () => fixedNow,
      );

      final update = await repository.checkNow();

      expect(update?.buildNumber, 5);
      expect(adapter.requests, hasLength(1));
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.uri.path, '/api/v1/app-upgrade');
      expect(request.queryParameters['platform'], 'android');
      expect(request.queryParameters['current_version'], '3.5.alpha');
      expect(request.queryParameters['current_build'], '4');
      expect(
        preferences.getInt('flutter_update_last_successful_check'),
        fixedNow.millisecondsSinceEpoch,
      );
      expect(
        (await repository.readCachedUpdate())?.toJson(),
        update?.toJson(),
      );
    });

    test('does not repeat an optional startup prompt inside the daily window',
        () async {
      final preferences = await SharedPreferences.getInstance();
      final fixedNow = DateTime.utc(2026, 10, 8, 12);
      final adapter = _FakeAdapter((_) => _jsonResponse(_upgradeResponse()));
      final dio = Dio(BaseOptions(baseUrl: 'https://updates.example/api/v1/'))
        ..httpClientAdapter = adapter;
      final repository = UpdateRepository(
        config: _config,
        preferences: preferences,
        dio: dio,
        clock: () => fixedNow,
      );

      final firstPrompt = await repository.checkForStartup();
      expect(firstPrompt, isNotNull);
      await repository.markPrompted(firstPrompt!);

      expect(await repository.checkForStartup(), isNull);
      expect(adapter.requests, hasLength(1));
    });

    test('imports a WorkManager result for the foreground prompt', () async {
      final preferences = await SharedPreferences.getInstance();
      final fixedNow = DateTime.utc(2026, 10, 8, 12);
      final adapter = _FakeAdapter((_) => throw StateError('Unexpected request'));
      final dio = Dio(BaseOptions(baseUrl: 'https://updates.example/api/v1/'))
        ..httpClientAdapter = adapter;
      final repository = UpdateRepository(
        config: _config,
        preferences: preferences,
        nativeBridge: _FakeNativeBridge({
          'checkedAt': fixedNow.millisecondsSinceEpoch,
          'updateInfoJson': jsonEncode(_cachedUpdate()),
        }),
        dio: dio,
        clock: () => fixedNow,
      );

      final update = await repository.checkForStartup();

      expect(update?.versionName, '3.6.0');
      expect(adapter.requests, isEmpty);
      expect(
        preferences.getInt('flutter_update_last_successful_check'),
        fixedNow.millisecondsSinceEpoch,
      );
      await repository.markPrompted(update!);
      expect(await repository.pendingUpdatePrompt(), isNull);
    });

    test('re-shows a cached mandatory update without waiting a day', () async {
      final preferences = await SharedPreferences.getInstance();
      final fixedNow = DateTime.utc(2026, 10, 8, 12);
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(_upgradeResponse(updateRequired: true)),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://updates.example/api/v1/'))
        ..httpClientAdapter = adapter;
      final repository = UpdateRepository(
        config: _config,
        preferences: preferences,
        dio: dio,
        clock: () => fixedNow,
      );

      expect((await repository.checkNow())?.isMandatory, isTrue);
      expect((await repository.checkForStartup())?.isMandatory, isTrue);
      expect(adapter.requests, hasLength(1));
    });

    test('clears cached updates after the installed build catches up', () async {
      final preferences = await SharedPreferences.getInstance();
      final fixedNow = DateTime.utc(2026, 10, 8, 12);
      final adapter = _FakeAdapter((_) => _jsonResponse(_upgradeResponse()));
      final dio = Dio(BaseOptions(baseUrl: 'https://updates.example/api/v1/'))
        ..httpClientAdapter = adapter;
      final repository = UpdateRepository(
        config: _config,
        preferences: preferences,
        dio: dio,
        clock: () => fixedNow,
      );
      await repository.checkNow();

      final upgradedConfig = AppConfig(
        webBaseUrl: _config.webBaseUrl,
        apiBaseUrl: _config.apiBaseUrl,
        frontBaseUrl: _config.frontBaseUrl,
        updateApiBaseUrl: _config.updateApiBaseUrl,
        versionName: '3.6.0',
        versionCode: 5,
        appGateCookieConfigured: false,
      );
      final upgradedRepository = UpdateRepository(
        config: upgradedConfig,
        preferences: preferences,
        dio: dio,
        clock: () => fixedNow,
      );

      expect(await upgradedRepository.readCachedUpdate(), isNull);
      expect(preferences.getString('flutter_update_cached_info'), isNull);
    });
  });
}
