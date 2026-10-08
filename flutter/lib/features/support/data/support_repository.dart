import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/nextel_api.dart';
import '../domain/support_models.dart';

class SupportRepository {
  const SupportRepository({required NextelApi api}) : _api = api;

  final NextelApi _api;

  Future<SupportOverview> loadTickets(String bearerToken) async {
    final response = await _api.get(
      'support-tickets',
      bearerToken: bearerToken,
    );
    final data = response.dataMap;
    final rawTickets = data['tickets'];
    return SupportOverview(
      account: SupportAccount.fromJson(data['user']),
      tickets: rawTickets is List
          ? rawTickets.map(SupportTicket.fromJson).toList(growable: false)
          : const [],
    );
  }

  Future<SupportTicketCreation> createTicket({
    required String bearerToken,
    required String subject,
    required String category,
    required String message,
  }) async {
    final response = await _api.post(
      'support-tickets',
      bearerToken: bearerToken,
      body: {
        'subject': subject,
        'category': category,
        'message': message,
      },
    );
    final data = response.dataMap;
    final ticketMap = data['ticket'];
    final ticket = ticketMap is Map ? SupportTicket.fromJson(ticketMap) : null;
    return SupportTicketCreation(
      account: data['user'] == null ? null : SupportAccount.fromJson(data['user']),
      ticket: ticket,
    );
  }

  Future<SupportConversation> loadConversation({
    required String bearerToken,
    required String ticketId,
  }) async {
    final safeTicketId = Uri.encodeComponent(ticketId);
    final response = await _api.get(
      'support-tickets/$safeTicketId',
      bearerToken: bearerToken,
    );
    final data = response.dataMap;
    final parsedTicket = SupportTicket.fromJson(data['ticket']);
    final ticket = parsedTicket.id.isEmpty
        ? parsedTicket.copyWith(id: ticketId)
        : parsedTicket;
    final rawMessages = data['messages'];
    return SupportConversation(
      ticket: ticket,
      messages: rawMessages is List
          ? rawMessages.map(SupportMessage.fromJson).toList(growable: false)
          : const [],
    );
  }

  Future<void> sendReply({
    required String bearerToken,
    required String ticketId,
    required String message,
  }) async {
    final safeTicketId = Uri.encodeComponent(ticketId);
    await _api.post(
      'support-tickets/$safeTicketId/messages',
      bearerToken: bearerToken,
      body: {'message': message},
    );
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(api: ref.watch(nextelApiProvider));
});
