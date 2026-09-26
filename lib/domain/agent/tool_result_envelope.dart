import '../../core/failures.dart';

enum ToolErrorKind {
  notFound('not_found', true, 'Resolve the identifier with a discovery/list tool, then retry.'),
  invalidArgument('invalid_argument', true, 'Re-read the tool schema; fix the argument and retry once.'),
  ambiguous('ambiguous', true, 'Several matches — narrow the query or ask the user.'),
  auth('auth', false, 'Credentials missing/expired. Tell the user to fix it in Settings. Do not retry.'),
  rateLimit('rate_limit', true, 'Wait and retry, or use a cheaper tool.'),
  network('network', true, 'Transient. Retry at most once.'),
  unavailable('unavailable', false, 'Tool/server down. Report and continue without it.'),
  declined('declined', false, 'The user declined this action.'),
  internal('internal', false, 'Report the failure.');

  const ToolErrorKind(this.wireName, this.defaultRecoverable, this.defaultHint);

  final String wireName;
  final bool defaultRecoverable;
  final String defaultHint;
}

class ToolResultEnvelope {
  const ToolResultEnvelope._();

  static Map<String, dynamic> success(Map<String, dynamic> result) {
    return {
      'ok': true,
      'result': result,
    };
  }

  static ToolErrorKind classifyError({
    AppFailure? failure,
    int? statusCode,
    String? message,
  }) {
    if (failure != null) {
      if (failure is AuthFailure) return ToolErrorKind.auth;
      if (failure is RateLimitFailure) return ToolErrorKind.rateLimit;
      if (failure is NetworkFailure) return ToolErrorKind.network;
      if (failure is ValidationFailure) return ToolErrorKind.invalidArgument;
      if (failure is CancelledFailure) return ToolErrorKind.declined;
    }

    if (statusCode != null) {
      if (statusCode == 401 || statusCode == 403) return ToolErrorKind.auth;
      if (statusCode == 404) return ToolErrorKind.notFound;
      if (statusCode == 429) return ToolErrorKind.rateLimit;
      if (statusCode == 400 || statusCode == 422) return ToolErrorKind.invalidArgument;
      if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
        return ToolErrorKind.unavailable;
      }
    }

    final msg = (message ?? failure?.message ?? '').toLowerCase();
    if (RegExp(r'(not found|doesn.*t exist|does not exist|unknown project|unknown item|cannot find|could not find|no such)').hasMatch(msg)) {
      return ToolErrorKind.notFound;
    }
    if (RegExp(r'(unauthorized|forbidden|invalid token|authentication|permission denied)').hasMatch(msg)) {
      return ToolErrorKind.auth;
    }
    if (RegExp(r'(rate limit|too many requests|quota)').hasMatch(msg)) {
      return ToolErrorKind.rateLimit;
    }
    if (RegExp(r'(ambiguous|multiple matches|more than one)').hasMatch(msg)) {
      return ToolErrorKind.ambiguous;
    }
    if (RegExp(r'(invalid|required argument|missing argument|schema|validation failed)').hasMatch(msg)) {
      return ToolErrorKind.invalidArgument;
    }
    if (RegExp(r'(unavailable|service down|connection refused|timeout|offline)').hasMatch(msg)) {
      return ToolErrorKind.unavailable;
    }
    if (RegExp(r'(network error|socket|connection reset)').hasMatch(msg)) {
      return ToolErrorKind.network;
    }
    if (RegExp(r'(declined|rejected|cancelled)').hasMatch(msg)) {
      return ToolErrorKind.declined;
    }

    return ToolErrorKind.internal;
  }

  static Map<String, dynamic> failure({
    required String message,
    AppFailure? appFailure,
    int? statusCode,
    List<String> relatedTools = const [],
    int attempt = 1,
    String? customErrorKind,
    bool? customRecoverable,
    String? customHint,
  }) {
    final kind = classifyError(
      failure: appFailure,
      statusCode: statusCode,
      message: message,
    );

    final errorKind = customErrorKind ?? kind.wireName;
    final recoverable = customRecoverable ?? kind.defaultRecoverable;
    final hint = customHint ?? kind.defaultHint;

    final map = <String, dynamic>{
      'ok': false,
      'error_kind': errorKind,
      'recoverable': recoverable,
      'message': message,
      'hint': hint,
      'attempt': attempt,
    };

    if (relatedTools.isNotEmpty) {
      map['related_tools'] = relatedTools;
    }

    return map;
  }
}
