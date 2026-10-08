abstract final class SupportValidation {
  static const int minSubjectLength = 4;
  static const int maxSubjectLength = 160;
  static const int minOpeningMessageLength = 5;
  static const int maxMessageLength = 5000;

  static String? subjectError(String value) {
    final subject = value.trim();
    if (subject.length < minSubjectLength) {
      return 'Please enter a subject of at least 4 characters.';
    }
    if (subject.length > maxSubjectLength) {
      return 'The subject cannot exceed 160 characters.';
    }
    return null;
  }

  static String? openingMessageError(String value) {
    final message = value.trim();
    if (message.length < minOpeningMessageLength) {
      return 'Please describe your issue in at least 5 characters.';
    }
    if (message.length > maxMessageLength) {
      return 'The message cannot exceed 5000 characters.';
    }
    return null;
  }

  static String? replyError(String value) {
    final message = value.trim();
    if (message.isEmpty) return 'Write a reply before sending.';
    if (message.length > maxMessageLength) {
      return 'The reply cannot exceed 5000 characters.';
    }
    return null;
  }
}
