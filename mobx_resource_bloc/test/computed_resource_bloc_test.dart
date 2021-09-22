import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:mobx_resource_bloc/mobx_resource_bloc.dart';
import 'package:resource_bloc/resource_bloc.dart';
import 'package:test/test.dart';

void main() {
  group('ComputedResourceBloc', () {
    var keyCount = 0;
    var freshCount = 0;
    late Observable<String> key;
    late ComputedResourceBloc<String, String> bloc;
    final Map<String, StreamController<String>> truthDB = {};
    late FreshSource<String, String> freshSource;

    StreamController<String> getTruthSource(String key) {
      return (truthDB[key] ??= StreamController.broadcast());
    }

    void updateKey(String newKey) {
      runInAction(() => key.value = newKey);
    }

    setUp(() {
      keyCount = 0;
      freshCount = 0;
      key = Observable('key');
      freshSource = (key) => Stream.value(key);
      truthDB.clear();
      bloc = ComputedResourceBloc.from(
        key: () {
          keyCount++;
          return key.value;
        },
        freshSource: (key) {
          freshCount++;
          return freshSource(key);
        },
        truthSource: TruthSource.from(
          reader: (key) => getTruthSource(key).stream,
          writer: (key, value) => getTruthSource(key).add(value),
        ),
      );
    });

    tearDown(() async {
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

      updateKey('second');
      expect(keyCount, equals(3));
      await pumpEventQueue();

      dispose();

      updateKey('third');
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
    }, skip: 'Need to ensure clean-up of observable stream in order to close');

    test('updates bloc key while stream is being listened', () async {
      expect(keyCount, equals(1));
      final subscription = bloc.stream.listen(null);
      expect(keyCount, equals(2));
      expect(
        bloc.state,
        ResourceState<String, String>.initial('key', isLoading: true),
      );

      await pumpEventQueue();
      expect(
        bloc.state,
        ResourceState<String, String>.withValue('key', 'key',
            isLoading: false, source: Source.fresh),
      );

      updateKey('second');
      expect(keyCount, equals(3));
      await pumpEventQueue();
      expect(
        bloc.state,
        ResourceState<String, String>.withValue('second', 'second',
            isLoading: false, source: Source.fresh),
      );

      await subscription.cancel();

      updateKey('third');
      await pumpEventQueue();
      expect(keyCount, equals(3));
      expect(
        bloc.state,
        ResourceState<String, String>.withValue('second', 'second',
            isLoading: false, source: Source.fresh),
        reason: 'no change since stream is no longer being listened',
      );
    });
  });
}
