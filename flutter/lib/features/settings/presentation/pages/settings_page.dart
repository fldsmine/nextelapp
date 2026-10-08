import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../app/providers.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/app_settings.dart';
import '../providers/app_settings_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _biometricBusy = false;
  bool _notificationBusy = false;
  bool _reminderBusy = false;
  bool _logoutBusy = false;
  bool? _notificationPermissionGranted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(appSettingsProvider.notifier).synchronizeBiometricState(),
      );
      unawaited(_refreshNotificationPermission());
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refreshNotificationPermission() async {
    final granted = await ref
        .read(nativePlatformBridgeProvider)
        .notificationPermissionGranted();
    if (mounted) setState(() => _notificationPermissionGranted = granted);
  }

  Future<void> _requestNotificationPermission() async {
    setState(() => _notificationBusy = true);
    try {
      final granted = await ref
          .read(nativePlatformBridgeProvider)
          .requestNotificationPermission();
      if (!mounted) return;
      setState(() => _notificationPermissionGranted = granted);
      if (!granted) {
        _showMessage('Notification permission was not granted.');
      } else {
        if (!ref.read(appSettingsProvider).notificationsEnabled) {
          await ref
              .read(appSettingsProvider.notifier)
              .setNotificationsEnabled(true);
        }
        _showMessage('Notifications are allowed on this device.');
      }
    } catch (_) {
      _showMessage('Could not request notification permission. Please retry.');
    } finally {
      if (mounted) setState(() => _notificationBusy = false);
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.dashboard);
    }
  }

  Future<void> _setNotifications(bool enabled) async {
    setState(() => _notificationBusy = true);
    try {
      final saved = await ref
          .read(appSettingsProvider.notifier)
          .setNotificationsEnabled(enabled);
      if (!mounted) return;
      if (enabled) {
        if (!saved) {
          _showMessage(
            'Notification permission was not granted. You can enable it in Android settings.',
          );
        }
        if (mounted) {
          setState(() => _notificationPermissionGranted = saved);
        }
      } else {
        await _refreshNotificationPermission();
      }
    } catch (_) {
      _showMessage('Could not update notification settings. Please retry.');
    } finally {
      if (mounted) setState(() => _notificationBusy = false);
    }
  }

  Future<void> _setDailyReminder(bool enabled) async {
    setState(() => _reminderBusy = true);
    try {
      final saved = await ref
          .read(appSettingsProvider.notifier)
          .setDailyReminder(enabled);
      if (!mounted) return;
      if (!saved) {
        _showMessage(
          'Android notification or exact-alarm access is unavailable. Allow it, then try again.',
        );
      }
    } catch (_) {
      _showMessage('Could not update the daily reminder. Please retry.');
    } finally {
      if (mounted) setState(() => _reminderBusy = false);
    }
  }

  Future<void> _setBiometric(bool enabled) async {
    if (!enabled) {
      try {
        await ref
            .read(appSettingsProvider.notifier)
            .setBiometricEnabled(false);
      } catch (_) {
        _showMessage('Could not turn off biometric login. Please retry.');
      }
      return;
    }

    setState(() => _biometricBusy = true);
    try {
      final sessionStore = ref.read(sessionStoreProvider);
      final token = await sessionStore.readToken();
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        _showMessage('Sign in again before enabling biometric login.');
        return;
      }

      final authentication = LocalAuthentication();
      final deviceSupported = await authentication.isDeviceSupported();
      final canCheckBiometrics = deviceSupported
          ? await authentication.canCheckBiometrics
          : false;
      if (!mounted) return;
      if (!canCheckBiometrics) {
        _showMessage('Strong biometrics are not available on this device.');
        return;
      }
      final authenticated = await authentication.authenticate(
        localizedReason: 'Enable biometric login for your Nextel account',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (!mounted || !authenticated) return;

      // Biometrics may only protect a token that survives a process restart.
      await sessionStore.saveToken(token, remember: true);
      if (!mounted) return;
      await ref
          .read(appSettingsProvider.notifier)
          .setBiometricEnabled(true);
      _showMessage('Biometric login enabled.');
    } catch (_) {
      _showMessage(
        'Could not enable biometric login. Check that a strong biometric is enrolled and try again.',
      );
    } finally {
      if (mounted) setState(() => _biometricBusy = false);
    }
  }

  Future<void> _openSupport() async {
    final token = await ref.read(sessionStoreProvider).readToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      context.go(AppRoutes.login);
      return;
    }
    await context.push(AppRoutes.support, extra: token);
  }

  Future<void> _openCoupon() async {
    await context.push(AppRoutes.coupon);
  }

  Future<void> _confirmLogout() async {
    if (_logoutBusy) return;
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Log out'),
            content: const Text('Are you sure you want to log out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Log out'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldLogout || !mounted) return;

    setState(() => _logoutBusy = true);
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {
      // Local token and website storage are cleared before best-effort revoke.
    } finally {
      if (mounted) context.go(AppRoutes.login);
    }
  }

  Future<void> _confirmAccountDeletion() async {
    final contactSupport = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Account deletion'),
            content: const Text(
              'Account deletion is not available here. Please contact Nextel support for help.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Contact support'),
              ),
            ],
          ),
        ) ??
        false;
    if (contactSupport && mounted) await _openSupport();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final colors = context.nextelColors;
    final fontScale = settings.fontScale
        .clamp(AppSettings.minFontScale, AppSettings.maxFontScale)
        .toDouble();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('App settings'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _handleBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
          children: [
            Text(
              'Make Nextel yours',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Manage appearance, reminders, security and account shortcuts.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: colors.muted),
            ),
            const SizedBox(height: 22),
            _sectionCard(
              context,
              title: 'Appearance',
              icon: Icons.palette_outlined,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                    'Theme style',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppSettings.themes.map((theme) {
                      final selected = settings.theme == theme;
                      return ChoiceChip(
                        label: Text(theme),
                        selected: selected,
                        onSelected: (_) => controller.setTheme(theme),
                        selectedColor: colors.primary,
                        labelStyle: TextStyle(
                          color: selected
                              ? Theme.of(context).colorScheme.onPrimary
                              : colors.text,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('Font family'),
                  subtitle: const Text('Choose a typeface for the app'),
                  trailing: DropdownButton<String>(
                    value: settings.fontFamily,
                    underline: const SizedBox.shrink(),
                    onChanged: (value) {
                      if (value != null) controller.setFontFamily(value);
                    },
                    items: AppSettings.fontFamilies
                        .map(
                          (font) => DropdownMenuItem(
                            value: font,
                            child: Text(font),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('Font size')),
                          Text('${(fontScale * 100).round()}%'),
                        ],
                      ),
                      Slider(
                        min: AppSettings.minFontScale,
                        max: AppSettings.maxFontScale,
                        divisions: 28,
                        value: fontScale,
                        label: '${(fontScale * 100).round()}%',
                        onChanged: controller.setFontScale,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _sectionCard(
              context,
              title: 'Notifications',
              icon: Icons.notifications_outlined,
              children: [
                if (_notificationPermissionGranted == false)
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    leading: Icon(
                      Icons.info_outline,
                      color: context.nextelColors.danger,
                    ),
                    title: const Text('Allow device notifications'),
                    subtitle: const Text(
                      'Android permission is required to show notifications',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _notificationBusy
                        ? null
                        : _requestNotificationPermission,
                  ),
                _switchTile(
                  context,
                  title: 'Enable notifications',
                  subtitle: 'Allow Nextel notifications on this device',
                  value: settings.notificationsEnabled,
                  enabled: !_notificationBusy,
                  onChanged: _setNotifications,
                ),
                const Divider(height: 1),
                _switchTile(
                  context,
                  title: 'Notification sound',
                  subtitle: 'Play a sound for reminders',
                  value: settings.notificationSound,
                  onChanged: (value) =>
                      controller.setNotificationSound(value),
                ),
                const Divider(height: 1),
                _switchTile(
                  context,
                  title: 'Vibration',
                  subtitle: 'Vibrate for reminders',
                  value: settings.notificationVibration,
                  onChanged: (value) =>
                      controller.setNotificationVibration(value),
                ),
                const Divider(height: 1),
                _switchTile(
                  context,
                  title: 'Daily reminder',
                  subtitle:
                      'Get reminders at 8:00, 15:00 and 19:07 (Africa/Lagos)',
                  value: settings.dailyReminder,
                  enabled: !_reminderBusy,
                  onChanged: _setDailyReminder,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _sectionCard(
              context,
              title: 'Security',
              icon: Icons.fingerprint,
              children: [
                _switchTile(
                  context,
                  title: 'Biometric login',
                  subtitle: 'Use fingerprint or face unlock',
                  value: settings.biometricEnabled,
                  enabled: !_biometricBusy,
                  onChanged: _setBiometric,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _sectionCard(
              context,
              title: 'Quick actions',
              icon: Icons.grid_view_rounded,
              children: [
                _actionTile(
                  context,
                  icon: Icons.local_offer_outlined,
                  title: 'Check coupon',
                  subtitle: 'Verify a vendor coupon code',
                  onTap: _openCoupon,
                ),
                const Divider(height: 1),
                _actionTile(
                  context,
                  icon: Icons.support_agent_outlined,
                  title: 'Online chat',
                  subtitle: 'Chat with Nextel support',
                  onTap: _openSupport,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _sectionCard(
              context,
              title: 'Account',
              icon: Icons.manage_accounts_outlined,
              children: [
                _actionTile(
                  context,
                  icon: Icons.logout,
                  title: 'Log out',
                  subtitle: 'Close the current user session',
                  onTap: _logoutBusy ? null : _confirmLogout,
                ),
                const Divider(height: 1),
                _actionTile(
                  context,
                  icon: Icons.delete_outline,
                  title: 'Delete account',
                  subtitle: 'Contact support to disable your account',
                  color: colors.danger,
                  onTap: _confirmAccountDeletion,
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'Your preferences are saved on this device.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.muted,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colors = context.nextelColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _switchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) =>
      SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: enabled ? onChanged : null,
        activeTrackColor: context.nextelColors.primaryLight,
      );

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Color? color,
  }) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Icon(icon, color: color ?? context.nextelColors.primary),
        title: Text(title, style: TextStyle(color: color)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right, color: color ?? context.nextelColors.muted),
        onTap: onTap,
      );
}
