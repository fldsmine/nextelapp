import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/errors/api_failure.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/support_repository.dart';
import '../../domain/support_models.dart';
import '../../domain/support_validation.dart';

class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({this.initialToken, super.key});

  /// May be the current access token or the short-lived suspended-account
  /// support token. It is kept in memory and never rendered or logged.
  final String? initialToken;

  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  static const _categories = <(String, String)>[
    ('general', 'General enquiry'),
    ('account', 'Account access'),
    ('payments', 'Payments'),
    ('technical', 'Technical issue'),
  ];

  final _subjectController = TextEditingController();
  final _openingMessageController = TextEditingController();
  final _replyController = TextEditingController();

  String? _accessToken;
  String _selectedCategory = 'general';
  SupportAccount _account = const SupportAccount(name: '', email: '');
  List<SupportTicket> _tickets = const [];
  SupportConversation? _conversation;
  String? _ticketError;
  String? _formError;
  String? _replyError;
  bool _initializing = true;
  bool _loadingTickets = false;
  bool _loadingConversation = false;
  bool _creatingTicket = false;
  bool _sendingReply = false;
  bool _showingConversation = false;
  bool _retriedWithCurrentSessionToken = false;
  bool _routingToLogin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initialize());
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _openingMessageController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final supplied = widget.initialToken?.trim();
      final storedToken = supplied != null && supplied.isNotEmpty
          ? null
          : await ref.read(sessionStoreProvider).readToken();
      if (!mounted) return;
      _accessToken = supplied != null && supplied.isNotEmpty
          ? supplied
          : storedToken;
      if (_accessToken == null || _accessToken!.isEmpty) {
        await _routeToLogin();
        return;
      }
      await _loadTickets();
    } catch (_) {
      if (mounted) {
        setState(() {
          _ticketError = 'Could not open Support. Please retry.';
        });
      }
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<T> _withAuthorizedToken<T>(
    Future<T> Function(String token) operation,
  ) async {
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      await _routeToLogin();
      throw const ApiFailure(statusCode: 401, message: 'Sign in to use Support.');
    }

    try {
      return await operation(token);
    } on ApiFailure catch (failure) {
      if (failure.statusCode != 401 || !mounted) rethrow;

      if (!_retriedWithCurrentSessionToken) {
        String? currentToken;
        try {
          currentToken = await ref.read(sessionStoreProvider).readToken();
        } catch (_) {
          // The short-lived support token may still be valid even if the
          // device session cannot be read; route to Login only after retry is
          // unavailable.
        }
        if (currentToken != null &&
            currentToken.isNotEmpty &&
            currentToken != token) {
          _retriedWithCurrentSessionToken = true;
          _accessToken = currentToken;
          try {
            return await operation(currentToken);
          } on ApiFailure catch (retryFailure) {
            if (retryFailure.statusCode == 401) {
              await _routeToLogin();
            }
            rethrow;
          }
        }
      }
      await _routeToLogin();
      rethrow;
    }
  }

  Future<void> _routeToLogin() async {
    if (_routingToLogin) return;
    _routingToLogin = true;
    if (mounted) {
      try {
        await ref.read(authRepositoryProvider).handleExpiredSession();
      } catch (_) {
        // Keep the navigation path available if platform cleanup fails.
      }
    }
    if (mounted) context.go(AppRoutes.login);
  }

  Future<void> _loadTickets() async {
    if (!mounted) return;
    setState(() {
      _loadingTickets = true;
      _ticketError = null;
    });
    try {
      final overview = await _withAuthorizedToken(
        (token) => ref.read(supportRepositoryProvider).loadTickets(token),
      );
      if (!mounted) return;
      setState(() {
        _account = overview.account;
        _tickets = overview.tickets;
      });
    } on ApiFailure catch (failure) {
      if (!mounted || _routingToLogin) return;
      setState(() => _ticketError = failure.displayMessage);
    } catch (_) {
      if (mounted) {
        setState(() => _ticketError = 'Unable to load support tickets. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _loadingTickets = false);
    }
  }

  Future<void> _openTicket() async {
    FocusScope.of(context).unfocus();
    final subject = _subjectController.text.trim();
    final message = _openingMessageController.text.trim();
    final subjectError = SupportValidation.subjectError(subject);
    final messageError = SupportValidation.openingMessageError(message);
    if (subjectError != null || messageError != null) {
      setState(() {
        _formError = subjectError ?? messageError;
      });
      return;
    }

    setState(() {
      _creatingTicket = true;
      _formError = null;
    });
    try {
      final created = await _withAuthorizedToken(
        (token) => ref.read(supportRepositoryProvider).createTicket(
              bearerToken: token,
              subject: subject,
              category: _selectedCategory,
              message: message,
            ),
      );
      if (!mounted) return;
      if (created.account != null &&
          (created.account!.name.isNotEmpty || created.account!.email.isNotEmpty)) {
        _account = created.account!;
      }
      _subjectController.clear();
      _openingMessageController.clear();
      setState(() => _selectedCategory = 'general');
      final ticketId = created.ticket?.id ?? '';
      if (ticketId.isEmpty) {
        setState(() {
          _formError =
              "Your ticket was created, but we couldn't open its conversation.";
        });
        unawaited(_loadTickets());
        return;
      }
      _showMessage('Support ticket opened.');
      await _loadConversation(ticketId);
    } on ApiFailure catch (failure) {
      if (!mounted || _routingToLogin) return;
      setState(() {
        _formError = failure.firstFieldError('subject') ??
            failure.firstFieldError('category') ??
            failure.firstFieldError('message') ??
            failure.displayMessage;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _formError = 'Could not open the support ticket. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _creatingTicket = false);
    }
  }

  Future<void> _loadConversation(String ticketId) async {
    if (ticketId.trim().isEmpty || !mounted) return;
    setState(() {
      _loadingConversation = true;
      _replyError = null;
    });
    try {
      final conversation = await _withAuthorizedToken(
        (token) => ref.read(supportRepositoryProvider).loadConversation(
              bearerToken: token,
              ticketId: ticketId,
            ),
      );
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _showingConversation = true;
      });
    } on ApiFailure catch (failure) {
      if (!mounted || _routingToLogin) return;
      _showMessage(failure.displayMessage);
    } catch (_) {
      if (mounted) _showMessage('Could not load this support conversation.');
    } finally {
      if (mounted) setState(() => _loadingConversation = false);
    }
  }

  Future<void> _sendReply() async {
    final conversation = _conversation;
    if (conversation == null) return;
    FocusScope.of(context).unfocus();
    final message = _replyController.text.trim();
    final error = SupportValidation.replyError(message);
    if (error != null) {
      setState(() => _replyError = error);
      return;
    }

    setState(() {
      _sendingReply = true;
      _replyError = null;
    });
    try {
      await _withAuthorizedToken(
        (token) => ref.read(supportRepositoryProvider).sendReply(
              bearerToken: token,
              ticketId: conversation.ticket.id,
              message: message,
            ),
      );
      if (!mounted) return;
      _replyController.clear();
      await _loadConversation(conversation.ticket.id);
    } on ApiFailure catch (failure) {
      if (!mounted || _routingToLogin) return;
      setState(() {
        _replyError = failure.firstFieldError('message') ?? failure.displayMessage;
      });
    } catch (_) {
      if (mounted) setState(() => _replyError = 'Could not send your reply. Please retry.');
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  Future<void> _showTicketList() async {
    if (!mounted) return;
    setState(() {
      _showingConversation = false;
      _conversation = null;
      _replyController.clear();
    });
    await _loadTickets();
  }

  void _handleBack() {
    if (_showingConversation) {
      unawaited(_showTicketList());
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.dashboard);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _categoryLabel(String category) {
    for (final (key, label) in _categories) {
      if (key == category) return label;
    }
    return category.isEmpty ? 'General enquiry' : category;
  }

  String _formattedDate(String value) {
    if (value.isEmpty) return '';
    return value.replaceFirst('T', ' ').substring(
      0,
      value.length < 16 ? value.length : 16,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_showingConversation,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showingConversation) unawaited(_showTicketList());
      },
      child: Scaffold(
        backgroundColor: NextelPalette.background,
        appBar: AppBar(
          backgroundColor: NextelPalette.primary,
          foregroundColor: Colors.white,
          title: Text(_showingConversation ? 'Support ticket' : 'Help & Support'),
          leading: IconButton(
            tooltip: _showingConversation ? 'Back to tickets' : 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          actions: [
            if (!_showingConversation)
              IconButton(
                tooltip: 'Refresh tickets',
                onPressed: _loadingTickets ? null : _loadTickets,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        body: SafeArea(
          child: _initializing
              ? const Center(child: CircularProgressIndicator())
              : _showingConversation
                  ? _buildConversation()
                  : _buildTicketList(),
        ),
      ),
    );
  }

  Widget _buildTicketList() => RefreshIndicator(
        onRefresh: _loadTickets,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          children: [
            _buildAccountCard(),
            const SizedBox(height: 18),
            _buildTicketForm(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your tickets',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: NextelPalette.text,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (_loadingTickets && _tickets.isNotEmpty)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_ticketError != null)
              _buildInlineError(
                _ticketError!,
                onRetry: _loadingTickets ? null : _loadTickets,
              ),
            if (_tickets.isEmpty && _loadingTickets)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_tickets.isEmpty && !_loadingTickets && _ticketError == null)
              const _SupportEmptyState(),
            if (_tickets.isNotEmpty) ..._tickets.map(_buildTicketCard),
          ],
        ),
      );

  Widget _buildAccountCard() => Card(
        color: NextelPalette.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: NextelPalette.accent,
                foregroundColor: NextelPalette.primary,
                child: Text(
                  _account.initials,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REGISTERED ACCOUNT',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: NextelPalette.muted,
                            fontWeight: FontWeight.bold,
                            letterSpacing: .5,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _account.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (_account.email.isNotEmpty)
                      Text(
                        _account.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: NextelPalette.muted,
                            ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildTicketForm() => Card(
        color: NextelPalette.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Open a ticket',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _subjectController,
                maxLength: SupportValidation.maxSubjectLength,
                maxLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  counterText: '',
                ),
                onChanged: (_) {
                  if (_formError != null) setState(() => _formError = null);
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final (key, label) in _categories)
                    DropdownMenuItem(value: key, child: Text(label)),
                ],
                onChanged: _creatingTicket
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedCategory = value);
                        }
                      },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _openingMessageController,
                maxLength: SupportValidation.maxMessageLength,
                minLines: 4,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Describe how we can help',
                  alignLabelWithHint: true,
                ),
                onChanged: (_) {
                  if (_formError != null) setState(() => _formError = null);
                },
              ),
              if (_formError != null) ...[
                const SizedBox(height: 6),
                _ErrorText(_formError!),
              ],
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _creatingTicket ? null : _openTicket,
                icon: _creatingTicket
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_comment_outlined),
                label: const Text('Open support ticket'),
              ),
            ],
          ),
        ),
      );

  Widget _buildTicketCard(SupportTicket ticket) => Card(
        color: NextelPalette.surface,
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _loadingConversation
              ? null
              : () => _loadConversation(ticket.id),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        ticket.subject,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: NextelPalette.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(label: ticket.statusLabel),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${ticket.reference} · ${_categoryLabel(ticket.category)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NextelPalette.muted,
                      ),
                ),
                if ((ticket.latestMessage ?? '').isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    ticket.latestMessage!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (_loadingConversation &&
                    _conversation?.ticket.id == ticket.id) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _buildConversation() {
    final conversation = _conversation;
    if (conversation == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _showTicketList,
            icon: const Icon(Icons.chevron_left),
            label: const Text('All tickets'),
          ),
        ),
        Card(
          color: NextelPalette.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.ticket.reference,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NextelPalette.muted,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  conversation.ticket.subject,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                _StatusPill(label: conversation.ticket.statusLabel),
              ],
            ),
          ),
        ),
        if (_loadingConversation) const LinearProgressIndicator(),
        for (final message in conversation.messages) _buildMessageBubble(message),
        Card(
          color: NextelPalette.surface,
          margin: const EdgeInsets.only(top: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _replyController,
                  maxLength: SupportValidation.maxMessageLength,
                  minLines: 3,
                  maxLines: 7,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Write a reply',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) {
                    if (_replyError != null) setState(() => _replyError = null);
                  },
                ),
                if (_replyError != null) ...[
                  const SizedBox(height: 6),
                  _ErrorText(_replyError!),
                ],
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _sendingReply ? null : _sendReply,
                  icon: _sendingReply
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined),
                  label: const Text('Send reply'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(SupportMessage message) {
    final fromSupport = message.fromSupport;
    final availableWidth = MediaQuery.sizeOf(context).width * .78;
    return Align(
      alignment: fromSupport ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: availableWidth),
        margin: const EdgeInsets.only(top: 5, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: fromSupport ? NextelPalette.surface : const Color(0xFFEAF2D2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NextelPalette.border.withValues(alpha: .55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fromSupport
                  ? (message.senderName.trim().isEmpty
                      ? 'Nextel Support'
                      : message.senderName)
                  : 'You',
              style: const TextStyle(
                color: NextelPalette.primary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            SelectableText(message.body),
            if (message.createdAt.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                _formattedDate(message.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: NextelPalette.muted,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInlineError(String message, {required VoidCallback? onRetry}) =>
      Card(
        color: NextelPalette.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(color: NextelPalette.danger)),
              if (onRetry != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      );
}

class _SupportEmptyState extends StatelessWidget {
  const _SupportEmptyState();

  @override
  Widget build(BuildContext context) => Card(
        color: NextelPalette.surface,
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'Your support conversations will appear here.',
            style: TextStyle(color: NextelPalette.muted),
          ),
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE7EDCD),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label.isEmpty ? 'Open' : label,
          style: const TextStyle(
            color: NextelPalette.primary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Text(
        message,
        style: const TextStyle(color: NextelPalette.danger, fontSize: 12),
      );
}
