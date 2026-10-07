import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/errors/api_failure.dart';
import '../../data/coupon_repository.dart';
import '../../domain/coupon_data.dart';
import '../../domain/coupon_validation.dart';

class CouponSearchPage extends ConsumerStatefulWidget {
  const CouponSearchPage({super.key});

  @override
  ConsumerState<CouponSearchPage> createState() => _CouponSearchPageState();
}

class _CouponSearchPageState extends ConsumerState<CouponSearchPage> {
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  bool _loading = false;
  String? _fieldError;
  String? _requestError;
  CouponData? _coupon;

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _verifyCoupon() async {
    FocusScope.of(context).unfocus();
    final code = _codeController.text.trim();
    final validationError = CouponValidation.codeError(code);
    if (validationError != null) {
      setState(() {
        _fieldError = validationError;
        _requestError = null;
        _coupon = null;
      });
      _codeFocusNode.requestFocus();
      return;
    }

    setState(() {
      _loading = true;
      _fieldError = null;
      _requestError = null;
      _coupon = null;
    });
    try {
      final coupon = await ref.read(couponRepositoryProvider).verifyCode(code);
      if (!mounted) return;
      setState(() => _coupon = coupon);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      final fieldMessage = failure.firstFieldError('code');
      setState(() {
        _requestError = fieldMessage ??
            (failure.displayMessage.trim().isEmpty
                ? 'Coupon was not found.'
                : failure.displayMessage);
      });
    } catch (_) {
      if (mounted) setState(() => _requestError = 'Could not verify this coupon. Please retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _display(String? value) =>
      value == null || value.trim().isEmpty ? '-' : value;

  String _region(String? value) {
    switch (value?.toLowerCase()) {
      case 'nigeria':
        return 'Nigeria';
      case 'foreign':
        return 'Foreign';
      case null:
      case '':
        return '-';
      default:
        final text = value!;
        return '${text[0].toUpperCase()}${text.substring(1)}';
    }
  }

  String _formatDate(String? value) {
    if (value == null || value.trim().isEmpty) return '-';
    var normalized = value;
    if (normalized.endsWith('Z')) {
      normalized = '${normalized.substring(0, normalized.length - 1)}+00:00';
    }
    normalized = normalized.replaceFirstMapped(
      RegExp(r'([+-]\d{2})(\d{2})$'),
      (match) => '${match[1]}:${match[2]}',
    );
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: NextelPalette.background,
        appBar: AppBar(
          backgroundColor: NextelPalette.primary,
          foregroundColor: Colors.white,
          title: const Text('Coupon verification'),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Verify your coupon',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter a coupon code below to check its validity and view the coupon details.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: NextelPalette.muted,
                      ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Coupon code',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _codeController,
                  focusNode: _codeFocusNode,
                  enabled: !_loading,
                  maxLength: CouponValidation.maxCodeLength,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  enableSuggestions: false,
                  onSubmitted: (_) => _verifyCoupon(),
                  onChanged: (_) {
                    setState(() => _fieldError = null);
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter coupon code',
                    counterText: '',
                    errorText: _fieldError,
                    suffixIcon: _codeController.text.isEmpty || _loading
                        ? null
                        : IconButton(
                            tooltip: 'Clear coupon code',
                            onPressed: () {
                              _codeController.clear();
                              setState(() {
                                _fieldError = null;
                                _requestError = null;
                                _coupon = null;
                              });
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _loading ? null : _verifyCoupon,
                  child: _loading
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text('Checking…'),
                          ],
                        )
                      : const Text('Verify coupon'),
                ),
                if (_requestError != null) ...[
                  const SizedBox(height: 24),
                  _buildErrorCard(_requestError!),
                ],
                if (_coupon != null) ...[
                  const SizedBox(height: 24),
                  _buildCouponResult(_coupon!),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _buildErrorCard(String message) => Container(
        decoration: BoxDecoration(
          color: NextelPalette.danger.withValues(alpha: .08),
          border: Border.all(color: NextelPalette.danger.withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Coupon not found',
              style: TextStyle(
                color: NextelPalette.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(message, style: const TextStyle(color: NextelPalette.danger)),
          ],
        ),
      );

  Widget _buildCouponResult(CouponData coupon) {
    final valid = coupon.isValid;
    final accent = valid ? NextelPalette.primary : NextelPalette.danger;
    final verificationMessage = coupon.verification?.message;
    final product = coupon.product;
    final batch = coupon.batch;
    final agent = coupon.agent;
    final redeemer = coupon.redeemer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .08),
            border: Border.all(color: accent.withValues(alpha: .35)),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                valid ? '✓' : '✕',
                style: TextStyle(
                  color: accent,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                valid ? 'VALID COUPON' : 'COUPON USED',
                style: TextStyle(
                  color: accent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                verificationMessage ??
                    (valid
                        ? 'This coupon is available for redemption.'
                        : 'This coupon has already been redeemed.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: NextelPalette.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  coupon.code ?? '',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Coupon details',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        _detailsCard([
          _detailRow('Coupon code', _display(coupon.code), bold: true),
          _detailRow('Coupon type', _display(coupon.typeName ?? coupon.type)),
          _detailRow('Status', _display(coupon.status), valueColor: accent),
          _detailRow('Price', _display(coupon.price)),
          _detailRow('Region', _region(coupon.region)),
          _detailRow('Special coupon', coupon.isSpecial ? 'Yes' : 'No'),
          if (coupon.usedAt?.trim().isNotEmpty == true)
            _detailRow('Used at', _formatDate(coupon.usedAt)),
          if (coupon.displayName?.trim().isNotEmpty == true)
            _detailRow('Description', coupon.displayName!),
        ]),
        if (product != null) ...[
          const SizedBox(height: 16),
          _detailsCard([
            _sectionTitle(_productTitle(coupon)),
            _detailRow('Name', _display(product.name), bold: true),
            _optionalRow('Price', product.price),
            _optionalRow('Description', product.description),
            _optionalRow('Duration', product.duration),
            _optionalRow('Minutes', product.minutes),
            _optionalRow('Storage', product.storage),
            _optionalRow('Storage size', product.storageSize),
          ]),
        ],
        if (batch != null) ...[
          const SizedBox(height: 16),
          _detailsCard([
            _sectionTitle('Coupon batch'),
            _detailRow('Reference', _display(batch.reference), bold: true),
            _detailRow('Name', _display(batch.displayName)),
            _detailRow(
              'Coupon type',
              _display(batch.typeName ?? batch.type),
            ),
            _detailRow('Region', _region(batch.region)),
            if (batch.createdAt?.trim().isNotEmpty == true)
              _detailRow('Created', _formatDate(batch.createdAt)),
          ]),
        ],
        if (_hasPerson(agent)) ...[
          const SizedBox(height: 16),
          _detailsCard([
            _sectionTitle('Issued by'),
            ..._personRows(agent!),
          ]),
        ],
        if (_hasPerson(redeemer)) ...[
          const SizedBox(height: 16),
          _detailsCard([
            _sectionTitle('Redeemed by'),
            ..._personRows(redeemer!),
          ]),
        ],
      ],
    );
  }

  String _productTitle(CouponData coupon) {
    if (coupon.packageData != null) return 'Package';
    if (coupon.additionalMinutePlan != null) return 'Additional minute plan';
    if (coupon.cloudStoragePlan != null) return 'Cloud storage plan';
    return 'Product';
  }

  bool _hasPerson(CouponPerson? person) =>
      person != null &&
      (person.name?.trim().isNotEmpty == true ||
          person.username?.trim().isNotEmpty == true);

  List<Widget> _personRows(CouponPerson person) => [
        if (person.name?.trim().isNotEmpty == true)
          _detailRow('Name', person.name!),
        if (person.username?.trim().isNotEmpty == true)
          _detailRow('Username', '@${person.username}'),
      ];

  Widget _optionalRow(String label, String? value) =>
      value?.trim().isNotEmpty == true
          ? _detailRow(label, value!)
          : const SizedBox.shrink();

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      );

  Widget _detailsCard(List<Widget> rows) => Container(
        decoration: BoxDecoration(
          color: NextelPalette.surface,
          border: Border.all(color: NextelPalette.border),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(children: rows),
      );

  Widget _detailRow(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: NextelPalette.muted,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: valueColor,
                      fontWeight: bold ? FontWeight.bold : null,
                    ),
              ),
            ),
          ],
        ),
      );
}
