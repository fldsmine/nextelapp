import 'package:flutter_test/flutter_test.dart';
import 'package:nextel_connect/features/support/domain/support_models.dart';
import 'package:nextel_connect/features/support/domain/support_validation.dart';

void main() {
  group('Support response models', () {
    test('maps a ticket and latest message without changing API field names', () {
      final ticket = SupportTicket.fromJson({
        'id': 42,
        'subject': 'Wallet credit missing',
        'category': 'payments',
        'reference': 'NX-2042',
        'status': 'open',
        'status_label': 'Awaiting response',
        'latest_message': {'body': 'I have attached the receipt.'},
      });

      expect(ticket.id, '42');
      expect(ticket.subject, 'Wallet credit missing');
      expect(ticket.category, 'payments');
      expect(ticket.reference, 'NX-2042');
      expect(ticket.statusLabel, 'Awaiting response');
      expect(ticket.latestMessage, 'I have attached the receipt.');
    });

    test('maps admin messages and derives account initials', () {
      final message = SupportMessage.fromJson({
        'sender_type': 'admin',
        'sender_name': 'Support Agent',
        'body': 'We are checking this for you.',
        'created_at': '2026-10-08T12:30:00Z',
      });
      final account = SupportAccount.fromJson({
        'name': 'Ada Lovelace Byron',
        'email': 'ada@example.test',
      });

      expect(message.fromSupport, isTrue);
      expect(message.senderName, 'Support Agent');
      expect(account.displayName, 'Ada Lovelace Byron');
      expect(account.initials, 'AL');
    });

    test('uses a safe fallback for missing account and optional fields', () {
      expect(SupportAccount.fromJson(null).displayName, 'Registered Nextel user');
      final ticket = SupportTicket.fromJson({});
      expect(ticket.id, isEmpty);
      expect(ticket.statusLabel, isEmpty);
      expect(ticket.latestMessage, isNull);
    });
  });

  group('Support form validation', () {
    test('preserves minimum subject and opening-message limits', () {
      expect(SupportValidation.subjectError('abc'), contains('4 characters'));
      expect(SupportValidation.subjectError('abcd'), isNull);
      expect(SupportValidation.openingMessageError('help'), contains('5 characters'));
      expect(SupportValidation.openingMessageError('please help'), isNull);
    });

    test('enforces legacy maximum lengths and a non-empty reply', () {
      final tooLongSubject = List.filled(161, 's').join();
      final tooLongMessage = List.filled(5001, 'm').join();
      expect(
        SupportValidation.subjectError(tooLongSubject),
        contains('160 characters'),
      );
      expect(
        SupportValidation.openingMessageError(tooLongMessage),
        contains('5000 characters'),
      );
      expect(SupportValidation.replyError('  '), contains('Write a reply'));
      expect(
        SupportValidation.replyError(tooLongMessage),
        contains('5000 characters'),
      );
      expect(SupportValidation.replyError('thanks'), isNull);
    });
  });
}
