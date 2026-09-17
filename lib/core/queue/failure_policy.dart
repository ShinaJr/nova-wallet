import 'dart:math';
import 'package:dio/dio.dart';

enum FailureClass { retryable, insufficientFunds, permanent }

class FailurePolicy {
  FailurePolicy._();

  static const int maxAttempts = 5;

  static FailureClass classify(Object error) {
    if (error is DioException) {
      final code = error.response?.statusCode;

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.connectionError) {
        return FailureClass.retryable;
      }
      if (code != null && code >= 500) return FailureClass.retryable;
      if (code == 429) return FailureClass.retryable;

      if (code == 402) return FailureClass.insufficientFunds;

      if (code == 400 || code == 403 || code == 422) {
        return FailureClass.permanent;
      }
      if (code == 401) return FailureClass.permanent;
    }
    return FailureClass.retryable;
  }

  static Duration backoffFor(int attempts) {
    final baseSeconds = 1 << attempts.clamp(0, 6);
    final base = Duration(seconds: baseSeconds);
    final capped =
        base > const Duration(minutes: 2) ? const Duration(minutes: 2) : base;
    final jitterMs = Random().nextInt(1000);
    return capped + Duration(milliseconds: jitterMs);
  }
}
