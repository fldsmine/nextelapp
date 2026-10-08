import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/errors/api_failure.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_validation.dart';
import '../widgets/auth_page_frame.dart';
import 'suspended_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({this.prefillLogin = '', super.key});

  final String prefillLogin;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = true;
  bool _passwordVisible = false;
  bool _biometricAvailable = false;
  bool _loading = false;
  String? _loginError;
  String? _passwordError;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    _loginController.text = widget.prefillLogin;
    _rememberMe = ref.read(sessionStoreProvider).rememberMe;
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final session = ref.read(sessionStoreProvider);
      if (!session.biometricEnabled || !session.rememberMe) return;
      final token = await session.readToken();
      if (token == null || token.isEmpty || !mounted) return;
      final canAuthenticate = await ref
          .read(nativePlatformBridgeProvider)
          .canAuthenticateWithStrongBiometrics();
      if (mounted) {
        setState(
          () => _biometricAvailable =
              canAuthenticate &&
              _rememberMe &&
              session.biometricEnabled &&
              session.rememberMe,
        );
      }
    } catch (_) {
      // Devices without supported strong biometrics simply hide the shortcut.
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final login = _loginController.text.trim();
    final password = _passwordController.text;
    final loginError = AuthValidation.login(login);
    final passwordError = AuthValidation.loginPassword(password);
    setState(() {
      _loginError = loginError;
      _passwordError = passwordError;
      _generalError = null;
    });
    if (loginError != null || passwordError != null) return;

    setState(() => _loading = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      final result = await repository.login(
        login: login,
        password: password,
        rememberMe: _rememberMe,
      );
      await repository.retryQueuedRevocations();
      if (!mounted) return;
      await _continueAfterAuthentication(result);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      if (failure.statusCode == 403) {
        await _showSuspended(
          failure.message,
          failure.dataMap['support_token']?.toString(),
          serverRevoked: false,
        );
      } else if (mounted) {
        setState(() {
          _loginError = failure.firstFieldError('login');
          _passwordError = failure.firstFieldError('password');
          if (_loginError == null && _passwordError == null) {
            _generalError = failure.displayMessage;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _generalError = 'Unable to complete sign in. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueAfterAuthentication(AuthResult result) async {
    final repository = ref.read(authRepositoryProvider);
    if (result.user.isSuspended) {
      await _showSuspended(
        'This account has been suspended. Please contact support.',
        null,
        serverRevoked: false,
      );
      return;
    }
    if (result.verificationRequired) {
      if (mounted) context.go(AppRoutes.verify, extra: result.user.email);
      return;
    }

    try {
      final webSession = await repository.openWebSession();
      if (mounted) context.go(AppRoutes.dashboard, extra: webSession.destination);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      if (failure.statusCode == 403) {
        await _showSuspended(
          failure.message,
          failure.dataMap['support_token']?.toString(),
          serverRevoked: true,
        );
      } else if (mounted) {
        setState(() => _generalError = failure.displayMessage);
      }
    }
  }

  Future<void> _showSuspended(
    String message,
    String? supportToken, {
    required bool serverRevoked,
  }) async {
    await ref.read(authRepositoryProvider).handleSuspended(
          serverRevokedCurrentToken: serverRevoked,
        );
    if (!mounted) return;
    context.go(
      AppRoutes.suspended,
      extra: SuspendedRouteDetails(
        message: message,
        supportToken: supportToken,
      ),
    );
  }

  Future<void> _biometricLogin() async {
    if (_loading || !_biometricAvailable) return;
    final session = ref.read(sessionStoreProvider);
    if (!session.biometricEnabled || !session.rememberMe) {
      setState(() => _biometricAvailable = false);
      return;
    }
    setState(() => _generalError = null);
    try {
      final bridge = ref.read(nativePlatformBridgeProvider);
      if (!await bridge.canAuthenticateWithStrongBiometrics()) {
        if (mounted) setState(() => _biometricAvailable = false);
        return;
      }
      final authenticated = await bridge.authenticateWithStrongBiometrics(
        title: 'Biometric sign-in',
        subtitle: 'Confirm your identity to continue',
      );
      if (!authenticated || !mounted) return;
      setState(() => _loading = true);
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.validateStoredSession();
      if (!mounted) return;
      if (user == null) {
        setState(() => _generalError = 'Please sign in again to continue.');
        return;
      }
      await _continueAfterAuthentication(
        AuthResult(user: user, verificationRequired: !user.emailVerified),
      );
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      if (failure.statusCode == 403) {
        await _showSuspended(
          failure.message,
          failure.dataMap['support_token']?.toString(),
          serverRevoked: failure.dataMap['support_token']?.toString().isNotEmpty == true,
        );
      } else if (mounted) {
        setState(() => _generalError = failure.displayMessage);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _generalError = 'Biometric sign in was not completed.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      title: 'Welcome Back',
      subtitle: 'Login to continue to your Nextel account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _loginController,
            enabled: !_loading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            decoration: InputDecoration(
              labelText: 'Email or username',
              hintText: 'Email or username',
              prefixIcon: const Icon(Icons.person_outline),
              errorText: _loginError,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            enabled: !_loading,
            obscureText: !_passwordVisible,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter password',
              prefixIcon: const Icon(Icons.lock_outline),
              errorText: _passwordError,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                tooltip: _passwordVisible ? 'Hide password' : 'Show password',
                icon: Icon(
                  _passwordVisible ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Checkbox.adaptive(
                value: _rememberMe,
                activeColor: context.nextelColors.primary,
                onChanged: _loading
                    ? null
                    : (value) async {
                        final next = value ?? false;
                        setState(() {
                          _rememberMe = next;
                          if (!next) _biometricAvailable = false;
                        });
                        await ref.read(sessionStoreProvider).setRememberMe(next);
                        if (next && mounted) _checkBiometricAvailability();
                      },
              ),
              Expanded(
                child: Text('Remember Me', style: TextStyle(color: context.nextelColors.muted)),
              ),
              TextButton(
                onPressed: _loading ? null : () => context.push(AppRoutes.reset),
                child: const Text('Forgot Password?'),
              ),
            ],
          ),
          if (_generalError != null) ...[
            const SizedBox(height: 4),
            _InlineError(message: _generalError!),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: _biometricAvailable ? 5 : 1,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Login'),
                ),
              ),
              if (_biometricAvailable) ...[
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _biometricLogin,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Biometric'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Don\'t have an account? '),
                TextButton(
                  onPressed: _loading ? null : () => context.push(AppRoutes.register),
                  child: const Text('Create account'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x14FF3B30),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          message,
          style: TextStyle(color: context.nextelColors.danger),
        ),
      );
}
