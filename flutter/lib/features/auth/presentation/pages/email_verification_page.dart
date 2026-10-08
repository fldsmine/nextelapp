import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/errors/api_failure.dart';
import '../../domain/auth_validation.dart';
import '../widgets/auth_page_frame.dart';
import 'suspended_page.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({required this.email, super.key});

  final String email;

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _codeError;
  String? _generalError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    final validation = AuthValidation.verificationCode(_codeController.text);
    setState(() {
      _codeError = validation;
      _generalError = null;
    });
    if (validation != null) return;

    setState(() => _loading = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.verifyEmail(_codeController.text.trim());
      final webSession = await repository.openWebSession();
      if (mounted) context.go(AppRoutes.dashboard, extra: webSession.destination);
    } on ApiFailure catch (failure) {
      if (failure.statusCode == 401) {
        await ref.read(authRepositoryProvider).handleExpiredSession();
        if (mounted) context.go(AppRoutes.login);
      } else if (failure.statusCode == 403) {
        await _routeToSuspended(failure);
      } else if (mounted) {
        setState(() {
          _codeError = failure.firstFieldError('code');
          _generalError = _codeError == null ? failure.displayMessage : null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _generalError = 'Could not verify the email. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _loading = true;
      _generalError = null;
    });
    try {
      final message = await ref.read(authRepositoryProvider).resendVerificationCode();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } on ApiFailure catch (failure) {
      if (failure.statusCode == 401) {
        await ref.read(authRepositoryProvider).handleExpiredSession();
        if (mounted) context.go(AppRoutes.login);
      } else if (failure.statusCode == 403) {
        await _routeToSuspended(failure);
      } else if (mounted) {
        setState(() => _generalError = failure.displayMessage);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _generalError = 'Could not resend the verification code.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _routeToSuspended(ApiFailure failure) async {
    final supportToken = failure.dataMap['support_token']?.toString();
    await ref.read(authRepositoryProvider).handleSuspended(
          serverRevokedCurrentToken: supportToken?.isNotEmpty == true,
        );
    if (!mounted) return;
    context.go(
      AppRoutes.suspended,
      extra: SuspendedRouteDetails(
        message: failure.message,
        supportToken: supportToken,
      ),
    );
  }

  Future<void> _useAnotherAccount() async {
    if (_loading) return;
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Use another account?'),
            content: const Text(
              'Your current unverified session will be signed out.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldLogout || !mounted) return;

    setState(() {
      _loading = true;
      _generalError = null;
    });
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {
      // The repository clears the in-memory token before best-effort network
      // revocation. Never leave an unverified token on the verification route.
    }
    if (mounted) context.go(AppRoutes.login);
  }

  void _handleSystemBack(bool didPop) {
    if (!didPop && !_loading) unawaited(_useAnotherAccount());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handleSystemBack(didPop),
      child: AuthPageFrame(
        title: 'Verify your email',
        subtitle: widget.email.isEmpty
            ? 'Enter the 6-digit code sent to your email address.'
            : 'Enter the 6-digit code sent to ${widget.email}.',
        backAction: _loading ? null : _useAnotherAccount,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _codeController,
              enabled: !_loading,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 6,
              onSubmitted: (_) => _verify(),
              decoration: InputDecoration(
                labelText: 'Verification code',
                hintText: '6-digit verification code',
                prefixIcon: const Icon(Icons.mark_email_read_outlined),
                errorText: _codeError,
                counterText: '',
              ),
            ),
            if (_generalError != null) ...[
              const SizedBox(height: 8),
              Text(
                _generalError!,
                style: TextStyle(color: context.nextelColors.danger),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _loading ? null : _verify,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify email'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading ? null : _resend,
              child: const Text('Resend code'),
            ),
            TextButton(
              onPressed: _loading ? null : _useAnotherAccount,
              child: const Text('Use another account'),
            ),
          ],
        ),
      ),
    );
  }
}
