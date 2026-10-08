import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/providers.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/app_update_info.dart';

class UpdatePage extends ConsumerStatefulWidget {
  const UpdatePage({super.key, this.initialUpdate});

  final AppUpdateInfo? initialUpdate;

  @override
  ConsumerState<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends ConsumerState<UpdatePage>
    with WidgetsBindingObserver {
  AppUpdateInfo? _update;
  bool _checking = false;
  bool _checked = false;
  bool _downloading = false;
  bool _awaitingInstallPermission = false;
  double? _downloadProgress;
  String? _downloadedApkPath;
  String? _error;
  CancelToken? _downloadToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _update = widget.initialUpdate;
    _checking = false;
    _checked = widget.initialUpdate != null;
    if (widget.initialUpdate == null) unawaited(_checkForUpdates());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _downloadToken?.cancel('Update screen closed.');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingInstallPermission) {
      unawaited(_continueInstallAfterPermission());
    }
  }

  Future<void> _checkForUpdates() async {
    if (_checking || _downloading) return;
    setState(() {
      _checking = true;
      _error = null;
      _downloadedApkPath = null;
    });
    try {
      final repository = ref.read(updateRepositoryProvider);
      final update = await repository.checkNow();
      if (update != null) await repository.markPrompted(update);
      if (!mounted) return;
      setState(() {
        _update = update;
        _checked = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checked = true;
        _error = 'Could not check for updates. Check your connection and retry.';
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _startUpdateAction() async {
    final update = _update;
    if (update == null || _downloading) return;
    if (_downloadedApkPath != null) {
      await _installDownloadedApk();
      return;
    }
    if (update.serverDownloadUri != null) {
      await _downloadUpdate(update);
      return;
    }
    await _openExternalUpdate(update);
  }

  Future<void> _downloadUpdate(AppUpdateInfo update) async {
    final uri = update.serverDownloadUri;
    if (uri == null) {
      await _openExternalUpdate(update);
      return;
    }

    final token = CancelToken();
    File? apkFile;
    setState(() {
      _downloading = true;
      _downloadProgress = null;
      _downloadToken = token;
      _error = null;
    });

    try {
      final nativeDirectory =
          await ref.read(nativePlatformBridgeProvider).updateDownloadDirectory();
      if (nativeDirectory == null || nativeDirectory.isEmpty) {
        throw StateError('Android update storage is unavailable.');
      }
      final updateDirectory = Directory(nativeDirectory);
      await updateDirectory.create(recursive: true);
      final safeVersion = update.versionName.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]'),
        '-',
      );
      final outputFile = File(
        path.join(
          updateDirectory.path,
          'nextel-${safeVersion.isEmpty ? update.buildNumber : safeVersion}.apk',
        ),
      );
      apkFile = outputFile;
      if (await outputFile.exists()) await outputFile.delete();

      final client = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(minutes: 2),
          sendTimeout: const Duration(seconds: 15),
          headers: const {
            'accept': 'application/vnd.android.package-archive, application/octet-stream',
          },
        ),
      );
      await client.download(
        uri.toString(),
        outputFile.path,
        cancelToken: token,
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _downloadProgress = total > 0
                ? (received / total).clamp(0.0, 1.0).toDouble()
                : null;
          });
        },
      );
      if (token.isCancelled) {
        await _deletePartialFile(outputFile);
        return;
      }
      if (!await outputFile.exists() || await outputFile.length() <= 0) {
        throw FileSystemException('The downloaded update file is empty.');
      }
      if (!mounted) return;
      setState(() {
        _downloadedApkPath = outputFile.path;
        _downloadProgress = 1;
      });
    } on DioException catch (error) {
      if (!CancelToken.isCancel(error) && mounted) {
        setState(() {
          _error = 'The update download failed. Please try again or use the store link.';
        });
      }
      if (apkFile != null) await _deletePartialFile(apkFile);
    } catch (_) {
      if (mounted && !token.isCancelled) {
        setState(() {
          _error = 'The update file could not be saved. Please try again.';
        });
      }
      if (apkFile != null) await _deletePartialFile(apkFile);
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _downloadToken = null;
        });
      }
    }
  }

  Future<void> _deletePartialFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A partial update is never treated as an installable APK.
    }
  }

  void _cancelDownload() {
    _downloadToken?.cancel('Download cancelled by user.');
  }

  Future<void> _installDownloadedApk() async {
    final apkPath = _downloadedApkPath;
    if (apkPath == null) return;
    final bridge = ref.read(nativePlatformBridgeProvider);

    try {
      if (!await bridge.canInstallApks()) {
        _awaitingInstallPermission = true;
        final opened = await bridge.requestInstallApkPermission();
        if (!opened && mounted) {
          _awaitingInstallPermission = false;
          _showMessage(
            'Android could not open the permission screen. Enable installs from Nextel in Settings.',
          );
        } else if (mounted) {
          _showMessage('Allow installs from Nextel, then return here to continue.');
        }
        return;
      }

      _awaitingInstallPermission = false;
      final opened = await bridge.installApk(apkPath);
      if (!opened && mounted) {
        _showMessage('The Android package installer could not be opened.');
      }
    } catch (_) {
      if (mounted) _showMessage('The update could not be opened for installation.');
    }
  }

  Future<void> _continueInstallAfterPermission() async {
    if (!_awaitingInstallPermission) return;
    final allowed = await ref.read(nativePlatformBridgeProvider).canInstallApks();
    if (!mounted) return;
    if (allowed) {
      _awaitingInstallPermission = false;
      await _installDownloadedApk();
    } else {
      _awaitingInstallPermission = false;
      _showMessage(
        'Install permission was not granted. Tap Install update to try again.',
      );
    }
  }

  Future<void> _openExternalUpdate(AppUpdateInfo update) async {
    final uri = update.playStoreUri ?? update.serverDownloadUri;
    if (uri == null) {
      _showMessage('No secure update link is available. Please contact support.');
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showMessage('Could not open the update page. Please try again.');
      }
    } catch (_) {
      if (mounted) _showMessage('Could not open the update page. Please try again.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.splash);
    }
  }

  String? _publishedDate(String? value) {
    if (value == null) return null;
    final date = DateTime.tryParse(value);
    if (date == null) return null;
    return DateFormat.yMMMd().format(date.toLocal());
  }

  List<String> _releaseNoteLines(String raw) => raw
      .split(RegExp(r'\r\n|\n|\r'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) => line.replaceFirst(RegExp(r'^([-*•]|\d+[.)])\s+'), ''))
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final colors = context.nextelColors;
    final update = _update;
    final mandatory = update?.isMandatory ?? false;
    final hasUpdateAction = update != null &&
        (update.serverDownloadUri != null || update.playStoreUri != null);
    final actionLabel = _downloadedApkPath != null
        ? 'Install update'
        : update?.serverDownloadUri != null
            ? 'Download update'
            : 'Open update page';

    return PopScope<Object?>(
      canPop: !mandatory,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          automaticallyImplyLeading: !mandatory,
          leading: mandatory
              ? null
              : IconButton(
                  tooltip: 'Back',
                  onPressed: _handleBack,
                  icon: const Icon(Icons.arrow_back),
                ),
          title: const Text('App update'),
          backgroundColor: colors.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
            children: [
              if (_checking && update == null) ...[
                const SizedBox(height: 56),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 20),
                const Center(child: Text('Checking for updates…')),
              ] else if (_error != null && update == null) ...[
                _statusCard(
                  context,
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not check for updates',
                  message: _error!,
                  tint: colors.danger,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _checking ? null : _checkForUpdates,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ] else if (update == null && _checked) ...[
                _statusCard(
                  context,
                  icon: Icons.check_circle_outline,
                  title: 'You’re up to date',
                  message:
                      'Nextel ${ref.read(appConfigProvider).versionName} is the latest version available for this device.',
                  tint: colors.primary,
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: _checking ? null : _checkForUpdates,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check again'),
                ),
              ] else if (update != null) ...[
                _updateDetails(context, update, mandatory),
                if (_downloading) ...[
                  const SizedBox(height: 18),
                  LinearProgressIndicator(value: _downloadProgress),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _downloadProgress == null
                              ? 'Downloading update…'
                              : 'Downloading update… ${(_downloadProgress! * 100).round()}%',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colors.muted,
                              ),
                        ),
                      ),
                      TextButton(
                        onPressed: _cancelDownload,
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _inlineError(context, _error!),
                ],
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _downloading || !hasUpdateAction
                      ? null
                      : _startUpdateAction,
                  icon: Icon(
                    _downloadedApkPath == null
                        ? Icons.download_rounded
                        : Icons.install_mobile_outlined,
                  ),
                  label: Text(_downloading ? 'Downloading…' : actionLabel),
                ),
                if (update.serverDownloadUri != null &&
                    update.playStoreUri != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _downloading
                        ? null
                        : () => _openExternalUpdate(update),
                    child: const Text('Open store instead'),
                  ),
                ],
                if (!mandatory) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _downloading ? null : _handleBack,
                    child: const Text('Not now'),
                  ),
                ],
              ],
              if (_awaitingInstallPermission && update != null) ...[
                const SizedBox(height: 12),
                _inlineNotice(
                  context,
                  'Allow installs from Nextel in Android settings, then return to this screen.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required Color tint,
  }) {
    final colors = context.nextelColors;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 54, color: tint),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }

  Widget _updateDetails(
    BuildContext context,
    AppUpdateInfo update,
    bool mandatory,
  ) {
    final colors = context.nextelColors;
    final notes = _releaseNoteLines(update.releaseNotes);
    final published = _publishedDate(update.publishedAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.system_update_alt,
                      color: colors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          update.title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: colors.text,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Version ${update.versionName} · build ${update.buildNumber}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: colors.muted),
                        ),
                        if (published != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Released $published',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colors.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (mandatory) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: colors.danger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.priority_high, color: colors.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This update is required to continue using Nextel.',
                          style: TextStyle(
                            color: colors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'What’s new',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
                ...notes.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check, size: 18, color: colors.primary),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            line,
                            style: TextStyle(color: colors.text, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Current build ${update.currentBuild}',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colors.muted),
        ),
      ],
    );
  }

  Widget _inlineError(BuildContext context, String message) {
    final colors = context.nextelColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.danger),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineNotice(BuildContext context, String message) {
    final colors = context.nextelColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colors.primary),
          const SizedBox(width: 9),
          Expanded(child: Text(message, style: TextStyle(color: colors.text))),
        ],
      ),
    );
  }
}
