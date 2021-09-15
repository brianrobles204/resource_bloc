import 'package:resource_bloc/resource_bloc.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('error updates', () {
    late TestResourceBloc bloc;

    setUp(() {
      bloc = TestResourceBloc();
    });

    tearDown(() {
      bloc.close();
    });

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

      var freshSink = bloc.applyStreamFreshSource();

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
      bloc = TestResourceBloc(initialKey: 'key');
      bloc.getTruthSource('key').addError(StateError('error'));

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
      bloc.freshValueLocked.value = true;
      bloc.key = 'key';
      await pumpEventQueue();

      expect(bloc.state, isInitialLoadingState('key'));

      // Emit error from truth source before fresh source has finished
      bloc.getTruthSource('key').addError(StateError('error'));
      await untilDone(bloc);

      bloc.freshValueLocked.value = false;
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

      bloc.freshContent = 'first';
      bloc.key = 'key';
      await untilDone(bloc);

      // Emit value from truth source after fresh read has finished
      bloc
          .getTruthSource('key')
          .add(bloc.createFreshValue('key', content: 'second'));
      await untilDone(bloc);

      // Emit error from truth source
      bloc.getTruthSource('key').addError(StateError('error'));
    });

    test('during truth write reflect in state, erasing values', () async {
      bloc.freshContent = 'first';

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
      bloc.truthWriteThrowable = StateError('error');
      bloc.key = 'key';
      await untilDone(bloc);

      // Reload, complete successfully, then error on next reload / write
      bloc.truthWriteThrowable = null;
      bloc.reload();
      await untilDone(bloc);

      bloc.freshContent = 'second';
      bloc.truthWriteThrowable = StateError('error');
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

      final freshSink = bloc.applyStreamFreshSource();

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

      bloc.getTruthSource('key').value =
          bloc.createFreshValue('key', content: 'other');
      await pumpEventQueue();

      bloc.close();
    });
  });
}
