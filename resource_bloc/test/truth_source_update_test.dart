import 'package:resource_bloc/resource_bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('truth source updates', () {
    late TestResourceBloc bloc;

    setUp(() {
      bloc = TestResourceBloc();
    });

    tearDown(() {
      bloc.close();
    });

    test('can emit before reload is called', () async {
      bloc = TestResourceBloc(initialKey: 'key');

      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isStateWith(isLoading: false, content: 'first', source: Source.fresh),
          isStateWith(isLoading: true, content: 'first', source: Source.fresh),
          isStateWith(
              isLoading: false, content: 'second', source: Source.fresh),
        ]),
      );

      await pumpEventQueue();

      // Emit value from truth source before reload or key update
      bloc.getTruthSource('key').value =
          bloc.createFreshValue('key', content: 'first');
      await untilDone(bloc);

      bloc.freshContent = 'second';
      bloc.reload();
    });

    test('from seeded truth source can be initial value of bloc', () {
      bloc = TestResourceBloc(initialKey: 'key')
        ..truthSources['key'] = BehaviorSubject.seeded(
          bloc.createFreshValue('key', content: 'seeded'),
        );

      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          // No initial loading state, first state is the seeded value
          isStateWith(
              isLoading: false, content: 'seeded', source: Source.fresh),
          isStateWith(isLoading: true, content: 'seeded', source: Source.fresh),
          isStateWith(isLoading: false, content: 'fresh', source: Source.fresh),
        ]),
      );

      bloc.freshContent = 'fresh';
      bloc.reload();
    });

    test('after key update can come from seeded stream, tagged as cache', () {
      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isInitialLoadingState('key'),
          isStateWith(isLoading: true, content: 'seeded', source: Source.cache),
          isStateWith(isLoading: false, content: 'fresh', source: Source.fresh),
        ]),
      );

      bloc.truthSources['key'] = BehaviorSubject.seeded(
        bloc.createFreshValue('key', content: 'seeded'),
      );
      bloc.freshContent = 'fresh';
      bloc.key = 'key';
    });

    test('after error can come from seeded stream', () async {
      bloc = TestResourceBloc(initialKey: 'key');

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
      bloc.freshContent = 'success';
      bloc.freshValueThrowable = StateError('test error');
      bloc.reload();
      await untilDone(bloc);

      // Reload with seeded truth value and complete successfully
      bloc.getTruthSource('key').value =
          bloc.createFreshValue('key', content: 'seeded');
      bloc.freshValueThrowable = null;
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
      final freshSink = bloc.applyStreamFreshSource();
      bloc.key = 'key';
      await pumpEventQueue();

      bloc.getTruthSource('key').value =
          bloc.createFreshValue('key', content: 'loading');
      await pumpEventQueue();

      freshSink.add((key) => 'first');
      await pumpEventQueue();

      // Subsequent emits from direct truth then fresh source.
      bloc.getTruthSource('key').value =
          bloc.createFreshValue('key', content: 'fromTruth');
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

      bloc.freshContent = 'fresh-1';
      bloc.truthWriteLocked.value = true;
      bloc.key = 'key';
      await pumpEventQueue();

      expect(bloc.state, isInitialLoadingState('key'));

      // Emit new true value while first is still being written
      bloc.getTruthSource('key').value =
          bloc.createFreshValue('key', content: 'truth-1');
      await pumpEventQueue();

      bloc.truthWriteLocked.value = false;
    });
  });
}
