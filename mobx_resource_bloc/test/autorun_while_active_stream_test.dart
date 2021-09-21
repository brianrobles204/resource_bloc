import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:mobx_resource_bloc/src/autorun_while_active_stream.dart';
import 'package:test/test.dart';

void main() {
  group('AutorunWhileActiveStream', () {
    late Observable<String> observable;
    late StreamController<int> controller;
    var runCount = 0;

    void callback(Reaction _) {
      observable.value;
      runCount++;
    }

    void updateObservable(String value) {
      runInAction(() {
        observable.value = value;
      });
    }

    AutorunWhileActiveStream<int> autorunStream() =>
        AutorunWhileActiveStream(callback, controller.stream);

    setUp(() {
      runCount = 0;
      observable = Observable('first');
      controller = StreamController<int>();
    });

    tearDown(() {
      if (!controller.isClosed) {
        controller.close();
      }
    });

    test('does not run if not listened', () {
      autorunStream();
      expect(runCount, equals(0));
      updateObservable('second');
      expect(runCount, equals(0));
    });

    test('tracks observables if listened to', () async {
      final subscription = autorunStream().listen(null);

      expect(runCount, equals(1));
      updateObservable('second');
      expect(runCount, equals(2));

      await subscription.cancel();

      expect(runCount, equals(2));
      updateObservable('third');
      expect(runCount, equals(2));
    });

    test('stops tracking if paused', () async {
      final subscription = autorunStream().listen(null);

      expect(runCount, equals(1));
      updateObservable('second');
      expect(runCount, equals(2));

      subscription.pause();

      expect(runCount, equals(2));
      updateObservable('third');
      expect(runCount, equals(2));

      subscription.resume();

      expect(runCount, equals(3));
      updateObservable('fourth');
      expect(runCount, equals(4));

      subscription.pause();
      subscription.pause();

      expect(runCount, equals(4));
      updateObservable('fifth');
      expect(runCount, equals(4));

      subscription.resume();

      expect(runCount, equals(4));
      updateObservable('sixth');
      expect(runCount, equals(4));

      subscription.resume();

      expect(runCount, equals(5));
      updateObservable('seventh');
      expect(runCount, equals(6));

      await subscription.cancel();

      expect(runCount, equals(6));
      updateObservable('eighth');
      expect(runCount, equals(6));
    });

    test('autorun not affected by stream', () async {
      final subscription = autorunStream().listen(null);

      expect(runCount, equals(1));
      updateObservable('second');
      expect(runCount, equals(2));

      controller.add(10);

      expect(runCount, equals(2));
      updateObservable('third');
      expect(runCount, equals(3));

      subscription.pause();

      expect(runCount, equals(3));
      updateObservable('fourth');
      expect(runCount, equals(3));

      controller.addError(StateError('e'));

      expect(runCount, equals(3));
      updateObservable('fifth');
      expect(runCount, equals(3));

      subscription.resume();

      expect(runCount, equals(4));
      updateObservable('sixth');
      expect(runCount, equals(5));

      controller.add(30);

      expect(runCount, equals(5));
      updateObservable('seventh');
      expect(runCount, equals(6));

      await subscription.cancel();
    });

    test('works with broadcast controllers', () async {
      controller = StreamController.broadcast();
      final subscription = autorunStream().listen(null);

      expect(runCount, equals(1));
      updateObservable('second');
      expect(runCount, equals(2));

      controller.add(10);

      expect(runCount, equals(2));
      updateObservable('third');
      expect(runCount, equals(3));

      subscription.pause();

      expect(runCount, equals(3));
      updateObservable('fourth');
      expect(runCount, equals(3));

      controller.add(20);

      expect(runCount, equals(3));
      updateObservable('fifth');
      expect(runCount, equals(3));

      subscription.resume();

      expect(runCount, equals(4));
      updateObservable('sixth');
      expect(runCount, equals(5));

      controller.add(30);

      expect(runCount, equals(5));
      updateObservable('seventh');
      expect(runCount, equals(6));

      await controller.close();

      expect(runCount, equals(6));
      updateObservable('eighth');
      expect(runCount, equals(6));

      await subscription.cancel();
    });
  });
}
