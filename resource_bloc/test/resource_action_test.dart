import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('resource actions', () {
    late TestResourceBloc bloc;

    setUp(() {
      bloc = TestResourceBloc();
    });

    tearDown(() {
      bloc.close();
    });

    Value createFreshValue(
      String key, {
      int? count,
      String? content,
      Map<int, String>? action,
    }) =>
        Value(key, count ?? bloc.freshReadCount,
            content: content ?? bloc.freshContent, action: action ?? {});

    test('work after fresh load', () async {
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isInitialLoadingState('key'),
          isStateWith(isLoading: false, count: 1, action: isEmpty),
          isStateWith(isLoading: false, count: 1, action: {0: 'loading'}),
          isStateWith(isLoading: false, count: 1, action: {0: 'done'}),
        ]),
      );

      bloc.key = 'key';
      await untilDone(bloc);

      bloc.add(TestAction(0, loading: 'loading', done: 'done'));
    });

    test('work concurrently', () async {
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isInitialLoadingState('key'),
          isStateWith(isLoading: false, action: isEmpty),
          // Intersperse loading and done
          isStateWith(isLoading: false, action: {0: 'load-a'}),
          isStateWith(isLoading: false, action: {0: 'load-a', 1: 'load-b'}),
          isStateWith(isLoading: false, action: {0: 'done-a', 1: 'load-b'}),
          isStateWith(isLoading: false, action: {0: 'done-a', 1: 'done-b'}),
          // Finish load of one completely while another is loading
          isStateWith(isLoading: false, action: {0: 'load-c', 1: 'done-b'}),
          isStateWith(isLoading: false, action: {0: 'load-c', 1: 'load-d'}),
          isStateWith(isLoading: false, action: {0: 'load-c', 1: 'done-d'}),
          isStateWith(isLoading: false, action: {0: 'done-c', 1: 'done-d'}),
        ]),
      );

      bloc.key = 'key';
      await untilDone(bloc);

      final aLock = BehaviorSubject.seeded(true);
      bloc.add(TestAction(0, loading: 'load-a', done: 'done-a', lock: aLock));
      await pumpEventQueue();

      final bLock = BehaviorSubject.seeded(true);
      bloc.add(TestAction(1, loading: 'load-b', done: 'done-b', lock: bLock));
      await pumpEventQueue();

      aLock.value = false;
      await pumpEventQueue();

      bLock.value = false;
      await pumpEventQueue();

      final cLock = BehaviorSubject.seeded(true);
      bloc.add(TestAction(0, loading: 'load-c', done: 'done-c', lock: cLock));
      await pumpEventQueue();

      final dLock = BehaviorSubject.seeded(true);
      bloc.add(TestAction(1, loading: 'load-d', done: 'done-d', lock: dLock));
      await pumpEventQueue();

      dLock.value = false;
      await pumpEventQueue();

      cLock.value = false;
      await pumpEventQueue();
    });

    test('will use initial value', () async {
      bloc = TestResourceBloc(
        initialKey: 'key',
        initialValue: (key) => createFreshValue(key, content: '$key-init'),
      );

      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          // Adding a resource action should work using initial value
          isStateWith(
              isLoading: false, content: 'key-init', action: {0: 'loading'}),
          isStateWith(
              isLoading: false, content: 'key-init', action: {0: 'done'}),
          emitsDone,
        ]),
      );

      await pumpEventQueue();
      expect(
        bloc.state,
        isStateWith(
            isLoading: false, key: 'key', content: 'key-init', action: isEmpty),
      );

      bloc.add(TestAction(0, loading: 'loading', done: 'done'));
      await pumpEventQueue();

      bloc.close();
    });

    test('will use cached truth value', () async {
      bloc = TestResourceBloc(initialKey: 'key');

      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          // Adding a resource action should work using cached truth value
          isStateWith(isLoading: false, content: 'cache', action: isEmpty),
          isStateWith(
              isLoading: false, content: 'cache', action: {0: 'loading'}),
          isStateWith(isLoading: false, content: 'cache', action: {0: 'done'}),
          emitsDone,
        ]),
      );

      bloc.getTruthSource('key').value =
          bloc.createFreshValue('key', content: 'cache');
      await pumpEventQueue();

      bloc.add(TestAction(0, loading: 'loading', done: 'done'));
      await pumpEventQueue();

      bloc.close();
    });

    test('will wait until after reload before acting', () {});

    test('will wait until after truth read before acting', () {});

    test('will wait until after truth write before acting', () {});

    test('have no effect after error', () {});

    test('have no effect after key error', () {});

    test('errors are passed to state', () {});

    test('that emit during truth read will reflect after first value', () {});

    test('that emit during truth write will reflect after first value', () {});
  });
}
