class SupportAccount {
  const SupportAccount({required this.name, required this.email});

  final String name;
  final String email;

  factory SupportAccount.fromJson(Object? value) {
    final json = _stringMap(value);
    return SupportAccount(
      name: _stringValue(json['name']),
      email: _stringValue(json['email']),
    );
  }

  String get displayName => name.trim().isEmpty ? 'Registered Nextel user' : name;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    return parts
        .take(2)
        .map((part) => String.fromCharCode(part.runes.first).toUpperCase())
        .join()
        .ifEmpty('N');
  }
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.category,
    required this.reference,
    required this.status,
    required this.statusLabel,
    this.latestMessage,
  });

  final String id;
  final String subject;
  final String category;
  final String reference;
  final String status;
  final String statusLabel;
  final String? latestMessage;

  SupportTicket copyWith({String? id}) => SupportTicket(
        id: id ?? this.id,
        subject: subject,
        category: category,
        reference: reference,
        status: status,
        statusLabel: statusLabel,
        latestMessage: latestMessage,
      );

  factory SupportTicket.fromJson(Object? value) {
    final json = _stringMap(value);
    final latest = _stringMap(json['latest_message']);
    return SupportTicket(
      id: _stringValue(json['id']),
      subject: _stringValue(json['subject']),
      category: _stringValue(json['category']),
      reference: _stringValue(json['reference']),
      status: _stringValue(json['status']),
      statusLabel: _nonEmpty(json['status_label']) ?? _stringValue(json['status']),
      latestMessage: _nonEmpty(latest['body']),
    );
  }
}

class SupportMessage {
  const SupportMessage({
    required this.senderType,
    required this.senderName,
    required this.body,
    required this.createdAt,
  });

  final String senderType;
  final String senderName;
  final String body;
  final String createdAt;

  bool get fromSupport => senderType == 'admin';

  factory SupportMessage.fromJson(Object? value) {
    final json = _stringMap(value);
    return SupportMessage(
      senderType: _stringValue(json['sender_type']),
      senderName: _stringValue(json['sender_name']),
      body: _stringValue(json['body']),
      createdAt: _stringValue(json['created_at']),
    );
  }
}

class SupportOverview {
  const SupportOverview({required this.account, required this.tickets});

  final SupportAccount account;
  final List<SupportTicket> tickets;
}

class SupportConversation {
  const SupportConversation({required this.ticket, required this.messages});

  final SupportTicket ticket;
  final List<SupportMessage> messages;
}

class SupportTicketCreation {
  const SupportTicketCreation({this.account, this.ticket});

  final SupportAccount? account;
  final SupportTicket? ticket;
}

Map<String, Object?> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

String _stringValue(Object? value) => value?.toString() ?? '';

String? _nonEmpty(Object? value) {
  final text = _stringValue(value).trim();
  return text.isEmpty ? null : text;
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
