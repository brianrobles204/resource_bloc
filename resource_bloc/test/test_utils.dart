import 'dart:async';

import 'package:resource_bloc/resource_bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

class TestAction extends ResourceAction {
  TestAction(
    this.index, {
    required this.loading,
    required this.done,
    this.lock,
    this.throwable,
  });

  final int index;
  final String loading;
  final String done;
  final BehaviorSubject<bool>? lock;
  final Object? throwable;

  @override
  List<Object?> get props => [index, loading, done, lock, throwable];
}

class TestResourceBloc extends ResourceBloc<String, Value> {
  TestResourceBloc({
    InitialValue<String, Value>? initialValue,
    String? initialKey,
    Map<String, BehaviorSubject<Value>>? truthSources,
  })  : truthSources = truthSources ?? {},
        super(
          initialValue: initialValue,
          initialKey: initialKey,
        ) {
    onAction<TestAction>(_onTestAction);
  }

  var freshContent = 'content';
  FreshSource<String, Value>? freshSource;

  late final Map<String, BehaviorSubject<Value>> truthSources;

  var freshReadCount = 0;
  var truthReadCount = 0;
  var truthWriteCount = 0;
  var actionStartCount = 0;
  var actionFinishCount = 0;

  final freshValueLocked = BehaviorSubject<bool>.seeded(false);
  final truthReadLocked = BehaviorSubject<bool>.seeded(false);
  final truthWriteLocked = BehaviorSubject<bool>.seeded(false);

  Object? freshValueThrowable;
  Object? truthReadThrowable;
  Object? truthWriteThrowable;

  Value createFreshValue(
    String key, {
    int? count,
    String? content,
    Map<int, String>? action,
  }) =>
      Value(key, count ?? freshReadCount,
          content: content ?? freshContent, action: action ?? {});

  bool _isUnlocked(bool isLocked) => !isLocked;

  void applyValueFreshSource() {
    freshSource = (key) async* {
      if (freshValueLocked.value) {
        await freshValueLocked.firstWhere(_isUnlocked);
      }
      if (freshValueThrowable != null) {
        throw freshValueThrowable!;
      }
      yield createFreshValue(key);
    };
  }

  StreamSink<String Function(String)> applyStreamFreshSource() {
    final sink = StreamController<String Function(String)>.broadcast();
    freshSource = (key) => sink.stream.map(
          (callback) => createFreshValue(key, content: callback(key)),
        );
    return sink;
  }

  BehaviorSubject<Value> getTruthSource(String key) =>
      (truthSources[key] ??= BehaviorSubject());

  @override
  Stream<Value> readFreshSource(String key) {
    freshReadCount++;

    if (freshSource == null) applyValueFreshSource();

    return freshSource!(key);
  }

  @override
  Stream<Value> readTruthSource(String key) async* {
    truthReadCount++;
    if (truthReadLocked.value) {
      await truthReadLocked.firstWhere(_isUnlocked);
    }
    if (truthReadThrowable != null) {
      throw truthReadThrowable!;
    }
    yield* (truthSources[key] ??= BehaviorSubject());
  }

  @override
  Future<void> writeTruthSource(String key, Value value) async {
    truthWriteCount++;
    if (truthWriteLocked.value) {
      await truthWriteLocked.firstWhere(_isUnlocked);
    }
    if (truthWriteThrowable != null) {
      throw truthWriteThrowable!;
    }
    (truthSources[key] ??= BehaviorSubject()).value = value;
  }

  FutureOr<void> _onTestAction(
    TestAction action,
    ActionEmitter<Value> emit,
  ) async {
    actionStartCount++;
    await emit(
      (value) => value.copyWithAction(action.index, action.loading),
    );
    if (action.lock != null) {
      await action.lock!.firstWhere(_isUnlocked);
    }
    if (action.throwable != null) {
      throw action.throwable!;
    }
    await emit(
      (value) => value.copyWithAction(action.index, action.done),
    );
    actionFinishCount++;
  }

  @override
  Future<void> close() {
    truthSources.clear();
    return super.close();
  }
}

class Value {
  Value(
    this.name,
    this.count, {
    required this.content,
    required this.action,
  });

  final String name;
  final int count;
  final String content;
  final Map<int, String> action;

  Value copyWith({
    String? name,
    int? count,
    String? content,
    Map<int, String>? action,
  }) =>
      Value(
        name ?? this.name,
        count ?? this.count,
        content: content ?? this.content,
        action: action ?? this.action,
      );

  Value copyWithAction(int index, String action) =>
      copyWith(action: {...this.action, index: action});

  @override
  String toString() =>
      '_Value(name=$name, count=$count, content=$content, action=$action)';
}

Future<void> untilDone(ResourceBloc bloc) =>
    bloc.stream.firstWhere((state) => !state.isLoading);

final Matcher isInitialEmptyState =
    equals(ResourceState<String, Value>.initial(null, isLoading: false));

Matcher isInitialLoadingState(String key, {bool isLoading = true}) =>
    equals(ResourceState<String, Value>.initial(key, isLoading: isLoading));

final Matcher isKeyErrorState = isStateWhere(
    isLoading: false, key: isNull, value: isNull, error: isStateError);

Matcher isStateWith({
  bool? isLoading,
  Object? key,
  String? name,
  String? content,
  int? count,
  Object? action,
  Object? error,
  Source? source,
}) =>
    isStateWhere(
      isLoading: isLoading,
      key: key,
      value: [name, content, count, action].any((e) => e != null)
          ? isValueWith(
              name: name,
              content: content,
              count: count,
              action: action,
            )
          : null,
      error: error,
      source: source,
    );

Matcher isStateWhere({
  bool? isLoading,
  Object? key,
  Object? value,
  Object? error,
  Source? source,
}) =>
    _ResourceStateMatcher(isLoading, key, value, error, source);

class _ResourceStateMatcher extends Matcher {
  _ResourceStateMatcher(
    this.isLoading,
    this.keyMatcher,
    this.valueMatcher,
    this.errorMatcher,
    this.source,
  );

  final bool? isLoading;
  final Object? keyMatcher;
  final Object? valueMatcher;
  final Object? errorMatcher;
  final Source? source;

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is ResourceState<String, Value>) {
      final isValidLoading = isLoading == null || item.isLoading == isLoading;
      final isValidKey = keyMatcher == null ||
          wrapMatcher(keyMatcher).matches(item.key, matchState);
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
    } else {
      return false;
    }
  }

  @override
  Description describe(Description description) {
    var needsSeparator = false;
    void separate() {
      if (needsSeparator) description.add(', ');
      needsSeparator = true;
    }

    description.add('ResourceState(');

    if (isLoading != null) {
      description.add('isLoading=$isLoading');
      needsSeparator = true;
    }

    if (keyMatcher != null) {
      separate();
      description.add('key matches ').addDescriptionOf(keyMatcher);
    }

    if (valueMatcher != null) {
      separate();
      description.add('value matches ').addDescriptionOf(valueMatcher);
    }

    if (source != null) {
      separate();
      description.add('with source $source');
    }

    if (errorMatcher != null) {
      separate();
      description.addDescriptionOf(errorMatcher);
    }

    description.add(')');

    return description;
  }
}

Matcher isValueWith({
  String? name,
  String? content,
  int? count,
  Object? action,
}) =>
    _ValueMatcher(name, content, count, action);

class _ValueMatcher extends Matcher {
  _ValueMatcher(this.name, this.content, this.count, this.action);

  final String? name;
  final String? content;
  final int? count;
  final Object? action;

  @override
  bool matches(item, Map matchState) {
    bool isValidValue(Value value) {
      final isValidName = name == null || value.name == name;
      final isValidContent = content == null || value.content == content;
      final isValidCount = count == null || value.count == count;
      final isValidAction = action == null ||
          wrapMatcher(action).matches(value.action, matchState);
      return isValidName && isValidContent && isValidCount && isValidAction;
    }

    if (item is Value) {
      return isValidValue(item);
    } else if (item is ResourceState<String, Value>) {
      return item.hasValue && isValidValue(item.requireValue);
    } else {
      return false;
    }
  }

  @override
  Description describe(Description description) {
    return description.addAll('Value(', ', ', ')', [
      if (name != null) 'name=$name',
      if (content != null) 'content=$content',
      if (count != null) 'count=$count',
      if (action != null) wrapMatcher(action),
    ]);
  }
}
