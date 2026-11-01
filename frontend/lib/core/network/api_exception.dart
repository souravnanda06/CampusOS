class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final dynamic body;
  final Uri? uri;

  const ApiException({
    this.statusCode,
    required this.message,
    this.body,
    this.uri,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return 'ApiException($statusCode): $message';
    }
    return 'ApiException: $message';
  }
}
