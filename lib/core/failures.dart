import 'package:meta/meta.dart';

@immutable
sealed class AppFailure {
  const AppFailure({required this.message, this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure({
    required super.message,
    super.cause,
    this.statusCode,
  });

  final int? statusCode;
}

final class AuthFailure extends AppFailure {
  const AuthFailure({
    required super.message,
    required this.service,
    super.cause,
    this.statusCode = 401,
  });

  final String service; // e.g. 'notion', 'gemini', 'mcp.ado'
  final int statusCode;
}

final class RateLimitFailure extends AppFailure {
  const RateLimitFailure({
    required super.message,
    this.retryAfter,
    super.cause,
  });

  final Duration? retryAfter;
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    required super.message,
    this.rawErrorPayload,
    super.cause,
  });

  final Map<String, dynamic>? rawErrorPayload;
}

final class ToolFailure extends AppFailure {
  const ToolFailure({
    required super.message,
    required this.toolName,
    super.cause,
  });

  final String toolName;
}

final class CancelledFailure extends AppFailure {
  const CancelledFailure({
    super.message = 'Operation was cancelled',
    super.cause,
  });
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure({
    required super.message,
    super.cause,
  });
}
