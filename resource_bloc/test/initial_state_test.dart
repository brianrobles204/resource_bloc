import 'package:resource_bloc/resource_bloc.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('initial state', () {
    late TestResourceBloc bloc;

    setUp(() {
      bloc = TestResourceBloc();
    });

    tearDown(() {
      bloc.close();
    });

    test('starts with initial state and no reads', () {
      expect(bloc.state, isInitialState);
      expect(bloc.freshReadCount, equals(0));
      expect(bloc.truthReadCount, equals(0));
      expect(bloc.truthWriteCount, equals(0));
    });

    test('without key does not change after value changing events', () async {
      expectLater(bloc.stream, emitsDone);

      bloc.reload();
      await pumpEventQueue();

      bloc.add(ValueUpdate('key', bloc.createFreshValue('key')));
      await pumpEventQueue();

      bloc.add(TestAction(0, loading: 'active', done: 'done'));
      await pumpEventQueue();

      await bloc.close();

      expect(bloc.state, isInitialState);
      expect(bloc.freshReadCount, equals(0));
      expect(bloc.truthReadCount, equals(0));
      expect(bloc.truthWriteCount, equals(0));
      expect(bloc.actionStartCount, equals(0));
      expect(bloc.actionFinishCount, equals(0));
    });

    test('reflects the initial key if provided', () {
      bloc = TestResourceBloc(initialKey: 'first');

      expect(bloc.state, isInitialLoadingState('first'));
      expect(bloc.freshReadCount, equals(0));
      expect(bloc.truthReadCount, equals(0));
      expect(bloc.truthWriteCount, equals(0));

      bloc.reload();

      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isInitialLoadingState('first'),
          isStateWith(isLoading: false, name: 'first', count: 1),
        ]),
      );
    });
  });
}
