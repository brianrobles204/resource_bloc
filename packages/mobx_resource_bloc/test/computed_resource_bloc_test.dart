import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:mobx_resource_bloc/mobx_resource_bloc.dart';
import 'package:mobx_resource_bloc/src/computed_resource_bloc.dart';
import 'package:resource_bloc/resource_bloc.dart';
import 'package:test/test.dart';

void main() {
  group('ComputedResourceBloc', () {
    var keyCount = 0;
    var freshCount = 0;
    late Observable<String> key;
    var keyThrowable = Observable<Object?>(null);
    late ComputedResourceBloc<String, String> bloc;
    late FreshSource<String, String> freshSourceCallback;
    final Map<String, StreamController<String>> truthDB = {};
    late TruthSource<String, String> truthSource;
    late OnObservePolicy defaultOnObservePolicy;

    StreamController<String> getTruthSource(String key) {
      return (truthDB[key] ??= StreamController.broadcast());
    }

    void updateObs<T>(Observable<T> obs, T newValue) {
      runInAction(() => obs.value = newValue);
    }

    Future<void> untilDone() =>
        bloc.stream.firstWhere((state) => !state.isLoading);

    String keyCallback() {
      keyCount++;
      if (keyThrowable.value != null) {
        throw keyThrowable.value!;
      }
      return key.value;
    }

    Stream<String> freshSource(String key) {
      freshCount++;
      return freshSourceCallback(key);
    }

    setUp(() {
      keyCount = 0;
      freshCount = 0;
      key = Observable('key');
      keyThrowable = Observable(null);
      freshSourceCallback = (key) => Stream.value(key);
      truthDB.clear();
      truthSource = TruthSource.from(
        reader: (key) => getTruthSource(key).stream,
        writer: (key, value) => getTruthSource(key).add(value),
      );
      bloc = ComputedResourceBloc.from(
        key: keyCallback,
        freshSource: freshSource,
        truthSource: truthSource,
      );
      defaultOnObservePolicy = ComputedResourceBloc.defaultOnObservePolicy;
    });

    tearDown(() async {
      ComputedResourceBloc.defaultOnObservePolicy = defaultOnObservePolicy;
      await bloc.close();
      await Future.wait(truthDB.values.map((controller) => controller.close()));
    });

    test('does not run if not observed', () async {
      await pumpEventQueue();
      expect(keyCount, equals(1));
      expect(freshCount, equals(0));

      expect(bloc.key, equals('key'));
      expect(keyCount, equals(1));
      await pumpEventQueue();

      expect(freshCount, equals(0));
      expect(bloc.value, isNull);
      expect(
        bloc.state,
        ResourceState<String, String>.initial('key', isLoading: false),
      );
      expect(keyCount, equals(1));
    });

    test('runs while values are being observed', () async {
      final states = <ResourceState<String, String>>[];
      autorun((_) => states.add(bloc.state));

      await pumpEventQueue();

      expect(
        states,
        equals([
          ResourceState<String, String>.initial('key', isLoading: true),
          ResourceState<String, String>.withValue('key', 'key',
              isLoading: false, source: Source.fresh),
        ]),
      );
    });

    test('runs while stream is being listened', () async {
      await expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          ResourceState<String, String>.initial('key', isLoading: true),
          ResourceState<String, String>.withValue('key', 'key',
              isLoading: false, source: Source.fresh),
        ]),
      );
    });

    test('updates bloc key while values are being observed', () async {
      final states = <ResourceState<String, String>>[];
      final dispose = autorun((_) => states.add(bloc.state));

      expect(keyCount, equals(2));
      await pumpEventQueue();

      updateObs(key, 'second');
      expect(keyCount, equals(3));
      await pumpEventQueue();

      dispose();

      updateObs(key, 'third');
      await pumpEventQueue();
      expect(keyCount, equals(3));

      expect(
        states,
        equals([
          ResourceState<String, String>.initial('key', isLoading: true),
          ResourceState<String, String>.withValue('key', 'key',
              isLoading: false, source: Source.fresh),
          ResourceState<String, String>.initial('second', isLoading: true),
          ResourceState<String, String>.withValue('second', 'second',
              isLoading: false, source: Source.fresh),
        ]),
      );
    });

    test('updates bloc key while stream is being listened', () async {
      expect(keyCount, equals(1));
      final subscription = bloc.stream.listen(null);
      expect(keyCount, equals(2));
      expect(
        bloc.state,
        ResourceState<String, String>.initial('key', isLoading: false),
      );

      await pumpEventQueue();
      expect(
        bloc.state,
        ResourceState<String, String>.withValue('key', 'key',
            isLoading: false, source: Source.fresh),
      );

      updateObs(key, 'second');
      expect(keyCount, equals(3));
      await pumpEventQueue();
      expect(
        bloc.state,
        ResourceState<String, String>.withValue('second', 'second',
            isLoading: false, source: Source.fresh),
      );

      await subscription.cancel();

      updateObs(key, 'third');
      await pumpEventQueue();
      expect(keyCount, equals(3));
      expect(
        bloc.state,
        ResourceState<String, String>.withValue('second', 'second',
            isLoading: false, source: Source.fresh),
        reason: 'no change since stream is no longer being listened',
      );
    });

    test('errors in key callback add a KeyError event', () async {
      final states = <ResourceState<String, String>>[];
      final subscription = bloc.stream.listen(states.add);

      await untilDone();

      updateObs(keyThrowable, 'error');
      await untilDone();

      updateObs(keyThrowable, null);
      await untilDone();

      await subscription.cancel();

      expect(
        states,
        equals([
          ResourceState<String, String>.initial('key', isLoading: true),
          ResourceState<String, String>.withValue('key', 'key',
              isLoading: false, source: Source.fresh),
          ResourceState<String, String>.withError('error',
              key: null, isLoading: false),
          ResourceState<String, String>.initial('key', isLoading: true),
          ResourceState<String, String>.withValue('key', 'key',
              isLoading: false, source: Source.fresh),
        ]),
      );
    });

    test('keyCallback errors on init result in no key', () async {
      final shouldThrow = Observable(true);
      bloc = ComputedResourceBloc.from(
        key: () {
          if (shouldThrow.value) {
            throw 'error';
          } else {
            return key.value;
          }
        },
        freshSource: freshSource,
        truthSource: truthSource,
      );

      expect(bloc.key, equals(null));
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.hasKey, isFalse);
      expect(bloc.state.error, equals('error'));

      final states = <ResourceState<String, String>>[];
      final dispose = autorun((_) => states.add(bloc.state));

      await pumpEventQueue();

      updateObs(shouldThrow, false);
      await untilDone();

      dispose();

      expect(
        states,
        equals([
          ResourceState<String, String>.withError('error',
              key: null, isLoading: false),
          ResourceState<String, String>.initial('key', isLoading: true),
          ResourceState<String, String>.withValue('key', 'key',
              isLoading: false, source: Source.fresh),
        ]),
      );
    });

    test('initial value correctly reflects in initial state', () {
      final initialValue = (String key) => 'init-$key';
      bloc = ComputedResourceBloc.from(
        key: keyCallback,
        freshSource: freshSource,
        truthSource: truthSource,
        initialValue: initialValue,
      );

      expect(
          bloc.state,
          equals(ResourceState.withValue('key', 'init-key',
              isLoading: false, source: Source.cache)));
    });

    test('initial value correctly reflects in stream', () async {
      final initialValue = (String key) => 'init-$key';
      bloc = ComputedResourceBloc.from(
        key: keyCallback,
        freshSource: freshSource,
        truthSource: truthSource,
        initialValue: initialValue,
      );

      final states = <ResourceState<String, String>>[];
      final subscription = bloc.stream.listen(states.add);

      await pumpEventQueue();

      updateObs(key, 'second');
      await pumpEventQueue();

      await subscription.cancel();

      expect(
        states,
        equals([
          ResourceState.withValue('key', 'init-key',
              isLoading: true, source: Source.cache),
          ResourceState.withValue('key', 'key',
              isLoading: false, source: Source.fresh),
          ResourceState.withValue('second', 'init-second',
              isLoading: true, source: Source.cache),
          ResourceState.withValue('second', 'second',
              isLoading: false, source: Source.fresh),
        ]),
      );
    });

    test('truth source updates reflects in state', () async {
      getTruthSource('key').add('truth');
      await pumpEventQueue();

      expect(
          bloc.state,
          equals(ResourceState<String, String>.withValue('key', 'truth',
              isLoading: false, source: Source.cache)));
    });

    test('truth source updates reflect in stream', () async {
      getTruthSource('key').add('truth');
      await pumpEventQueue();

      final states = <ResourceState<String, String>>[];
      final dispose = autorun((_) => states.add(bloc.state));

      await pumpEventQueue();

      updateObs(key, 'second');
      await pumpEventQueue();

      dispose();

      expect(
        states,
        equals([
          ResourceState<String, String>.withValue('key', 'truth',
              isLoading: true, source: Source.cache),
          ResourceState<String, String>.withValue('key', 'key',
              isLoading: false, source: Source.fresh),
          ResourceState<String, String>.initial('second', isLoading: true),
          ResourceState<String, String>.withValue('second', 'second',
              isLoading: false, source: Source.fresh),
        ]),
      );
    });

    test('state after an unobserved reload is correct', () async {
      bloc.reload();
      await pumpEventQueue();

      expect(
          bloc.state,
          equals(ResourceState<String, String>.withValue('key', 'key',
              isLoading: false, source: Source.fresh)));
    });

    test('can be observed after an unobserved reload', () async {
      bloc.reload();
      await pumpEventQueue();

      freshSourceCallback = (key) => Stream.value('$key-2');

      final states = <ResourceState<String, String>>[];
      final subscription = bloc.stream.listen(states.add);

      await pumpEventQueue();

      await subscription.cancel();

      expect(freshCount, equals(2));
      expect(
        states,
        equals([
          ResourceState.withValue('key', 'key',
              isLoading: true, source: Source.fresh),
          ResourceState.withValue('key', 'key-2',
              isLoading: false, source: Source.fresh),
        ]),
      );
    });

    test('can be observed after a partially completed reload', () async {
      ComputedResourceBloc.defaultOnObservePolicy =
          OnObservePolicy.reloadIfCached;

      final controller = StreamController<String>.broadcast();
      freshSourceCallback = (key) => controller.stream;

      final subscription = bloc.stream.listen(null);
      await pumpEventQueue();
      await subscription.cancel();

      expect(
        bloc.state,
        equals(ResourceState<String, String>.initial('key', isLoading: true)),
      );

      controller.add('fresh');
      await pumpEventQueue();

      final states = <ResourceState<String, String>>[];
      final dispose = autorun((_) => states.add(bloc.state));

      await pumpEventQueue();
      dispose();

      expect(
        states,
        equals([
          ResourceState.withValue('key', 'fresh',
              isLoading: false, source: Source.fresh),
        ]),
      );
    });

    test('stream can be listened, cancelled, and listened again', () async {
      final states = <ResourceState<String, String>>[];

      final sub1 = bloc.stream.listen(states.add);
      await pumpEventQueue();
      sub1.cancel();

      final sub2 = bloc.stream.listen(states.add);
      await pumpEventQueue();
      sub2.cancel();

      expect(
        states,
        equals([
          ResourceState<String, String>.initial('key', isLoading: true),
          ResourceState<String, String>.withValue('key', 'key',
              isLoading: false, source: Source.fresh),
          ResourceState<String, String>.withValue('key', 'key',
              isLoading: true, source: Source.fresh),
          ResourceState<String, String>.withValue('key', 'key',
              isLoading: false, source: Source.fresh),
        ]),
      );
    });

    test('key change while unobserved will not start load', () async {
      final states = <ResourceState<String, String>>[];

      final sub1 = bloc.stream.listen(states.add);
      await pumpEventQueue();
      sub1.cancel();

      updateObs(key, 'second');
      await pumpEventQueue();

      final sub2 = bloc.stream.listen(states.add);
      await pumpEventQueue();
      sub2.cancel();

      expect(keyCount, equals(3));
      expect(freshCount, equals(2));

      expect(
        states,
        equals([
          ResourceState<String, String>.initial('key', isLoading: true),
          ResourceState<String, String>.withValue('key', 'key',
              isLoading: false, source: Source.fresh),
          ResourceState<String, String>.initial('second', isLoading: true),
          ResourceState<String, String>.withValue('second', 'second',
              isLoading: false, source: Source.fresh),
        ]),
      );
    });

    test('reloadIfCached policy will not reload if fresh', () async {
      ComputedResourceBloc.defaultOnObservePolicy =
          OnObservePolicy.reloadIfCached;
      bloc.reload();
      await pumpEventQueue();

      final states = <ResourceState<String, String>>[];

      final dispose = autorun((_) => states.add(bloc.state));
      await pumpEventQueue();
      dispose();

      expect(
        states,
        equals([
          ResourceState<String, String>.withValue('key', 'key',
              isLoading: false, source: Source.fresh),
        ]),
      );
    });

    test('reloadIfEmpty policy will not reload if fresh', () async {
      ComputedResourceBloc.defaultOnObservePolicy =
          OnObservePolicy.reloadIfEmpty;
      bloc.reload();
      await pumpEventQueue();

      final states = <ResourceState<String, String>>[];

      final dispose = autorun((_) => states.add(bloc.state));
      await pumpEventQueue();
      dispose();

      expect(
        states,
        equals([
          ResourceState<String, String>.withValue('key', 'key',
              isLoading: false, source: Source.fresh),
        ]),
      );
    });
    test('reloadIfEmpty policy will not reload if cached', () async {
      ComputedResourceBloc.defaultOnObservePolicy =
          OnObservePolicy.reloadIfEmpty;
      getTruthSource('key').add('truth');
      await pumpEventQueue();

      final states = <ResourceState<String, String>>[];

      final dispose = autorun((_) => states.add(bloc.state));
      await pumpEventQueue();
      dispose();

      expect(
        states,
        equals([
          ResourceState<String, String>.withValue('key', 'truth',
              isLoading: false, source: Source.cache),
        ]),
      );
    });

    test('reloadNever policy will not reload if empty', () async {
      ComputedResourceBloc.defaultOnObservePolicy = OnObservePolicy.reloadNever;

      final states = <ResourceState<String, String>>[];

      final dispose = autorun((_) => states.add(bloc.state));
      await pumpEventQueue();
      dispose();

      expect(
        states,
        equals([
          ResourceState<String, String>.initial('key', isLoading: false),
        ]),
      );
    });
  });
}
