import 'package:resource_bloc/resource_bloc.dart';
import 'package:test/test.dart';

/// A matcher that matches a resource state that is loading and all other
/// properties (key, value, source, error) are null.
Matcher isEmptyLoadingState = isInitialLoadingState(isNull);

/// A matcher that matches a resource state that is not loading and all other
/// properties (key, value, source, error) are null.
Matcher isEmptyNonLoadingState = isInitialNonLoadingState(isNull);

/// A matcher that matches a resource state that is loading, where the key
/// matches the given key matcher, and value & error are null
Matcher isInitialLoadingState(Object key) =>
    isLoadingStateWith(key: key, value: isNull, error: isNull);

/// A matcher that matches a resource state that is not loading, where
/// the key matches the given key matcher, and value & error are null
Matcher isInitialNonLoadingState(Object key) =>
    isNonLoadingStateWith(key: key, value: isNull, error: isNull);

/// Convenience matcher that matches a resource state that is loading, with the
/// given value and source.
///
/// Optional key & error matchers can also be provided
Matcher isLoadingWithValue(
  Object? value,
  Source source, {
  Object? key,
  Object? error,
}) =>
    isLoadingStateWith(key: key, value: value, source: source, error: error);

/// Convenience matcher that matches a resource state that is not loading, with
/// the given value & source.
///
/// Optional key & error matchers can also be provided
Matcher isDoneWithValue(
  Object? value,
  Source source, {
  Object? key,
  Object? error,
}) =>
    isNonLoadingStateWith(key: key, value: value, source: source, error: error);

/// Matcher that matches a resource state that is loading.
///
/// Matchers for other properties can also be provided.
Matcher isLoadingStateWith({
  Object? key,
  Object? value,
  Object? error,
  Source? source,
}) =>
    isStateWith(
      isLoading: true,
      key: key,
      value: value,
      error: error,
      source: source,
    );

/// Matcher that matches a resource state that is not loading.
///
/// Matchers for other properties can also be provided.
Matcher isNonLoadingStateWith({
  Object? key,
  Object? value,
  Object? error,
  Source? source,
}) =>
    isStateWith(
      isLoading: false,
      key: key,
      value: value,
      error: error,
      source: source,
    );

/// Matcher that matches a [StateSnapshot] that is strictly of the provided
/// generic value type.
Matcher isSnapshotOf<V>({
  bool? isLoading,
  Object? value,
  Object? error,
  Source? source,
}) =>
    _ResourceStateMatcher<Object, V>(
        isLoading, null, value, error, source, true);

/// Matcher that matches a [ResourceState] that is strictly of the provided
/// generic key and value types.
Matcher isStateOf<K extends Object, V>({
  bool? isLoading,
  Object? key,
  Object? value,
  Object? error,
  Source? source,
}) =>
    _ResourceStateMatcher<K, V>(isLoading, key, value, error, source, true);

/// Matcher that matches a [ResourceState] or [StateSnapshot] whose properties
/// match all of the provided matchers.
Matcher isStateWith({
  bool? isLoading,
  Object? key,
  Object? value,
  Object? error,
  Source? source,
}) =>
    _ResourceStateMatcher(isLoading, key, value, error, source, false);

class _ResourceStateMatcher<K extends Object, V> extends Matcher {
  _ResourceStateMatcher(
    this.isLoading,
    this.keyMatcher,
    this.valueMatcher,
    this.errorMatcher,
    this.source,
    this.isStrictType,
  );

  final bool? isLoading;
  final Object? keyMatcher;
  final Object? valueMatcher;
  final Object? errorMatcher;
  final Source? source;
  final bool isStrictType;

  bool get _isSnapshotMatcher => (keyMatcher == null || keyMatcher == isNull);

  bool _isValidState(StateSnapshot item, Map matchState) {
    final isValidLoading = isLoading == null || item.isLoading == isLoading;
    final isValidKey = keyMatcher == null ||
        (item is ResourceState &&
            wrapMatcher(keyMatcher).matches(item.key, matchState)) ||
        (item is! ResourceState && keyMatcher == isNull); // for strict snapshot
    final isValidValue = valueMatcher == null ||
        wrapMatcher(valueMatcher).matches(item.value, matchState);
    final isValidError = errorMatcher == null ||
        wrapMatcher(errorMatcher).matches(item.error, matchState);
    final isValidSource =
        source == null || (item.hasValue && item.requireSource == source);

    return isValidLoading &&
        isValidKey &&
        isValidValue &&
        isValidError &&
        isValidSource;
  }

  @override
  bool matches(dynamic item, Map matchState) {
    final isResourceState = !isStrictType && item is ResourceState;
    final isTypedResourceState = isStrictType && item is ResourceState<K, V>;
    final isSnapshot =
        _isSnapshotMatcher && !isStrictType && item is StateSnapshot;
    final isTypedSnapshot =
        _isSnapshotMatcher && isStrictType && item is StateSnapshot<V>;

    if (isResourceState ||
        isTypedResourceState ||
        isSnapshot ||
        isTypedSnapshot) {
      return _isValidState(item, matchState);
    } else {
      return false;
    }
  }

  @override
  Description describe(Description description) {
    final classPart = _isSnapshotMatcher ? 'StateSnapshot' : 'ResourceState';

    final genericText = _isSnapshotMatcher ? '<$V>' : '<$K, $V>';
    final genericPart = isStrictType ? genericText : '';

    description.add('$classPart$genericPart(');

    void addAll(Iterable<Iterable<Object?>> lines) {
      var shouldSeparate = false;
      for (final line in lines) {
        if (shouldSeparate) {
          description.add(', ');
        }
        for (final value in line) {
          description.addDescriptionOf(value);
        }
        shouldSeparate = true;
      }
    }

    addAll([
      if (isLoading != null) ['isLoading=$isLoading'],
      if (keyMatcher != null) ['key=', keyMatcher],
      if (valueMatcher != null) ['value=', valueMatcher],
      if (source != null) ['source=$source'],
      if (errorMatcher != null) ['error=', errorMatcher],
    ]);

    description.add(')');

    return description;
  }
}
