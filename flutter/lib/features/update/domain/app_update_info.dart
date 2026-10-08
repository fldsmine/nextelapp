import 'package:flutter/foundation.dart';

@immutable
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentBuild,
    required this.updateRequired,
    required this.versionName,
    required this.buildNumber,
    required this.minimumSupportedBuild,
    required this.forceUpdate,
    required this.title,
    required this.releaseNotes,
    required this.serverDownloadUrl,
    required this.playStoreUrl,
    required this.publishedAt,
  });

  final int currentBuild;
  final bool updateRequired;
  final String versionName;
  final int buildNumber;
  final int minimumSupportedBuild;
  final bool forceUpdate;
  final String title;
  final String releaseNotes;
  final String? serverDownloadUrl;
  final String? playStoreUrl;
  final String? publishedAt;

  bool get isMandatory =>
      updateRequired || forceUpdate || currentBuild < minimumSupportedBuild;

  Uri? get serverDownloadUri => _secureUri(serverDownloadUrl);
  Uri? get playStoreUri => _secureUri(playStoreUrl);

  /// Parses the existing `/app-upgrade` response envelope used by the Kotlin app.
  /// A null result means the server has no newer build for this installation.
  static AppUpdateInfo? fromApiResponse(
    Object? payload, {
    required int currentBuild,
  }) {
    final envelope = _stringMap(payload);
    final data = _stringMap(envelope['data']);
    if (data.isEmpty) {
      throw const FormatException(
        'Upgrade response did not contain a data object.',
      );
    }
    if (data['update_available'] != true) return null;

    final latest = _stringMap(data['latest']);
    if (latest.isEmpty) {
      throw const FormatException(
        'Upgrade response did not contain latest release details.',
      );
    }

    final buildNumber = _asInt(latest['build_number']) ?? 0;
    if (buildNumber <= currentBuild) return null;

    return AppUpdateInfo(
      currentBuild: currentBuild,
      updateRequired: data['update_required'] == true,
      versionName: _string(latest['version_name']) ?? 'Unknown version',
      buildNumber: buildNumber,
      minimumSupportedBuild:
          _asInt(latest['minimum_supported_build']) ?? 0,
      forceUpdate: latest['force_update'] == true,
      title: _string(latest['title']) ?? 'A new update is available',
      releaseNotes: _string(latest['release_notes']) ?? '',
      serverDownloadUrl: _string(latest['server_download_url']),
      playStoreUrl: _string(latest['play_store_url']),
      publishedAt: _string(latest['published_at']),
    );
  }

  Map<String, Object?> toJson() => {
        'current_build': currentBuild,
        'update_required': updateRequired,
        'version_name': versionName,
        'build_number': buildNumber,
        'minimum_supported_build': minimumSupportedBuild,
        'force_update': forceUpdate,
        'title': title,
        'release_notes': releaseNotes,
        'server_download_url': serverDownloadUrl,
        'play_store_url': playStoreUrl,
        'published_at': publishedAt,
      };

  factory AppUpdateInfo.fromJson(
    Map<String, Object?> json, {
    int? currentBuild,
  }) {
    return AppUpdateInfo(
      currentBuild: currentBuild ?? _asInt(json['current_build']) ?? 0,
      updateRequired: json['update_required'] == true,
      versionName: _string(json['version_name']) ?? 'Unknown version',
      buildNumber: _asInt(json['build_number']) ?? 0,
      minimumSupportedBuild: _asInt(json['minimum_supported_build']) ?? 0,
      forceUpdate: json['force_update'] == true,
      title: _string(json['title']) ?? 'A new update is available',
      releaseNotes: _string(json['release_notes']) ?? '',
      serverDownloadUrl: _string(json['server_download_url']),
      playStoreUrl: _string(json['play_store_url']),
      publishedAt: _string(json['published_at']),
    );
  }

  static Uri? _secureUri(String? value) {
    if (value == null) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }

  static Map<String, Object?> _stringMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static int? _asInt(Object? value) => switch (value) {
        int number => number,
        num number => number.toInt(),
        String text => int.tryParse(text),
        _ => null,
      };

  static String? _string(Object? value) {
    if (value is! String) return null;
    return value.trim().isEmpty ? null : value.trim();
  }
}
