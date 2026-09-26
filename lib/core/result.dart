import 'package:meta/meta.dart';
import 'failures.dart';

@immutable
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Success<T>;
  const factory Result.err(AppFailure failure) = Failure<T>;

  bool get isOk => this is Success<T>;
  bool get isErr => this is Failure<T>;

  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        Failure<T>() => null,
      };

  AppFailure? get failureOrNull => switch (this) {
        Success<T>() => null,
        Failure<T>(:final failure) => failure,
      };

  R when<R>({
    required R Function(T value) ok,
    required R Function(AppFailure failure) err,
  }) =>
      switch (this) {
        Success<T>(:final value) => ok(value),
        Failure<T>(:final failure) => err(failure),
      };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Success<T>(:final value) => Result.ok(transform(value)),
        Failure<T>(:final failure) => Result.err(failure),
      };
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Result.ok($value)';
}

final class Failure<T> extends Result<T> {
  const Failure(this.failure);
  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> &&
          runtimeType == other.runtimeType &&
          failure == other.failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'Result.err($failure)';
}
