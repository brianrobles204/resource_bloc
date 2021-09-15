import 'package:resource_bloc/resource_bloc.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('.reload()', () {
    late TestResourceBloc bloc;

    setUp(() {
      bloc = TestResourceBloc();
    });

    tearDown(() {
      bloc.close();
    });

    test('reloads the bloc', () async {
      bloc = TestResourceBloc(initialKey: 'key');

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
      bloc.freshContent = 'first';
      bloc.reload();
      await untilDone(bloc);

      // Reload the second time
      bloc.freshContent = 'second';
      bloc.reload();
      await untilDone(bloc);

      // Reload the third time
      bloc.freshContent = 'third';
      bloc.reload();
    });

    test('after key error does nothing', () async {
      bloc = TestResourceBloc(initialKey: 'key');

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
      bloc.freshContent = 'first';
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
      bloc = TestResourceBloc(initialKey: 'key');

      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isInitialLoadingState('key'),
          isStateWith(isLoading: false, content: 'first', count: 1),
          emitsDone,
        ]),
      );

      // Reload but pause during fresh read
      bloc.freshContent = 'first';
      bloc.freshValueLocked.value = true;
      bloc.reload();
      await pumpEventQueue();

      // Reload while fresh read is ongoing
      bloc.reload();
      await pumpEventQueue();
      bloc.freshValueLocked.value = false;

      await untilDone(bloc);
      bloc.close();
    });

    test('after first value in fresh stream starts a new load', () async {
      bloc = TestResourceBloc(initialKey: 'first');

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
      final firstSink = bloc.applyStreamFreshSource();
      bloc.reload();
      await pumpEventQueue();

      firstSink.add((key) => '$key-a');
      await pumpEventQueue();

      firstSink.add((key) => '$key-b');
      await untilDone(bloc);

      // Reload with different fresh source, and have old & new fresh source
      // emit different values. Only values from newer one should reflect.
      final secondSink = bloc.applyStreamFreshSource();
      bloc.reload(); // Listening for second sink now
      await pumpEventQueue();

      firstSink.add((key) => '$key-c');
      await pumpEventQueue();

      secondSink.add((key) => '$key-x');
      await pumpEventQueue();
    });

    test('after error starts a new load', () async {
      bloc = TestResourceBloc(initialKey: 'first');

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
      bloc.freshContent = 'success';
      bloc.freshValueThrowable = StateError('test error');
      bloc.reload();
      await untilDone(bloc);

      // Reload and complete successfully
      bloc.freshValueThrowable = null;
      bloc.reload();
    });

    test('during truth source read waits then starts a new load', () async {
      bloc = TestResourceBloc(initialKey: 'key');

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
      bloc.freshContent = 'x';
      bloc.truthReadLocked.value = true;
      bloc.reload();
      await pumpEventQueue();

      expect(bloc.state, isInitialLoadingState('first'));

      // Reload while truth source read is ongoing
      bloc.freshContent = 'y';
      bloc.reload();
      await pumpEventQueue();

      expect(bloc.state, isInitialLoadingState('first'));

      // Allow truth source read to finish
      bloc.truthReadLocked.value = false;
      await pumpEventQueue();
    });

    test('during truth source write waits then starts a new load', () async {
      bloc = TestResourceBloc(initialKey: 'key');

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
      bloc.freshContent = 'x';
      bloc.truthWriteLocked.value = true;
      bloc.reload();
      await pumpEventQueue();

      expect(bloc.state, isInitialLoadingState('first'));

      // Reload while truth source write is ongoing
      bloc.freshContent = 'y';
      bloc.reload();
      await pumpEventQueue();

      expect(bloc.state, isInitialLoadingState('first'));

      // Allow truth source write to finish
      bloc.truthWriteLocked.value = false;
      await pumpEventQueue();
    });
  });
}
