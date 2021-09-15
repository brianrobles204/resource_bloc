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

    test('can load from truth source cache', () {});

    test('restarts any in-progress loading', () {});

    test('triggers a fresh reload after error, if key is different', () {});

    test('during truth source read cancels truth source, reloads', () {
      //
    });

    test('during truth source write cancels truth source, reloads', () {});
  });
}
