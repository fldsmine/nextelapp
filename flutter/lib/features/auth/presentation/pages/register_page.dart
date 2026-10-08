import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/errors/api_failure.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_validation.dart';
import '../../domain/country.dart';
import '../../domain/country_calling_codes.dart';
import '../widgets/auth_page_frame.dart';
import 'suspended_page.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _referralController = TextEditingController();
  final _passwordController = TextEditingController();
  final _termsTapRecognizer = TapGestureRecognizer();
  final _privacyTapRecognizer = TapGestureRecognizer();

  List<Country> _countries = const [];
  Country _selectedCountry = localCountryDialCodes.firstWhere(
    (country) => country.code == 'NG',
  );
  final Map<String, String> _fieldErrors = {};
  bool _acceptedTerms = false;
  bool _countriesLoading = false;
  bool _loading = false;
  bool _passwordVisible = false;
  String? _countryLoadError;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    _termsTapRecognizer.onTap = () => context.push(AppRoutes.terms);
    _privacyTapRecognizer.onTap = () => context.push(AppRoutes.privacy);
    _loadCountries();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _referralController.dispose();
    _passwordController.dispose();
    _termsTapRecognizer.dispose();
    _privacyTapRecognizer.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    if (_countriesLoading) return;
    setState(() {
      _countriesLoading = true;
      _countryLoadError = null;
    });
    try {
      final countries = await ref.read(authRepositoryProvider).fetchCountries();
      if (!mounted) return;
      setState(() {
        _countries = countries;
        _selectedCountry = countries.firstWhere(
          (country) => country.code == 'NG',
          orElse: () => countries.isEmpty ? _selectedCountry : countries.first,
        );
        _countriesLoading = false;
        if (countries.isEmpty) {
          _countryLoadError =
              'No supported countries are currently available. Tap to retry.';
        }
      });
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() {
          _countriesLoading = false;
          _countryLoadError = failure.displayMessage;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _countriesLoading = false;
          _countryLoadError = 'Could not load the supported countries. Tap to retry.';
        });
      }
    }
  }

  Future<void> _chooseCountry() async {
    if (_countries.isEmpty) {
      await _loadCountries();
      return;
    }
    final searchController = TextEditingController();
    final selected = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final query = searchController.text.trim().toLowerCase();
          final visibleCountries = _countries.where((country) {
            return country.name.toLowerCase().contains(query) ||
                country.code.toLowerCase().contains(query) ||
                country.dialCode.contains(query);
          }).toList(growable: false);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.78,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      onChanged: (_) => setModalState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search country',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  Expanded(
                    child: visibleCountries.isEmpty
                        ? const Center(child: Text('No matching countries'))
                        : ListView.separated(
                            itemCount: visibleCountries.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final country = visibleCountries[index];
                              return ListTile(
                                leading: Text(
                                  country.flag.isEmpty ? '🌐' : country.flag,
                                  style: const TextStyle(fontSize: 24),
                                ),
                                title: Text(country.name),
                                subtitle: Text(country.code),
                                trailing: Text(country.dialCode),
                                onTap: () => Navigator.of(context).pop(country),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    searchController.dispose();
    if (selected != null && mounted) {
      setState(() {
        _selectedCountry = selected;
        _fieldErrors.remove('country');
        _fieldErrors.remove('phone');
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final errors = AuthValidation.registration(
      fullName: _nameController.text,
      username: _usernameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
      acceptedTerms: _acceptedTerms,
      selectedCountry: _selectedCountry,
      availableCountries: _countries,
    );
    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(errors);
      _generalError = null;
    });
    if (errors.isNotEmpty) {
      if (_countries.isEmpty && !_countriesLoading) await _loadCountries();
      return;
    }

    setState(() => _loading = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      final result = await repository.register(
        fullName: _nameController.text,
        username: _usernameController.text,
        email: _emailController.text,
        phone: AuthValidation.phoneForApi(
          _phoneController.text,
          _selectedCountry,
        ),
        country: _selectedCountry,
        password: _passwordController.text,
        referralCode: _referralController.text,
      );
      await repository.retryQueuedRevocations();
      if (!mounted) return;
      if (result.user.isSuspended) {
        await repository.handleSuspended(serverRevokedCurrentToken: false);
        if (mounted) {
          ref.read(currentUserProvider.notifier).state = null;
          context.go(
            AppRoutes.suspended,
            extra: const SuspendedRouteDetails(
              message: 'This account has been suspended. Please contact support.',
            ),
          );
        }
        return;
      }
      ref.read(currentUserProvider.notifier).state = result.user;
      if (result.verificationRequired) {
        context.go(AppRoutes.verify, extra: result.user.email);
        return;
      }
      final webSession = await repository.openWebSession();
      if (mounted) {
        context.go(AppRoutes.dashboard, extra: webSession.destination);
      }
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      if (failure.statusCode == 403) {
        final repository = ref.read(authRepositoryProvider);
        await repository.handleSuspended(serverRevokedCurrentToken: false);
        if (mounted) {
          context.go(
            AppRoutes.suspended,
            extra: SuspendedRouteDetails(
              message: failure.message,
              supportToken: failure.dataMap['support_token']?.toString(),
            ),
          );
        }
      } else if (mounted) {
        setState(() {
          for (final field in const [
            'full_name',
            'username',
            'email',
            'phone',
            'password',
          ]) {
            final error = failure.firstFieldError(field);
            if (error != null) _fieldErrors[field] = error;
          }
          _generalError = _fieldErrors.isEmpty || failure.statusCode == 429
              ? failure.displayMessage
              : null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _generalError = 'Unable to complete registration. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      title: 'Create Account',
      subtitle: 'Join Nextel Connect and get started today',
      backAction: () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            controller: _nameController,
            label: 'Full name',
            hint: 'Your name',
            icon: Icons.person_outline,
            error: _fieldErrors['full_name'],
            action: TextInputAction.next,
          ),
          const SizedBox(height: 15),
          _field(
            controller: _emailController,
            label: 'Email',
            hint: 'Enter your email address',
            icon: Icons.alternate_email,
            keyboardType: TextInputType.emailAddress,
            error: _fieldErrors['email'],
            action: TextInputAction.next,
          ),
          const SizedBox(height: 15),
          _field(
            controller: _usernameController,
            label: 'Username',
            hint: 'Choose preferred username',
            icon: Icons.account_circle_outlined,
            error: _fieldErrors['username'],
            action: TextInputAction.next,
          ),
          const SizedBox(height: 15),
          Text('Country', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          InkWell(
            onTap: _loading ? null : _chooseCountry,
            borderRadius: BorderRadius.circular(13),
            child: InputDecorator(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.public),
                suffixIcon: _countriesLoading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.arrow_drop_down),
                errorText: _fieldErrors['country'] ?? _countryLoadError,
              ),
              child: Text(
                '${_selectedCountry.flag}  ${_selectedCountry.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (_countryLoadError != null && _countries.isEmpty) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _countriesLoading ? null : _loadCountries,
                child: const Text('Retry'),
              ),
            ),
          ],
          const SizedBox(height: 15),
          Text('Phone number', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: context.nextelColors.border),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(13),
                  ),
                ),
                child: Text(
                  _selectedCountry.dialCode,
                  style: TextStyle(
                    color: context.nextelColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  enabled: !_loading,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Phone number',
                    errorText: _fieldErrors['phone'],
                    prefixIcon: const Icon(Icons.call_outlined),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(13),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _field(
            controller: _referralController,
            label: 'Promo code (optional)',
            hint: 'Enter referral code',
            icon: Icons.sell_outlined,
            action: TextInputAction.next,
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _passwordController,
            enabled: !_loading,
            obscureText: !_passwordVisible,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'At least 8 characters',
              prefixIcon: const Icon(Icons.lock_outline),
              errorText: _fieldErrors['password'],
              suffixIcon: IconButton(
                onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                icon: Icon(
                  _passwordVisible ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox.adaptive(
                value: _acceptedTerms,
                onChanged: _loading
                    ? null
                    : (value) => setState(() {
                          _acceptedTerms = value ?? false;
                          _fieldErrors.remove('terms');
                        }),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms & Conditions',
                          recognizer: _termsTapRecognizer,
                          style: TextStyle(
                            color: context.nextelColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          recognizer: _privacyTapRecognizer,
                          style: TextStyle(
                            color: context.nextelColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_fieldErrors['terms'] != null)
            Text(
              _fieldErrors['terms']!,
              style: TextStyle(color: context.nextelColors.danger),
            ),
          if (_generalError != null) ...[
            const SizedBox(height: 10),
            Text(
              _generalError!,
              style: TextStyle(color: context.nextelColors.danger),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _loading || _countriesLoading || _countries.isEmpty
                ? null
                : _submit,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create account'),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _loading ? null : () => context.go(AppRoutes.login),
              child: const Text('Already have an account? Login'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? error,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction action = TextInputAction.next,
  }) =>
      TextField(
        controller: controller,
        enabled: !_loading,
        keyboardType: keyboardType,
        textInputAction: action,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          errorText: error,
        ),
      );
}
