import 'package:dio/dio.dart';

/// The single error type every network call funnels into (§6.1). The UI never
/// reads dio directly — it catches this and asks `errorText(code)` what to show.
/// The server [serverMessage] is for logs only and must never be displayed.
enum ApiErrorKind { offline, server }

class ApiException implements Exception {
  ApiException({
    required this.kind,
    this.status,
    this.code,
    this.serverMessage,
    this.fields,
  });

  final ApiErrorKind kind;
  final int? status;
  final String? code; // snake_case code from the {error:{code,message}} envelope
  final String? serverMessage; // log this, do not show it
  final Map<String, String>? fields; // 422 per-field messages

  bool get isOffline => kind == ApiErrorKind.offline;

  /// Builds an ApiException from a dio failure, parsing the standard envelope.
  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return ApiException(kind: ApiErrorKind.offline);
      case DioExceptionType.unknown:
        if (e.error is! FormatException && e.response == null) {
          return ApiException(kind: ApiErrorKind.offline);
        }
        break;
      default:
        break;
    }

    final status = e.response?.statusCode;
    String? code;
    String? message;
    Map<String, String>? fields;

    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      code = err['code'] as String?;
      message = err['message'] as String?;
      if (err['fields'] is Map) {
        fields = (err['fields'] as Map).map((k, v) => MapEntry('$k', '$v'));
      }
    }

    return ApiException(
      kind: ApiErrorKind.server,
      status: status,
      code: code,
      serverMessage: message,
      fields: fields,
    );
  }

  @override
  String toString() => 'ApiException(kind: $kind, status: $status, code: $code)';
}
