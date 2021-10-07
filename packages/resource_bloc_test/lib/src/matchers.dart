import 'package:resource_bloc/resource_bloc.dart';
import 'package:test/test.dart';

Matcher isSnapshotOf<V>({
  bool? isLoading,
  Object? value,
  Object? error,
  Source? source,
}) =>
    _ResourceStateMatcher<Object, V>(
        isLoading, null, value, error, source, true);

Matcher isStateOf<K extends Object, V>({
  bool? isLoading,
  Object? key,
  Object? value,
  Object? error,
  Source? source,
}) =>
    _ResourceStateMatcher<K, V>(isLoading, key, value, error, source, true);

Matcher isStateWhere({
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

  bool _isValidState(StateSnapshot item, Map matchState) {
    final isValidLoading = isLoading == null || item.isLoading == isLoading;
    final isValidKey = keyMatcher == null ||
        (item is ResourceState &&
            wrapMatcher(keyMatcher).matches(item.key, matchState));
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
        keyMatcher == null && !isStrictType && item is StateSnapshot;
    final isTypedSnapshot =
        keyMatcher == null && isStrictType && item is StateSnapshot<V>;

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
    if (isStrictType) {
      description.add('ResourceState<$K,$V>(');
    } else {
      description.add('ResourceState(');
    }

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
