import 'package:resource_bloc/resource_bloc.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('key updates', () {
    late TestResourceBloc bloc;

    setUp(() {
      bloc = TestResourceBloc();
    });

    tearDown(() {
      bloc.close();
    });

    test('do nothing if key is the same', () async {
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isInitialLoadingState('key'),
          isStateWith(isLoading: false, name: 'key', count: 1),
          emitsDone,
        ]),
      );

      bloc.key = 'key';
      await pumpEventQueue();

      bloc.key = 'key';
      await pumpEventQueue();

      bloc.close();
    });

    test('trigger a fresh reload if key is different', () async {
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isInitialLoadingState('first'),
          isStateWith(isLoading: false, name: 'first', content: 'a', count: 1),
          isInitialLoadingState('second'),
          isStateWith(isLoading: false, name: 'second', content: 'b', count: 2),
          emitsDone,
        ]),
      );

      bloc.freshContent = 'a';
      bloc.key = 'first';
      await untilDone(bloc);

      bloc.freshContent = 'b';
      bloc.key = 'second';
      await untilDone(bloc);

      bloc.close();
    });

    test('can recover from key errors to different key', () async {
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isInitialLoadingState('first'),
          isStateWith(isLoading: false, name: 'first', content: 'a', count: 1),
          isKeyErrorState,
          isInitialLoadingState('second'),
          isStateWith(isLoading: false, name: 'second', content: 'b', count: 2),
          emitsDone,
        ]),
      );

      bloc.freshContent = 'a';
      bloc.key = 'first';
      await untilDone(bloc);

      bloc.add(KeyError(StateError('error')));
      await pumpEventQueue();

      bloc.freshContent = 'b';
      bloc.key = 'second';
      await untilDone(bloc);

      bloc.close();
    });

    test('can recover from key errors to same prior key', () async {
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isInitialLoadingState('first'),
          isStateWhere(
              isLoading: false,
              value: isValueWith(name: 'first', content: 'a', count: 1),
              source: Source.fresh),
          isKeyErrorState,
          isInitialLoadingState('first'),
          isStateWhere(
              isLoading: true,
              value: isValueWith(name: 'first', content: 'a', count: 1),
              source: Source.cache),
          isStateWhere(
              isLoading: false,
              value: isValueWith(name: 'first', content: 'b', count: 2),
              source: Source.fresh),
          emitsDone,
        ]),
      );

      bloc.freshContent = 'a';
      bloc.key = 'first';
      await untilDone(bloc);

      bloc.add(KeyError(StateError('error')));
      await pumpEventQueue();

      bloc.freshContent = 'b';
      bloc.key = 'first';
      await untilDone(bloc);

      bloc.close();
    });

    test('can load from truth source cache', () async {
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isInitialLoadingState('first'),
          isStateWith(isLoading: true, content: 'c-1', source: Source.cache),
          isStateWith(isLoading: false, content: 'f-1', source: Source.fresh),
          isInitialLoadingState('second'),
          isStateWith(isLoading: true, content: 'c-2', source: Source.cache),
          isStateWith(isLoading: false, content: 'f-2', source: Source.fresh),
        ]),
      );

      bloc.freshContent = 'f-1';
      bloc.getTruthSource('first').value =
          bloc.createFreshValue('first', content: 'c-1');
      bloc.key = 'first';
      await untilDone(bloc);

      bloc.freshContent = 'f-2';
      bloc.getTruthSource('second').value =
          bloc.createFreshValue('second', content: 'c-2');
      bloc.key = 'second';
    });

    test('restarts any in-progress loading', () async {
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          // Change key in the middle of fresh content read
          isInitialLoadingState('first'),
          isInitialLoadingState('second'),
          isStateWith(isLoading: false, name: 'second', content: 'second-x'),
        ]),
      );

      final firstSink = bloc.applyStreamFreshSource();
      bloc.key = 'first';
      await pumpEventQueue();

      final secondSink = bloc.applyStreamFreshSource();
      bloc.key = 'second';
      await pumpEventQueue();

      firstSink.add((key) => '$key-a');
      await pumpEventQueue();

      secondSink.add((key) => '$key-x');
      await pumpEventQueue();
    });

    test('triggers a fresh reload after error, if key is different', () async {
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          // Load with error
          isInitialLoadingState('first'),
          isStateWhere(isLoading: false, error: isStateError, value: isNull),
          // Reload when key changes
          isInitialLoadingState('second'),
          isStateWith(isLoading: false, error: isNull, count: 2),
        ]),
      );

      bloc.freshValueThrowable = StateError('error');
      bloc.key = 'first';
      await untilDone(bloc);

      bloc.freshValueThrowable = null;
      bloc.key = 'second';
    });

    test('during truth source read cancels truth source, reloads', () async {
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          // Load but pause during truth source read
          isInitialLoadingState('first'),
          // Reload due to key change, first value not emitted
          isInitialLoadingState('second'),
          isStateWith(isLoading: false, content: 'new', count: 2),
          emitsDone,
        ]),
      );

      // Load but pause during truth source read
      bloc.truthReadLocked.value = true;
      bloc.freshContent = 'old';
      bloc.key = 'first';
      await pumpEventQueue();

      expect(bloc.state, isInitialLoadingState('first'));

      // Reload due to key change, first value not emitted
      bloc.freshContent = 'new';
      bloc.key = 'second';
      await pumpEventQueue();

      bloc.truthReadLocked.value = false;
      await pumpEventQueue();

      bloc.close();
    });

    test('during truth source write cancels truth source, reloads', () async {
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          // Load but pause during truth source write
          isInitialLoadingState('first'),
          // Reload due to key change, first value not emitted
          isInitialLoadingState('second'),
          isStateWith(isLoading: false, content: 'new', count: 2),
          emitsDone,
        ]),
      );

      // Load but pause during truth source write
      bloc.truthWriteLocked.value = true;
      bloc.freshContent = 'old';
      bloc.key = 'first';
      await pumpEventQueue();

      expect(bloc.state, isInitialLoadingState('first'));

      // Reload due to key change, first value not emitted
      bloc.freshContent = 'new';
      bloc.key = 'second';
      await pumpEventQueue();

      bloc.truthWriteLocked.value = false;
      await pumpEventQueue();

      bloc.close();
    });
  });
}
