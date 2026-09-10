import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Helpers for deriving one [AsyncValue] from several others.
///
/// The pattern these replace is `ref.watch(dep).asData?.value ?? []`, which
/// silently substitutes an empty list while a dependency is still loading. A
/// derived provider built that way emits a fully-formed but *wrong* result
/// (0% attendance, "no subjects", empty tables) and then corrects itself a
/// moment later, which is exactly the flicker users were reporting.
///
/// Combining properly means the derived value stays `loading` until every
/// input has arrived, and surfaces the first error if one occurs.
extension AsyncValueCombine2<A, B> on (AsyncValue<A>, AsyncValue<B>) {
  AsyncValue<R> combine<R>(R Function(A a, B b) build) {
    final (a, b) = this;
    final error = a.firstError ?? b.firstError;
    if (error != null) return AsyncError(error.$1, error.$2);
    if (a.isLoading || b.isLoading) return const AsyncLoading();
    if (!a.hasValue || !b.hasValue) return const AsyncLoading();
    return AsyncData(build(a.requireValue, b.requireValue));
  }
}

extension AsyncValueCombine3<A, B, C>
    on (AsyncValue<A>, AsyncValue<B>, AsyncValue<C>) {
  AsyncValue<R> combine<R>(R Function(A a, B b, C c) build) {
    final (a, b, c) = this;
    final error = a.firstError ?? b.firstError ?? c.firstError;
    if (error != null) return AsyncError(error.$1, error.$2);
    if (a.isLoading || b.isLoading || c.isLoading) return const AsyncLoading();
    if (!a.hasValue || !b.hasValue || !c.hasValue) {
      return const AsyncLoading();
    }
    return AsyncData(build(a.requireValue, b.requireValue, c.requireValue));
  }
}

extension AsyncValueCombine4<A, B, C, D>
    on (AsyncValue<A>, AsyncValue<B>, AsyncValue<C>, AsyncValue<D>) {
  AsyncValue<R> combine<R>(R Function(A a, B b, C c, D d) build) {
    final (a, b, c, d) = this;
    final error =
        a.firstError ?? b.firstError ?? c.firstError ?? d.firstError;
    if (error != null) return AsyncError(error.$1, error.$2);
    if (a.isLoading || b.isLoading || c.isLoading || d.isLoading) {
      return const AsyncLoading();
    }
    if (!a.hasValue || !b.hasValue || !c.hasValue || !d.hasValue) {
      return const AsyncLoading();
    }
    return AsyncData(
      build(a.requireValue, b.requireValue, c.requireValue, d.requireValue),
    );
  }
}

extension AsyncValueError<T> on AsyncValue<T> {
  /// The error and stack trace, if this value is in the error state.
  (Object, StackTrace)? get firstError =>
      hasError ? (error!, stackTrace ?? StackTrace.empty) : null;
}
