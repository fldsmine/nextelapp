import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/errors/api_failure.dart';
import '../../domain/auth_validation.dart';
import '../widgets/auth_page_frame.dart';

class PasswordResetPage extends ConsumerStatefulWidget {
  const PasswordResetPage({super.key});

  @override
  ConsumerState<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends ConsumerState<PasswordResetPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _passwordVisible = false;
  String? _emailError;
  String? _codeError;
  String? _passwordError;
  String? _generalError;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    FocusScope.of(context).unfocus();
    final error = AuthValidation.resetEmail(_emailController.text);
    setState(() {
      _emailError = error;
      _generalError = null;
    });
    if (error != null) return;

    setState(() => _loading = true);
    try {
      final message = await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(_emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _generalError = failure.displayMessage);
    } catch (_) {
      if (mounted) {
        setState(() => _generalError = 'Could not request a reset code. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();
    final emailError = AuthValidation.resetEmail(_emailController.text);
    final codeError = AuthValidation.verificationCode(_codeController.text);
    final passwordError = AuthValidation.newPassword(_passwordController.text);
    setState(() {
      _emailError = emailError;
      _codeError = codeError;
      _passwordError = passwordError;
      _generalError = null;
    });
    if (emailError != null || codeError != null || passwordError != null) return;

    setState(() => _loading = true);
    try {
      final message = await ref.read(authRepositoryProvider).resetPassword(
            email: _emailController.text.trim(),
            code: _codeController.text.trim(),
            password: _passwordController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      context.go(AppRoutes.login, extra: _emailController.text.trim());
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() {
          _emailError = failure.firstFieldError('email');
          _codeError = failure.firstFieldError('code');
          _passwordError = failure.firstFieldError('password');
          _generalError = failure.displayMessage;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _generalError = 'Could not reset the password. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      title: 'Password reset',
      subtitle: 'Request a 6-digit reset code using your email address.',
      backAction: () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _emailController,
            enabled: !_loading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Email address',
              prefixIcon: const Icon(Icons.alternate_email),
              errorText: _emailError,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  enabled: !_loading,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: '6-digit reset code',
                    prefixIcon: const Icon(Icons.password),
                    errorText: _codeError,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _loading ? null : _requestCode,
                child: const Text('Send code'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            enabled: !_loading,
            obscureText: !_passwordVisible,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: const Icon(Icons.lock_outline),
              errorText: _passwordError,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                icon: Icon(
                  _passwordVisible ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          if (_generalError != null) ...[
            const SizedBox(height: 10),
            Text(_generalError!, style: TextStyle(color: context.nextelColors.danger)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _resetPassword,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Reset password'),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _loading ? null : () => context.go(AppRoutes.register),
              child: const Text('Create account'),
            ),
          ),
        ],
      ),
    );
  }
}
