class ApiFailure implements Exception {
  const ApiFailure({
    required this.statusCode,
    required this.message,
    this.fieldErrors = const {},
    this.retryAfterSeconds,
    this.data = const {},
  });

  final int statusCode;
  final String message;
  final Map<String, List<String>> fieldErrors;
  final int? retryAfterSeconds;
  final Object? data;

  String? firstFieldError(String field) {
    final values = fieldErrors[field];
    return values == null || values.isEmpty ? null : values.first;
  }

  String get displayMessage {
    final retry = retryAfterSeconds;
    if (statusCode == 429 && retry != null && retry > 0 &&
        !message.toLowerCase().contains('second')) {
      return '$message Please try again in $retry seconds.';
    }
    return message;
  }

  Map<String, Object?> get dataMap => data is Map
      ? (data as Map).map((key, value) => MapEntry(key.toString(), value))
      : const {};

  @override
  String toString() => 'ApiFailure($statusCode, $message)';
}
