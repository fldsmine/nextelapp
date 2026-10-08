import 'package:flutter_test/flutter_test.dart';
import 'package:nextel_connect/features/update/domain/app_update_info.dart';

Map<String, Object?> response({
  bool updateAvailable = true,
  bool updateRequired = false,
  bool forceUpdate = false,
  int buildNumber = 5,
  int minimumSupportedBuild = 0,
  String? downloadUrl = 'https://downloads.example/nextel.apk',
  String? playStoreUrl = 'https://play.google.com/store/apps/details?id=nextel',
}) => {
      'success': true,
      'data': {
        'update_available': updateAvailable,
        'update_required': updateRequired,
        'latest': {
          'version_name': '3.6.0',
          'build_number': buildNumber,
          'minimum_supported_build': minimumSupportedBuild,
          'force_update': forceUpdate,
          'title': 'A brighter Nextel',
          'release_notes': '- Faster loading\n2. Better search',
          'server_download_url': downloadUrl,
          'play_store_url': playStoreUrl,
          'published_at': '2026-10-08T10:00:00Z',
        },
      },
    };

void main() {
  group('AppUpdateInfo API parsing', () {
    test('maps the existing endpoint contract and mandatory rules', () {
      final update = AppUpdateInfo.fromApiResponse(
        response(minimumSupportedBuild: 5),
        currentBuild: 4,
      );

      expect(update, isNotNull);
      expect(update!.versionName, '3.6.0');
      expect(update.buildNumber, 5);
      expect(update.currentBuild, 4);
      expect(update.title, 'A brighter Nextel');
      expect(update.serverDownloadUri?.scheme, 'https');
      expect(update.playStoreUri?.host, 'play.google.com');
      expect(update.isMandatory, isTrue);
    });

    test('force and update-required flags make an update mandatory', () {
      final forced = AppUpdateInfo.fromApiResponse(
        response(forceUpdate: true),
        currentBuild: 4,
      );
      final required = AppUpdateInfo.fromApiResponse(
        response(updateRequired: true),
        currentBuild: 4,
      );

      expect(forced?.isMandatory, isTrue);
      expect(required?.isMandatory, isTrue);
    });

    test('returns null if there is no newer release', () {
      expect(
        AppUpdateInfo.fromApiResponse(
          response(updateAvailable: false),
          currentBuild: 4,
        ),
        isNull,
      );
      expect(
        AppUpdateInfo.fromApiResponse(
          response(buildNumber: 4),
          currentBuild: 4,
        ),
        isNull,
      );
    });

    test('rejects an incomplete update envelope', () {
      expect(
        () => AppUpdateInfo.fromApiResponse(const {}, currentBuild: 4),
        throwsFormatException,
      );
    });

    test('does not expose non-HTTPS or credential-bearing update links', () {
      final update = AppUpdateInfo.fromApiResponse(
        response(
          downloadUrl: 'http://downloads.example/nextel.apk',
          playStoreUrl: 'https://user:password@store.example/nextel',
        ),
        currentBuild: 4,
      )!;

      expect(update.serverDownloadUri, isNull);
      expect(update.playStoreUri, isNull);
    });

    test('round-trips saved update data', () {
      final update = AppUpdateInfo.fromApiResponse(
        response(),
        currentBuild: 4,
      )!;

      expect(AppUpdateInfo.fromJson(update.toJson()).toJson(), update.toJson());
    });
  });
}
