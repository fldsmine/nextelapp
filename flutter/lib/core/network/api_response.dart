class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.message,
    required this.data,
    this.cookies = const [],
  });

  final int statusCode;
  final String message;
  final Object? data;
  final List<String> cookies;

  Map<String, Object?> get dataMap => data is Map
      ? (data as Map).map((key, value) => MapEntry(key.toString(), value))
      : const {};
}
