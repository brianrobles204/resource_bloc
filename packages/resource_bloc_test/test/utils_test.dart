import 'dart:async';

import 'package:resource_bloc/resource_bloc.dart';
import 'package:resource_bloc_test/src/utils.dart';
import 'package:test/test.dart';

void main() {
  group('Resource bloc test utils', () {
    late StreamController<String> controller;
    late ResourceBloc<String, String> bloc;

    setUp(() {
      controller = StreamController.broadcast();
      bloc = ResourceBloc<String, String>.from(
        initialKey: 'key',
        freshSource: (key) => controller.stream,
        truthSource: TruthSource.noop(),
      );
    });

    tearDown(() async {
      await bloc.close();
      await controller.close();
    });

    test('untilDone waits until bloc is done loading', () async {
      bloc.reload();
      await pumpEventQueue();

      final untilDoneFuture = untilDoneLoading(bloc);

      expect(bloc.state.isLoading, isTrue);
      expect(untilDoneFuture, isA<Future<void>>());

      controller.add('value');
      await expectLater(untilDoneFuture, completes);

      expect(bloc.state.isLoading, isFalse);
    });

    test('untilDone returns instantly if bloc is done loading', () async {
      bloc.reload();
      await pumpEventQueue();
      controller.add('value');
      await pumpEventQueue();

      expect(bloc.state.isLoading, isFalse);
      expect(untilDoneLoading(bloc), isNot(isA<Future>()));
    });
  });
}
