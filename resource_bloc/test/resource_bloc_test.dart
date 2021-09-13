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
    var currentContent = 'content';
    final truthDB = <String, BehaviorSubject<Result<_Value>>>{};

    _Value createFreshValue(String key, [String? content]) =>
        _Value(key, content ?? currentContent, freshReadCount++);

    void valueFreshSource() {
      freshSource = (key) => Stream.value(createFreshValue(key));
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

      return ResourceBloc.from(
        initialKey: initialKey,
        initialValue: initialValue,
        freshSource: (key) => freshSource!(key),
        truthSource: TruthSource.from(
          reader: (key) {
            truthReadCount++;
            return truthDB[key] ??= BehaviorSubject();
          },
          writer: (key, value, date) async {
            truthWriteCount++;
            (truthDB[key] ??= BehaviorSubject()).value = Result(value, date);
          },
        ),
      );
    }

    late ResourceBloc<String, _Value> bloc;

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
      currentContent = 'content';
      truthDB.clear();
      bloc = createBloc();
    });

    tearDown(() {
      bloc.close();
      truthDB.clear();
    });

    test('starts with initial state and no reads', () {
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
          isStateWith(isLoading: false, name: 'first', count: 0),
        ]),
      );
    });

    test('.reload() without a key does nothing', () async {
      // ignore: unawaited_futures
      expectLater(bloc.stream, emitsDone);

      bloc.reload();
      await pumpEventQueue();

      await bloc.close();
      expect(bloc.state, isInitialState);
      expect(freshReadCount, equals(0));
      expect(truthReadCount, equals(0));
      expect(truthWriteCount, equals(0));
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
      await untilDone(bloc.stream);

      currentContent = 'second';
      bloc.reload();

      await untilDone(bloc.stream);

      currentContent = 'third';
      bloc.reload();
    });

    test('null initial values should return loading state', () {});

    test('non-null initial values should reflect in state', () {});

    test('errors in initial values should be ignored', () {});

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

class _Value {
  _Value(this.name, this.content, this.count);

  final String name;
  final String content;
  final int count;
}

Future<void> untilDone(Stream<ResourceState> stream) =>
    stream.firstWhere((state) => !state.isLoading);

final Matcher isInitialState = equals(ResourceState<String, _Value>.initial());

Matcher isStateWith({
  bool? isLoading,
  Object? key,
  String? name,
  String? content,
  int? count,
  Object? error,
  Source? source,
  DateTime? date,
}) =>
    isStateWhere(
      isLoading: isLoading,
      key: key,
      value: (name != null || content != null || count != null)
          ? isValueWith(name: name, content: content, count: count)
          : null,
      error: error,
      source: source,
      date: date,
    );

Matcher isStateWhere({
  bool? isLoading,
  Object? key,
  Object? value,
  Object? error,
  Source? source,
  DateTime? date,
}) =>
    _ResourceStateMatcher(isLoading, key, value, error, source, date);

class _ResourceStateMatcher extends Matcher {
  _ResourceStateMatcher(
    this.isLoading,
    this.keyMatcher,
    this.valueMatcher,
    this.errorMatcher,
    this.source,
    this.date,
  );

  final bool? isLoading;
  final Object? keyMatcher;
  final Object? valueMatcher;
  final Object? errorMatcher;
  final Source? source;
  final DateTime? date;

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
      final isValidSource = source == null ||
          (item.hasValue && item.requireInfo.source == source);
      final isValidDate =
          date == null || (item.hasValue && item.requireInfo.date == date);

      return isValidLoading &&
          isValidKey &&
          isValidValue &&
          isValidError &&
          isValidSource &&
          isValidDate;
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

    description.add('Resource State ');

    if (isLoading != null) {
      description.add(isLoading! ? 'is loading' : 'not loading');
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

    if (source != null || date != null) {
      separate();
      description.add('having value ');

      if (source != null) {
        description.add('with source $source');
      }

      if (date != null) {
        if (source != null) separate();
        description.add('with date $date');
      }
    }

    if (errorMatcher != null) {
      separate();
      description.addDescriptionOf(errorMatcher);
    }

    return description;
  }
}

Matcher isValueWith({
  String? name,
  String? content,
  int? count,
}) =>
    predicate(
      (value) {
        bool isValidValue(_Value value) {
          final isValidName = name == null || value.name == name;
          final isValidContent = content == null || value.content == content;
          final isValidCount = count == null || value.count == count;
          return isValidName && isValidContent && isValidCount;
        }

        if (value is _Value) {
          return isValidValue(value);
        } else if (value is ResourceState<String, _Value>) {
          return value.hasValue && isValidValue(value.requireValue);
        } else {
          return false;
        }
      },
      'Value ' +
          [
            if (name != null) 'with name of $name',
            if (content != null) 'with content of $content',
            if (count != null) 'with count of $count',
          ].join(', '),
    );
