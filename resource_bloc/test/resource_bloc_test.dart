import 'dart:async';

import 'package:resource_bloc/resource_bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

void main() {
  group('Resource Bloc', () {
    var freshReadCount = 0;
    var truthReadCount = 0;
    var truthWriteCount = 0;

    String? initialKey;
    InitialValue<String, _Value>? initialValue;
    FreshSource<String, _Value>? freshSource;

    Duration? freshValueDelay;
    Duration? truthReadDelay;
    Duration? truthWriteDelay;

    var currentContent = 'content';
    final truthDB = <String, BehaviorSubject<_Value>>{};

    late ResourceBloc<String, _Value> bloc;

    _Value createFreshValue(
      String key, {
      int? count,
      String? content,
      String? action,
    }) =>
        _Value(key, count ?? freshReadCount,
            content: content ?? currentContent, action: action);

    void valueFreshSource() {
      freshSource = (key) async* {
        if (freshValueDelay != null) {
          await Future<void>.delayed(freshValueDelay!);
        }
        yield createFreshValue(key);
      };
    }

    StreamSink<_Value> streamFreshSource() {
      final sink = BehaviorSubject<_Value>();
      freshSource = (key) => sink;
      return sink;
    }

    ResourceBloc<String, _Value> createBloc() {
      if (freshSource == null) {
        valueFreshSource();
      }

      return _TestResourceBloc(
        initialKey: initialKey,
        initialValue: initialValue,
        freshSource: (key) {
          freshReadCount++;
          return freshSource!(key);
        },
        truthSource: TruthSource.from(
          reader: (key) async* {
            truthReadCount++;
            if (truthReadDelay != null) {
              await Future<void>.delayed(truthReadDelay!);
            }
            yield* (truthDB[key] ??= BehaviorSubject());
          },
          writer: (key, value) async {
            truthWriteCount++;
            if (truthWriteDelay != null) {
              await Future<void>.delayed(truthWriteDelay!);
            }
            (truthDB[key] ??= BehaviorSubject()).value = value;
          },
        ),
      );
    }

    /// Replace the current bloc with a newly created bloc.
    ///
    /// This is useful if the initial arguments for the bloc have changed and
    /// the bloc needs to be recreated for the changes to have an effect.
    void setUpBloc() {
      bloc.close();
      bloc = createBloc();
    }

    setUp(() {
      freshReadCount = 0;
      truthReadCount = 0;
      truthWriteCount = 0;

      initialKey = null;
      initialValue = null;
      freshSource = null;

      freshValueDelay = null;
      truthReadDelay = null;
      truthWriteDelay = null;

      currentContent = 'content';
      truthDB.clear();

      bloc = createBloc();
    });

    tearDown(() {
      bloc.close();
      truthDB.clear();
    });

    group('initial conditions:', () {
      test('starts with initial state and no reads', () {
        expect(bloc.state, isInitialState);
        expect(freshReadCount, equals(0));
        expect(truthReadCount, equals(0));
        expect(truthWriteCount, equals(0));
      });

      test('value changing events without a key do nothing', () async {
        // ignore: unawaited_futures
        expectLater(bloc.stream, emitsDone);

        bloc.reload();
        await pumpEventQueue();

        bloc.add(ValueUpdate('key', createFreshValue('key')));
        await pumpEventQueue();

        bloc.add(_TestAction(activeAction: 'active', doneAction: 'done'));
        await pumpEventQueue();

        await bloc.close();

        expect(bloc.state, isInitialState);
        expect(freshReadCount, equals(0));
        expect(truthReadCount, equals(0));
        expect(truthWriteCount, equals(0));
      });

      test('setting the initial key reflects in the initial state', () {
        initialKey = 'first';
        setUpBloc();

        final isInitialLoadingState =
            isStateWhere(key: 'first', isLoading: true, value: isNull);

        expect(bloc.state, isInitialLoadingState);
        expect(freshReadCount, equals(0));
        expect(truthReadCount, equals(0));
        expect(truthWriteCount, equals(0));

        bloc.reload();

        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isInitialLoadingState,
            isStateWith(isLoading: false, name: 'first', count: 1),
          ]),
        );
      });
    });

    group('initial values:', () {
      test('null result should emit loading state with no value', () {
        initialValue = (key) => null;
        initialKey = 'first';
        setUpBloc();

        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isStateWhere(key: 'first', isLoading: true, value: isNull),
            isStateWith(isLoading: false, name: 'first', count: 1),
          ]),
        );

        bloc.reload();
      });

      test('non-null result should reflect in state', () async {
        initialValue = (key) => createFreshValue(key, content: '$key-loading');
        initialKey = 'first';
        currentContent = 'first-ready';
        setUpBloc();

        // ignore: unawaited_futures
        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isStateWith(
                isLoading: true, name: 'first', content: 'first-loading'),
            isStateWith(
                isLoading: false, name: 'first', content: 'first-ready'),
            isStateWith(
                isLoading: true, name: 'second', content: 'second-loading'),
            isStateWith(
                isLoading: false, name: 'second', content: 'second-ready'),
          ]),
        );

        bloc.reload();
        await untilDone(bloc);

        currentContent = 'second-ready';
        bloc.key = 'second';
      });

      test('errors in initial values should be ignored', () async {
        var shouldThrow = true;
        initialValue = (key) {
          if (shouldThrow) {
            throw StateError('initial value error');
          } else {
            return createFreshValue(key, content: '$key-loading');
          }
        };
        currentContent = 'first-ready';
        initialKey = 'first';
        setUpBloc();

        // ignore: unawaited_futures
        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isStateWhere(isLoading: true, key: 'first', value: isNull),
            isStateWith(
                isLoading: false, name: 'first', content: 'first-ready'),
            isStateWhere(isLoading: true, key: 'second', value: isNull),
            isStateWith(
                isLoading: false, name: 'second', content: 'second-ready'),
            isStateWith(
                isLoading: true, name: 'third', content: 'third-loading'),
            isStateWith(
                isLoading: false, name: 'third', content: 'third-ready'),
          ]),
        );

        bloc.reload();
        await untilDone(bloc);

        currentContent = 'second-ready';
        bloc.key = 'second';
        await untilDone(bloc);

        shouldThrow = false;
        currentContent = 'third-ready';
        bloc.key = 'third';
      });
    });

    test('.reload() reloads the bloc', () async {
      initialKey = 'key';
      currentContent = 'first';
      setUpBloc();

      // ignore: unawaited_futures
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isStateWhere(isLoading: true, key: 'key', value: isNull),
          isStateWith(isLoading: false, content: 'first'),
          isStateWith(isLoading: true, content: 'first'),
          isStateWith(isLoading: false, content: 'second'),
          isStateWith(isLoading: true, content: 'second'),
          isStateWith(isLoading: false, content: 'third'),
        ]),
      );

      bloc.reload();
      await untilDone(bloc);

      currentContent = 'second';
      bloc.reload();

      await untilDone(bloc);

      currentContent = 'third';
      bloc.reload();
    });

    test('passes fresh source errors to the state', () {});

    test('passes truth source errors to the state', () {});

    test('error updates do not erase existing data', () {});

    test('handles changes in keys', () {});

    test('passes key errors to the state', () {});

    test('key errors overwrite existing data with an error', () {});

    test('key errors can recover to the same prior key', () {});

    test('key errors stop loading', () {});
  });
}

class _TestAction extends ResourceAction {
  _TestAction({
    required this.activeAction,
    required this.doneAction,
    this.loadDelay,
  });

  final String activeAction;
  final String doneAction;
  final Duration? loadDelay;

  @override
  List<Object?> get props => [activeAction, doneAction];
}

class _TestResourceBloc extends CallbackResourceBloc<String, _Value> {
  _TestResourceBloc({
    required FreshSource<String, _Value> freshSource,
    required TruthSource<String, _Value> truthSource,
    InitialValue<String, _Value>? initialValue,
    String? initialKey,
  }) : super(
          freshSource: freshSource,
          truthSource: truthSource,
          initialValue: initialValue,
          initialKey: initialKey,
        );

  @override
  Stream<_Value> mapActionToValue(ResourceAction action) async* {
    if (action is _TestAction) {
      yield* mappedValue(
          (value) => value.copyWith(action: action.activeAction));
      if (action.loadDelay != null) {
        await Future<void>.delayed(action.loadDelay!);
      }
      yield* mappedValue((value) => value.copyWith(action: action.doneAction));
    }
  }
}

class _Value {
  _Value(
    this.name,
    this.count, {
    required this.content,
    required this.action,
  });

  final String name;
  final int count;
  final String content;
  final String? action;

  static const _kPreserveField = r'_$PRESERVE_FIELD';

  _Value copyWith({
    String? name,
    int? count,
    String? content,
    String? action = _kPreserveField,
  }) =>
      _Value(
        name ?? this.name,
        count ?? this.count,
        content: content ?? this.content,
        action: action != _kPreserveField ? action : this.action,
      );

  @override
  String toString() =>
      '_Value(name=$name, count=$count, content=$content, action=$action)';
}

Future<void> untilDone(ResourceBloc bloc) =>
    bloc.stream.firstWhere((state) => !state.isLoading);

final Matcher isInitialState = equals(ResourceState<String, _Value>.initial());

Matcher isStateWith({
  bool? isLoading,
  Object? key,
  String? name,
  String? content,
  int? count,
  Object? error,
  Source? source,
}) =>
    isStateWhere(
      isLoading: isLoading,
      key: key,
      value: (name != null || content != null || count != null)
          ? isValueWith(name: name, content: content, count: count)
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
    if (item is ResourceState<String, _Value>) {
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
    bool isValidValue(_Value value) {
      final isValidName = name == null || value.name == name;
      final isValidContent = content == null || value.content == content;
      final isValidCount = count == null || value.count == count;
      final isValidAction = action == null ||
          wrapMatcher(action).matches(value.action, matchState);
      return isValidName && isValidContent && isValidCount && isValidAction;
    }

    if (item is _Value) {
      return isValidValue(item);
    } else if (item is ResourceState<String, _Value>) {
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
