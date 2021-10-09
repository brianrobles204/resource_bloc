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
    Object? keyMatcher,
    Object? valueMatcher,
    Object? errorMatcher,
    this.source,
    this.isStrictType,
  )   : keyMatcher = keyMatcher != null ? wrapMatcher(keyMatcher) : null,
        valueMatcher = valueMatcher != null ? wrapMatcher(valueMatcher) : null,
        errorMatcher = errorMatcher != null ? wrapMatcher(errorMatcher) : null;

  final bool? isLoading;
  final Matcher? keyMatcher;
  final Matcher? valueMatcher;
  final Matcher? errorMatcher;
  final Source? source;
  final bool isStrictType;

  bool get _isSnapshotMatcher => (keyMatcher == null || keyMatcher == isNull);

  bool _isValidState(StateSnapshot item, Map matchState) {
    final keyState = {}, valueState = {}, errorState = {};

    final isValidLoading = isLoading == null || item.isLoading == isLoading;
    final isValidResourceKey = keyMatcher == null ||
        (item is ResourceState && keyMatcher!.matches(item.key, keyState));
    final isValidSnapshotKey = _isSnapshotMatcher && item is! ResourceState;
    final isValidKey = isValidResourceKey || isValidSnapshotKey;
    final isValidValue =
        valueMatcher == null || valueMatcher!.matches(item.value, valueState);
    final isValidError =
        errorMatcher == null || errorMatcher!.matches(item.error, errorState);
    final isValidSource =
        source == null || (item.hasValue && item.requireSource == source);

    addStateInfo(matchState, {
      'loadingMismatch': !isValidLoading,
      'keyMismatch': !isValidKey,
      'valueMismatch': !isValidValue,
      'errorMismatch': !isValidError,
      'sourceMismatch': !isValidSource,
      'keyState': keyState,
      'valueState': valueState,
      'errorState': errorState,
    });

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
      addStateInfo(matchState, {'typeMismatch': true});
      return false;
    }
  }

  String get _typeDescription {
    final classPart = _isSnapshotMatcher ? 'StateSnapshot' : 'ResourceState';

    final genericText = _isSnapshotMatcher ? '<$V>' : '<$K, $V>';
    final genericPart = isStrictType ? genericText : '';

    return '$classPart$genericPart';
  }

  @override
  Description describe(Description description) {
    description.add('$_typeDescription(');

    void addAll(Iterable<Iterable<Object?>> lines) {
      var shouldSeparate = false;
      for (final line in lines) {
        if (shouldSeparate) {
          description.add(', ');
        }
        for (final value in line) {
          if (value is String) {
            description.add(value);
          } else {
            description.addDescriptionOf(value);
          }
        }
        shouldSeparate = true;
      }
    }

    addAll([
      if (isLoading != null) ['isLoading=', isLoading],
      if (keyMatcher != null) ['key=', keyMatcher],
      if (valueMatcher != null) ['value=', valueMatcher],
      if (source != null) ['source=<$source>'],
      if (errorMatcher != null) ['error=', errorMatcher],
    ]);

    description.add(')');

    return description;
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if ((matchState['typeMismatch'] ?? false)) {
      return mismatchDescription.add('is not an instance of $_typeDescription');
    }

    item as StateSnapshot;

    final mismatches = [
      'loadingMismatch',
      'keyMismatch',
      'valueMismatch',
      'errorMismatch',
      'sourceMismatch',
    ];

    final mismatchCount =
        mismatches.where((mismatch) => matchState[mismatch]).length;
    var count = 0;
    var hadLoadingMismatch = false;
    void add({
      required String ifFirst,
      String? ifSucceeding,
      String? ifLast,
      String? ifLastAfterLoading,
    }) {
      if (count == 0) {
        mismatchDescription.add(ifFirst);
      } else if (count < mismatchCount - 1) {
        mismatchDescription.add(ifSucceeding ?? ifLast ?? ifFirst);
      } else if (hadLoadingMismatch && count == 1) {
        mismatchDescription
            .add(ifLastAfterLoading ?? ifLast ?? ifSucceeding ?? ifFirst);
      } else {
        mismatchDescription.add(ifLast ?? ifSucceeding ?? ifFirst);
      }
      count++;
    }

    if (matchState['loadingMismatch'] ?? false) {
      add(ifFirst: item.isLoading ? 'is loading' : 'is not loading');
      hadLoadingMismatch = true;
    }

    void addMismatchedDescription(
      Matcher matcher,
      dynamic itemProp,
      Map matchState,
    ) {
      final description = matcher
          .describeMismatch(itemProp, StringDescription(), matchState, verbose)
          .toString();
      if (description.isEmpty) {
        mismatchDescription.add('is ').addDescriptionOf(itemProp);
      } else {
        mismatchDescription.add(description);
      }
    }

    if (matchState['keyMismatch'] ?? false) {
      item as ResourceState;
      add(
        ifFirst: 'has a key that ',
        ifSucceeding: ', with a key which ',
        ifLast: ', and a key which ',
        ifLastAfterLoading: ' with a key which ',
      );
      addMismatchedDescription(keyMatcher!, item.key, matchState['keyState']);
    }

    if (matchState['valueMismatch'] ?? false) {
      add(
        ifFirst: 'has a value that ',
        ifSucceeding: ', with a value which ',
        ifLast: ', and a value which ',
        ifLastAfterLoading: ' with a value which ',
      );
      addMismatchedDescription(
          valueMatcher!, item.value, matchState['valueState']);
    }

    if (matchState['errorMismatch'] ?? false) {
      add(
        ifFirst: 'has an error that ',
        ifSucceeding: ', with an error which ',
        ifLast: ', and an error which ',
        ifLastAfterLoading: ' with an error which ',
      );
      addMismatchedDescription(
          errorMatcher!, item.error, matchState['errorState']);
    }

    if (matchState['sourceMismatch'] ?? false) {
      switch (item.source) {
        case Source.fresh:
        case Source.cache:
          final source =
              item.source == Source.fresh ? 'fresh source' : 'cache source';
          add(
            ifFirst: 'has a $source',
            ifLast: ', and a $source',
            ifLastAfterLoading: ' with a $source',
          );
          break;
        case null:
          add(
            ifFirst: 'has no source',
            ifLast: ', and no source',
            ifLastAfterLoading: ' with no source',
          );
          break;
      }
    }

    return mismatchDescription;
  }
}
