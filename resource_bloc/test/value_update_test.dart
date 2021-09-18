import 'package:resource_bloc/resource_bloc.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('value updates', () {
    late TestResourceBloc bloc;

    setUp(() {
      bloc = TestResourceBloc();
    });

    tearDown(() {
      bloc.close();
    });

    test('without key is unsupported & does nothing', () async {
      expectLater(bloc.stream, emitsDone);

      // Add value update manually during initial state, with no key yet
      expect(bloc.state, isInitialEmptyState);
      bloc.add(ValueUpdate('key', bloc.createFreshValue('key')));
      await pumpEventQueue();

      expect(bloc.state, isInitialEmptyState);
      await bloc.close();
    });

    test('with key error is unsupported and does nothing', () async {
      bloc = TestResourceBloc(initialKey: 'key');

      // Add key error
      bloc.add(KeyError(StateError('test error')));
      await pumpEventQueue();

      expectLater(bloc.stream, emitsDone);
      expect(bloc.state, isKeyErrorState);

      // Add value update manually, after key error
      bloc.add(ValueUpdate('key', bloc.createFreshValue('key')));
      await pumpEventQueue();

      expect(bloc.state, isKeyErrorState);
      await bloc.close();
    });

    test('after error is unsupported and does nothing', () async {
      bloc = TestResourceBloc(initialKey: 'key');

      // Load but immediately throw on fresh read
      bloc.freshValueThrowable = StateError('test error');
      bloc.reload();
      await pumpEventQueue();

      expectLater(bloc.stream, emitsDone);

      final isErrorState = isStateWhere(
          isLoading: false, key: 'key', error: isStateError, value: isNull);

      expect(bloc.state, isErrorState);

      // Add value update manually after error
      bloc.add(ValueUpdate('key', bloc.createFreshValue('key')));
      await pumpEventQueue();

      expect(bloc.state, isErrorState);
      bloc.close();
    });

    test('with non-matching key does nothing', () async {
      bloc = TestResourceBloc(initialKey: 'first');

      // Reload normally first
      bloc.reload();
      await untilDone(bloc);

      expectLater(bloc.stream, emitsDone);

      final isValueState =
          isStateWith(key: 'first', isLoading: false, name: 'first', count: 1);

      expect(bloc.state, isValueState);

      // Add value update manually, but with wrong key
      bloc.add(ValueUpdate('second', bloc.createFreshValue('second')));
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
      bloc.freshContent = 'first';
      bloc.freshValueLocked.value = true;
      bloc.key = 'key';
      await pumpEventQueue();

      // Add value update manually during initial fresh read
      bloc.add(
        ValueUpdate('key', bloc.createFreshValue('key', content: 'insert-1')),
      );
      await pumpEventQueue();

      expect(bloc.state, isInitialLoadingState('key'));
      bloc.freshValueLocked.value = false;
      await untilDone(bloc);

      // Try updating during subsequent fresh read
      final freshSink = bloc.applyStreamFreshSource();
      bloc.reload();
      await pumpEventQueue();
      freshSink.add((key) => 'second');
      await pumpEventQueue();

      expect(bloc.state, isStateWith(isLoading: false, content: 'second'));

      // Add value update manually during subsequent fresh read
      bloc.add(
        ValueUpdate('key', bloc.createFreshValue('key', content: 'insert-2')),
      );
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
      bloc.freshContent = 'first';
      bloc.truthReadLocked.value = true;
      bloc.key = 'key';
      await pumpEventQueue();

      // Add value update manually during truth read
      bloc.add(
        ValueUpdate('key', bloc.createFreshValue('key', content: 'second')),
      );
      await pumpEventQueue();

      expect(bloc.state, isInitialLoadingState('key'));
      bloc.truthReadLocked.value = false;
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
      bloc.freshContent = 'first';
      bloc.truthWriteLocked.value = true;
      bloc.key = 'key';
      await pumpEventQueue();

      // Add value update manually during truth write
      bloc.add(
        ValueUpdate('key', bloc.createFreshValue('key', content: 'second')),
      );
      await pumpEventQueue();

      expect(bloc.state, isInitialLoadingState('key'));
      bloc.truthWriteLocked.value = false;
      await untilDone(bloc);
      await untilDone(bloc); // second await for second value

      bloc.close();
    });
  });
}
