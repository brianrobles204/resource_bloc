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

    BehaviorSubject<bool> freshValueLocked = BehaviorSubject.seeded(false);
    BehaviorSubject<bool> truthReadLocked = BehaviorSubject.seeded(false);
    BehaviorSubject<bool> truthWriteLocked = BehaviorSubject.seeded(false);
    bool isUnlocked(bool isLocked) => !isLocked;

    BehaviorSubject<Object?> freshValueThrowable = BehaviorSubject.seeded(null);
    BehaviorSubject<Object?> truthReadThrowable = BehaviorSubject.seeded(null);
    BehaviorSubject<Object?> truthWriteThrowable = BehaviorSubject.seeded(null);

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
        if (freshValueLocked.value) {
          await freshValueLocked.firstWhere(isUnlocked);
        }
        if (freshValueThrowable.value != null) {
          throw freshValueThrowable.value!;
        }
        yield createFreshValue(key);
      };
    }

    StreamSink<String Function(String)> streamFreshSource() {
      final sink = StreamController<String Function(String)>.broadcast();
      freshSource = (key) => sink.stream.map(
            (callback) => createFreshValue(key, content: callback(key)),
          );
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
            if (truthReadLocked.value) {
              await truthReadLocked.firstWhere(isUnlocked);
            }
            if (truthReadThrowable.value != null) {
              throw truthReadThrowable.value!;
            }
            yield* (truthDB[key] ??= BehaviorSubject());
          },
          writer: (key, value) async {
            truthWriteCount++;
            if (truthWriteLocked.value) {
              await truthWriteLocked.firstWhere(isUnlocked);
            }
            if (truthWriteThrowable.value != null) {
              throw truthWriteThrowable.value!;
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

      freshValueLocked.value = false;
      truthReadLocked.value = false;
      truthWriteLocked.value = false;

      freshValueThrowable.value = null;
      truthReadThrowable.value = null;
      truthWriteThrowable.value = null;

      currentContent = 'content';
      truthDB.clear();

      bloc = createBloc();
    });

    tearDown(() {
      bloc.close();
      truthDB.clear();
    });

    group('initial state', () {
      test('starts with initial state and no reads', () {
        expect(bloc.state, isInitialState);
        expect(freshReadCount, equals(0));
        expect(truthReadCount, equals(0));
        expect(truthWriteCount, equals(0));
      });

      test('without key does not change after value changing events', () async {
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

      test('reflects the initial key if provided', () {
        initialKey = 'first';
        setUpBloc();

        expect(bloc.state, isInitialLoadingState('first'));
        expect(freshReadCount, equals(0));
        expect(truthReadCount, equals(0));
        expect(truthWriteCount, equals(0));

        bloc.reload();

        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isInitialLoadingState('first'),
            isStateWith(isLoading: false, name: 'first', count: 1),
          ]),
        );
      });
    });

    group('initial value callback', () {
      test('returning null should emit loading state with no value', () {
        initialValue = (key) => null;
        initialKey = 'first';
        setUpBloc();

        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isInitialLoadingState('first'),
            isStateWith(isLoading: false, name: 'first', count: 1),
          ]),
        );

        bloc.reload();
      });

      test('returning non-null value should reflect in state', () async {
        initialValue = (key) => createFreshValue(key, content: '$key-loading');
        initialKey = 'first';
        setUpBloc();

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

        currentContent = 'first-ready';
        bloc.reload();
        await untilDone(bloc);

        currentContent = 'second-ready';
        bloc.key = 'second';
      });

      test('errors should be treated as if there\'s no value', () async {
        var shouldThrow = true;
        initialValue = (key) {
          if (shouldThrow) {
            throw StateError('initial value error');
          } else {
            return createFreshValue(key, content: '$key-loading');
          }
        };
        initialKey = 'first';
        setUpBloc();

        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isInitialLoadingState('first'),
            isStateWith(
                isLoading: false, name: 'first', content: 'first-ready'),
            isInitialLoadingState('second'),
            isStateWith(
                isLoading: false, name: 'second', content: 'second-ready'),
            isStateWith(
                isLoading: true, name: 'third', content: 'third-loading'),
            isStateWith(
                isLoading: false, name: 'third', content: 'third-ready'),
          ]),
        );

        currentContent = 'first-ready';
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

    group('.reload()', () {
      test('reloads the bloc', () async {
        initialKey = 'key';
        setUpBloc();

        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            // Reload the first time
            isInitialLoadingState('key'),
            isStateWith(isLoading: false, content: 'first'),
            // Reload the second time
            isStateWith(isLoading: true, content: 'first'),
            isStateWith(isLoading: false, content: 'second'),
            // Reload the third time
            isStateWith(isLoading: true, content: 'second'),
            isStateWith(isLoading: false, content: 'third'),
          ]),
        );

        // Reload the first time
        currentContent = 'first';
        bloc.reload();
        await untilDone(bloc);

        // Reload the second time
        currentContent = 'second';
        bloc.reload();
        await untilDone(bloc);

        // Reload the third time
        currentContent = 'third';
        bloc.reload();
      });

      test('after key error does nothing', () async {
        initialKey = 'key';
        setUpBloc();

        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isInitialLoadingState('key'),
            isStateWith(isLoading: false, content: 'first'),
            isKeyErrorState,
            emitsDone,
          ]),
        );

        // Reload normally
        currentContent = 'first';
        bloc.reload();
        await untilDone(bloc);

        // Add key error
        bloc.add(KeyError(StateError('test key error')));
        await pumpEventQueue();

        // Try reloading again
        bloc.reload();
        await pumpEventQueue();

        bloc.close();
      });

      test('while already reloading does nothing', () async {
        initialKey = 'key';
        setUpBloc();

        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isInitialLoadingState('key'),
            isStateWith(isLoading: false, content: 'first', count: 1),
            emitsDone,
          ]),
        );

        // Reload but pause during fresh read
        currentContent = 'first';
        freshValueLocked.value = true;
        bloc.reload();
        await pumpEventQueue();

        // Reload while fresh read is ongoing
        bloc.reload();
        await pumpEventQueue();
        freshValueLocked.value = false;

        await untilDone(bloc);
        bloc.close();
      });

      test('after first value in fresh stream starts a new load', () async {
        initialKey = 'first';
        setUpBloc();

        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            // Load from fresh source and emit two values
            isInitialLoadingState('first'),
            isStateWith(
                isLoading: false, content: 'first-a', source: Source.fresh),
            isStateWith(
                isLoading: false, content: 'first-b', source: Source.fresh),
            // Reload with different fresh source
            isStateWith(
                isLoading: true, content: 'first-b', source: Source.fresh),
            isStateWith(
                isLoading: false, content: 'first-x', source: Source.fresh),
          ]),
        );

        // Load from fresh source and emit two values
        final firstSink = streamFreshSource();
        bloc.reload();
        await pumpEventQueue();

        firstSink.add((key) => '$key-a');
        await pumpEventQueue();

        firstSink.add((key) => '$key-b');
        await untilDone(bloc);

        // Reload with different fresh source, and have old & new fresh source
        // emit different values. Only values from newer one should reflect.
        final secondSink = streamFreshSource();
        bloc.reload(); // Listening for second sink now
        await pumpEventQueue();

        firstSink.add((key) => '$key-c');
        await pumpEventQueue();

        secondSink.add((key) => '$key-x');
        await pumpEventQueue();
      });

      test('after error starts a new load', () async {
        initialKey = 'first';
        setUpBloc();

        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            // Load but immediately throw error
            isInitialLoadingState('first'),
            isStateWhere(
                isLoading: false,
                key: 'first',
                error: isStateError,
                value: isNull),
            // Reload and complete successfully
            isStateWhere(
                isLoading: true,
                key: 'first',
                error: isStateError,
                value: isNull),
            isStateWith(
                isLoading: false,
                key: 'first',
                content: 'success',
                error: isNull),
          ]),
        );

        // Load but immediately throw error
        currentContent = 'success';
        freshValueThrowable.value = StateError('test error');
        bloc.reload();
        await untilDone(bloc);

        // Reload and complete successfully
        freshValueThrowable.value = null;
        bloc.reload();
      });

      test('during truth source read waits then starts a new load', () async {
        initialKey = 'first';
        setUpBloc();

        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isInitialLoadingState('first'),
            // Should emit first value then immediately reload
            isStateWith(
                isLoading: false, content: 'x', count: 1, source: Source.fresh),
            isStateWith(
                isLoading: true, content: 'x', count: 1, source: Source.fresh),
            isStateWith(
                isLoading: false, content: 'y', count: 2, source: Source.fresh),
          ]),
        );

        // Load but pause once truth source read is reached
        currentContent = 'x';
        truthReadLocked.value = true;
        bloc.reload();
        await pumpEventQueue();

        expect(bloc.state, isInitialLoadingState('first'));

        // Reload while truth source read is ongoing
        currentContent = 'y';
        bloc.reload();
        await pumpEventQueue();

        expect(bloc.state, isInitialLoadingState('first'));

        // Allow truth source read to finish
        truthReadLocked.value = false;
        await pumpEventQueue();
      });

      test('during truth source write waits then starts a new load', () async {
        initialKey = 'first';
        setUpBloc();

        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isInitialLoadingState('first'),
            // Should emit first value then immediately reload
            isStateWith(
                isLoading: false, content: 'x', count: 1, source: Source.fresh),
            isStateWith(
                isLoading: true, content: 'x', count: 1, source: Source.fresh),
            isStateWith(
                isLoading: false, content: 'y', count: 2, source: Source.fresh),
          ]),
        );

        // Load but pause once truth source write is reached
        currentContent = 'x';
        truthWriteLocked.value = true;
        bloc.reload();
        await pumpEventQueue();

        expect(bloc.state, isInitialLoadingState('first'));

        // Reload while truth source write is ongoing
        currentContent = 'y';
        bloc.reload();
        await pumpEventQueue();

        expect(bloc.state, isInitialLoadingState('first'));

        // Allow truth source write to finish
        truthWriteLocked.value = false;
        await pumpEventQueue();
      });
    });

    group('value updates', () {
      test('without key is unsupported & does nothing', () async {
        expectLater(bloc.stream, emitsDone);

        // Add value update manually during initial state, with no key yet
        expect(bloc.state, isInitialState);
        bloc.add(ValueUpdate('key', createFreshValue('key')));
        await pumpEventQueue();

        expect(bloc.state, isInitialState);
        await bloc.close();
      });

      test('with key error is unsupported and does nothing', () async {
        initialKey = 'key';
        setUpBloc();

        // Add key error
        bloc.add(KeyError(StateError('test error')));
        await pumpEventQueue();

        expectLater(bloc.stream, emitsDone);
        expect(bloc.state, isKeyErrorState);

        // Add value update manually, after key error
        bloc.add(ValueUpdate('key', createFreshValue('key')));
        await pumpEventQueue();

        expect(bloc.state, isKeyErrorState);
        await bloc.close();
      });

      test('after error is unsupported and does nothing', () async {
        initialKey = 'key';
        setUpBloc();

        // Load but immediately throw on fresh read
        freshValueThrowable.value = StateError('test error');
        bloc.reload();
        await pumpEventQueue();

        expectLater(bloc.stream, emitsDone);

        final isErrorState = isStateWhere(
            isLoading: false, key: 'key', error: isStateError, value: isNull);

        expect(bloc.state, isErrorState);

        // Add value update manually after error
        bloc.add(ValueUpdate('key', createFreshValue('key')));
        await pumpEventQueue();

        expect(bloc.state, isErrorState);
        bloc.close();
      });

      test('with non-matching key does nothing', () async {
        initialKey = 'first';
        setUpBloc();

        // Reload normally first
        bloc.reload();
        await untilDone(bloc);

        expectLater(bloc.stream, emitsDone);

        final isValueState = isStateWith(
            key: 'first', isLoading: false, name: 'first', count: 1);

        expect(bloc.state, isValueState);

        // Add value update manually, but with wrong key
        bloc.add(ValueUpdate('second', createFreshValue('second')));
        await pumpEventQueue();

        expect(bloc.state, isValueState);
        bloc.close();
      });

      test('are ignored during initial fresh read only', () async {
        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            // Try updating during initial fresh read, should do nothing
            isInitialLoadingState('key'),
            isStateWith(isLoading: false, content: 'first'),
            // Try updated during subsequent fresh read, should reflect
            isStateWith(isLoading: true, content: 'first'),
            isStateWith(isLoading: false, content: 'second'),
            isStateWith(isLoading: false, content: 'insert-2'),
            isStateWith(isLoading: false, content: 'third'),
            emitsDone,
          ]),
        );

        // Load but pause during fresh read
        currentContent = 'first';
        freshValueLocked.value = true;
        bloc.key = 'key';
        await pumpEventQueue();

        // Add value update manually during initial fresh read
        bloc.add(
            ValueUpdate('key', createFreshValue('key', content: 'insert-1')));
        await pumpEventQueue();

        expect(bloc.state, isInitialLoadingState('key'));
        freshValueLocked.value = false;
        await untilDone(bloc);

        // Try updating during subsequent fresh read
        final freshSink = streamFreshSource();
        bloc.reload();
        await pumpEventQueue();
        freshSink.add((key) => 'second');
        await pumpEventQueue();

        expect(bloc.state, isStateWith(isLoading: false, content: 'second'));

        // Add value update manually during subsequent fresh read
        bloc.add(
            ValueUpdate('key', createFreshValue('key', content: 'insert-2')));
        await pumpEventQueue();

        expect(bloc.state, isStateWith(isLoading: false, content: 'insert-2'));

        freshSink.add((key) => 'third');
        await untilDone(bloc);

        bloc.close();
      });

      test('during truth read waits then updates with newer value', () async {
        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isInitialLoadingState('key'),
            isStateWith(isLoading: false, content: 'first'),
            isStateWith(isLoading: false, content: 'second'),
            emitsDone,
          ]),
        );

        // Load but pause during truth read
        currentContent = 'first';
        truthReadLocked.value = true;
        bloc.key = 'key';
        await pumpEventQueue();

        // Add value update manually during truth read
        bloc.add(
            ValueUpdate('key', createFreshValue('key', content: 'second')));
        await pumpEventQueue();

        expect(bloc.state, isInitialLoadingState('key'));
        truthReadLocked.value = false;
        await untilDone(bloc);
        await untilDone(bloc); // second await for second value

        bloc.close();
      });

      test('during truth write waits then updates with newer value', () async {
        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isInitialLoadingState('key'),
            isStateWith(isLoading: false, content: 'first'),
            isStateWith(isLoading: false, content: 'second'),
            emitsDone,
          ]),
        );

        // Load but pause during truth write
        currentContent = 'first';
        truthWriteLocked.value = true;
        bloc.key = 'key';
        await pumpEventQueue();

        // Add value update manually during truth write
        bloc.add(
            ValueUpdate('key', createFreshValue('key', content: 'second')));
        await pumpEventQueue();

        expect(bloc.state, isInitialLoadingState('key'));
        truthWriteLocked.value = false;
        await untilDone(bloc);
        await untilDone(bloc); // second await for second value

        bloc.close();
      });
    });

    group('error updates', () {
      test('during reload do not erase existing data', () async {
        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isInitialLoadingState('key'),
            isStateWith(isLoading: false, content: 'key-a', count: 1),
            // reload but throw on read
            isStateWith(isLoading: true, content: 'key-a', count: 1),
            isStateWhere(
                isLoading: false,
                value: isValueWith(content: 'key-a', count: 1),
                error: isStateError),
            // reload, return successfully but then emit an error
            isStateWhere(
                isLoading: true,
                value: isValueWith(content: 'key-a', count: 1),
                source: Source.fresh,
                error: isStateError),
            isStateWhere(
                isLoading: true,
                value: isValueWith(content: 'key-a', count: 1),
                source: Source.cache,
                error: isStateError),
            isStateWith(
                isLoading: false, content: 'key-b', count: 3, error: isNull),
            isStateWith(
                isLoading: false, content: 'key-c', count: 3, error: isNull),
            isStateWhere(
                isLoading: false,
                value: isValueWith(content: 'key-c', count: 3),
                error: isStateError),
          ]),
        );

        var freshSink = streamFreshSource();

        bloc.key = 'key';
        await pumpEventQueue();
        freshSink.add((key) => '$key-a');
        await pumpEventQueue();

        // reload, but throw on read
        bloc.reload();
        await pumpEventQueue();
        freshSink.add((key) => throw StateError('error'));
        await pumpEventQueue();

        // reload, return successfully, but then emit an error
        bloc.reload();
        await pumpEventQueue();
        freshSink.add((key) => '$key-b');
        await pumpEventQueue();
        freshSink.add((key) => '$key-c');
        await pumpEventQueue();
        freshSink.add((key) => throw StateError('error 2'));
      });

      test('during set-up of truth source reflect in the state', () async {
        initialKey = 'key';
        truthDB['key'] = BehaviorSubject()..addError(StateError('error'));
        setUpBloc();

        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            // No initial loading state, starts with error due to truth source
            isStateWhere(isLoading: false, error: isStateError, value: isNull),
            emitsDone,
          ]),
        );

        await pumpEventQueue();
        bloc.close();
      });

      test('from truth source while loading fresh reflect in state', () async {
        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isInitialLoadingState('key'),
            isStateWhere(isLoading: false, error: isStateError, value: isNull),
            emitsDone,
          ]),
        );

        // Load, but pause on fresh read
        freshValueLocked.value = true;
        bloc.key = 'key';
        await pumpEventQueue();

        expect(bloc.state, isInitialLoadingState('key'));

        // Emit error from truth source before fresh source has finished
        truthDB['key']!.addError(StateError('error'));
        await untilDone(bloc);

        freshValueLocked.value = false;
        await pumpEventQueue();

        bloc.close();
      });

      test('during later truth read reflect in state, erase values', () async {
        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isInitialLoadingState('key'),
            isStateWhere(
                isLoading: false,
                value: isValueWith(name: 'key', content: 'first', count: 1),
                error: isNull),
            // Emit value from truth source after fresh read has finished
            isStateWhere(
                isLoading: false,
                value: isValueWith(name: 'key', content: 'second', count: 1),
                error: isNull),
            // Emit error from truth source
            isStateWhere(isLoading: false, error: isStateError, value: isNull),
          ]),
        );

        currentContent = 'first';
        bloc.key = 'key';
        await untilDone(bloc);

        // Emit value from truth source after fresh read has finished
        truthDB['key']!.add(createFreshValue('key', content: 'second'));
        await untilDone(bloc);

        // Emit error from truth source
        truthDB['key']!.addError(StateError('error'));
      });

      test('during truth write reflect in state, erasing values', () async {
        currentContent = 'first';

        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isInitialLoadingState('key'),
            // Initial error on first write
            isStateWhere(isLoading: false, error: isStateError, value: isNull),
            // Reload, complete successfully, then error on next reload / write
            isStateWhere(isLoading: true, error: isStateError, value: isNull),
            isStateWhere(
                isLoading: false,
                value: isValueWith(name: 'key', content: 'first', count: 2),
                error: isNull),
            isStateWhere(
                isLoading: true,
                value: isValueWith(name: 'key', content: 'first', count: 2),
                error: isNull),
            isStateWhere(isLoading: false, error: isStateError, value: isNull),
          ]),
        );

        // Initial error on first write
        truthWriteThrowable.value = StateError('error');
        bloc.key = 'key';
        await untilDone(bloc);

        // Reload, complete successfully, then error on next reload / write
        truthWriteThrowable.value = null;
        bloc.reload();
        await untilDone(bloc);

        currentContent = 'second';
        truthWriteThrowable.value = StateError('error');
        bloc.reload();
      });

      test('cancel further fresh or truth updates', () async {
        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isInitialLoadingState('key'),
            isStateWhere(
                isLoading: false,
                value: isValueWith(name: 'key', content: 'key-a', count: 1),
                error: isNull),
            // Add error manually
            isStateWhere(
                isLoading: false,
                value: isValueWith(name: 'key', content: 'key-a', count: 1),
                error: isStateError),
            emitsDone,
          ]),
        );

        final freshSink = streamFreshSource();

        bloc.key = 'key';
        await pumpEventQueue();
        freshSink.add((key) => '$key-a');
        await untilDone(bloc);

        // Add error manually
        bloc.add(ErrorUpdate(StateError('error'), isValueValid: true));
        await pumpEventQueue();

        // Emit from fresh and truth sources. Should have no effect on bloc
        freshSink.add((key) => '$key-b');
        await pumpEventQueue();

        truthDB['key']!.value = createFreshValue('key', content: 'other');
        await pumpEventQueue();

        bloc.close();
      });
    });

    group('truth source updates', () {
      test('can emit before reload is called', () async {
        initialKey = 'key';
        setUpBloc();

        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isStateWith(
                isLoading: false, content: 'first', source: Source.fresh),
            isStateWith(
                isLoading: true, content: 'first', source: Source.fresh),
            isStateWith(
                isLoading: false, content: 'second', source: Source.fresh),
          ]),
        );

        await pumpEventQueue();
        expect(truthDB['key'], isNotNull,
            reason: 'Bloc should be listening to truth source on init, '
                'if initial key is given');

        // Emit value from truth source before reload or key update
        truthDB['key']!.value = createFreshValue('key', content: 'first');
        await untilDone(bloc);

        currentContent = 'second';
        bloc.reload();
      });

      test('from seeded truth source can be initial value of bloc', () {
        truthDB['key'] =
            BehaviorSubject.seeded(createFreshValue('key', content: 'seeded'));
        initialKey = 'key';
        setUpBloc();

        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            // No initial loading state, first state is the seeded value
            isStateWith(
                isLoading: false, content: 'seeded', source: Source.fresh),
            isStateWith(
                isLoading: true, content: 'seeded', source: Source.fresh),
            isStateWith(
                isLoading: false, content: 'fresh', source: Source.fresh),
          ]),
        );

        currentContent = 'fresh';
        bloc.reload();
      });

      test('after key update can come from seeded stream, tagged as cache', () {
        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isInitialLoadingState('key'),
            isStateWith(
                isLoading: true, content: 'seeded', source: Source.cache),
            isStateWith(
                isLoading: false, content: 'fresh', source: Source.fresh),
          ]),
        );

        truthDB['key'] =
            BehaviorSubject.seeded(createFreshValue('key', content: 'seeded'));
        currentContent = 'fresh';
        bloc.key = 'key';
      });

      test('after error can come from seeded stream', () async {
        initialKey = 'key';
        setUpBloc();

        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            // Load but immediately throw error
            isInitialLoadingState('key'),
            isStateWhere(isLoading: false, error: isStateError, value: isNull),
            // Reload with seeded truth value and complete successfully
            isStateWhere(isLoading: true, error: isStateError, value: isNull),
            isStateWith(
                isLoading: true,
                content: 'seeded',
                source: Source.cache,
                error: isStateError),
            isStateWith(
                isLoading: false,
                content: 'success',
                source: Source.fresh,
                error: isNull),
          ]),
        );

        // Load but immediately throw error
        currentContent = 'success';
        freshValueThrowable.value = StateError('test error');
        bloc.reload();
        await untilDone(bloc);

        // Reload with seeded truth value and complete successfully
        truthDB['key']!.value = createFreshValue('key', content: 'seeded');
        freshValueThrowable.value = null;
        bloc.reload();
      });

      test('can emit while fresh source is loading, tagged as cache', () async {
        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isInitialLoadingState('key'),
            // Emit from truth source before fresh source emits
            isStateWhere(
                isLoading: true,
                value: isValueWith(content: 'loading', count: 1),
                source: Source.cache),
            isStateWhere(
                isLoading: false,
                value: isValueWith(content: 'first', count: 1),
                source: Source.fresh),
            // Subsequent emits from direct truth then fresh source.
            isStateWhere(
                isLoading: false,
                value: isValueWith(content: 'fromTruth', count: 1),
                source: Source.fresh),
            isStateWhere(
                isLoading: false,
                value: isValueWith(content: 'second', count: 1),
                source: Source.fresh),
          ]),
        );

        // Emit from truth source before fresh source emits
        final freshSink = streamFreshSource();
        bloc.key = 'key';
        await pumpEventQueue();

        truthDB['key']!.value = createFreshValue('key', content: 'loading');
        await pumpEventQueue();

        freshSink.add((key) => 'first');
        await pumpEventQueue();

        // Subsequent emits from direct truth then fresh source.
        truthDB['key']!.value = createFreshValue('key', content: 'fromTruth');
        await pumpEventQueue();

        freshSink.add((key) => 'second');
      });

      test('during truth source write will emit both values after', () async {
        expectLater(
          bloc.stream,
          emitsInOrder(<dynamic>[
            isInitialLoadingState('key'),
            // New true value then actual fresh value are emitted in succession
            // Since we cannot distinguish between them without potentially
            // strict equality checks, both are tagged fresh
            isStateWith(
                isLoading: false, content: 'truth-1', source: Source.fresh),
            isStateWith(
                isLoading: false, content: 'fresh-1', source: Source.fresh),
          ]),
        );

        currentContent = 'fresh-1';
        truthWriteLocked.value = true;
        bloc.key = 'key';
        await pumpEventQueue();

        expect(bloc.state, isInitialLoadingState('key'));

        // Emit new true value while first is still being written
        truthDB['key']!.value = createFreshValue('key', content: 'truth-1');
        await pumpEventQueue();

        truthWriteLocked.value = false;
      });
    });

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

Matcher isInitialLoadingState(String key) =>
    equals(ResourceState<String, _Value>.loading(key));

final Matcher isKeyErrorState = isStateWhere(
    isLoading: false, key: isNull, value: isNull, error: isStateError);

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
