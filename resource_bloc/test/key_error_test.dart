import 'package:resource_bloc/src/resource_event.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('key errors', () {
    late TestResourceBloc bloc;

    setUp(() {
      bloc = TestResourceBloc();
    });

    tearDown(() {
      bloc.close();
    });

    test('can happen during bloc initialization', () async {
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isKeyErrorState,
          emitsDone,
        ]),
      );

      bloc.add(KeyError(StateError('error')));
      await pumpEventQueue();

      bloc.close();
    });

    test('overwrite existing data with an error', () async {
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isInitialLoadingState('key'),
          isStateWith(isLoading: false, content: 'a', error: isNull),
          isStateWhere(isLoading: false, value: isNull, error: isStateError),
        ]),
      );

      bloc.freshContent = 'a';
      bloc.key = 'key';
      await untilDone(bloc);

      bloc.add(KeyError(StateError('error')));
    });

    test('after errors are still reflected', () async {
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isInitialLoadingState('key'),
          isStateWhere(
              isLoading: false, value: isNull, error: isFormatException),
          isStateWhere(isLoading: false, value: isNull, error: isStateError),
        ]),
      );

      bloc.freshValueThrowable = FormatException();
      bloc.key = 'key';
      await untilDone(bloc);

      bloc.add(KeyError(StateError('error')));
    });

    test('stop all loading including further fresh / truth updates', () async {
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isInitialLoadingState('key'),
          isStateWith(isLoading: false, content: 'key-x', error: isNull),
          isKeyErrorState,
          emitsDone,
        ]),
      );

      final freshSink = bloc.applyStreamFreshSource();
      bloc.key = 'key';
      await pumpEventQueue();

      freshSink.add((key) => '$key-x');
      await pumpEventQueue();

      bloc.add(KeyError(StateError('error')));
      await pumpEventQueue();

      // Update fresh and truth source after key error, should do nothing
      freshSink.add((key) => '$key-y');
      await pumpEventQueue();

      bloc.getTruthSource('key').value =
          bloc.createFreshValue('key', content: 'truth');
      await pumpEventQueue();

      freshSink.addError(FormatException());
      await pumpEventQueue();

      bloc.getTruthSource('key').addError(Exception());
      await pumpEventQueue();

      bloc.close();
    });

    test('stop all loading even during reload', () async {
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isInitialLoadingState('key'),
          isKeyErrorState,
          emitsDone,
        ]),
      );

      bloc.freshValueLocked.value = true;
      bloc.key = 'key';
      await pumpEventQueue();

      bloc.add(KeyError(StateError('error')));
      await pumpEventQueue();

      bloc.freshValueLocked.value = false;
      await pumpEventQueue();

      bloc.close();
    });

    test('stop all loading even during truth read', () async {
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isInitialLoadingState('key'),
          isKeyErrorState,
          emitsDone,
        ]),
      );

      bloc.truthReadLocked.value = true;
      bloc.key = 'key';
      await pumpEventQueue();

      bloc.add(KeyError(StateError('error')));
      await pumpEventQueue();

      bloc.truthReadLocked.value = false;
      await pumpEventQueue();

      bloc.close();
    });

    test('stop all loading even during truth write', () async {
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isInitialLoadingState('key'),
          isKeyErrorState,
          emitsDone,
        ]),
      );

      bloc.truthWriteLocked.value = true;
      bloc.key = 'key';
      await pumpEventQueue();

      bloc.add(KeyError(StateError('error')));
      await pumpEventQueue();

      bloc.truthWriteLocked.value = false;
      await pumpEventQueue();

      bloc.close();
    });
  });
}
