import 'package:resource_bloc/resource_bloc.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('initial value callback', () {
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

    test('returning null should emit loading state with no value', () {
      bloc = TestResourceBloc(
        initialKey: 'first',
        initialValue: (key) => null,
      );

      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isInitialLoadingState('first'),
          isStateWith(isLoading: false, name: 'first', count: 1),
        ]),
      );

      bloc.reload();
    });

    test('returning non-null value should reflect in state', () async {
      bloc = TestResourceBloc(
        initialKey: 'first',
        initialValue: (key) => createFreshValue(key, content: '$key-loading'),
      );

      // State should already be initial value state
      expect(
        bloc.state,
        isStateWhere(
            isLoading: false,
            value: isValueWith(name: 'first', content: 'first-loading'),
            source: Source.cache),
      );

      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          isStateWhere(
              isLoading: true,
              value: isValueWith(name: 'first', content: 'first-loading'),
              source: Source.cache),
          isStateWhere(
              isLoading: false,
              value: isValueWith(name: 'first', content: 'first-ready'),
              source: Source.fresh),
          isStateWhere(
              isLoading: true,
              value: isValueWith(name: 'second', content: 'second-loading'),
              source: Source.cache),
          isStateWhere(
              isLoading: false,
              value: isValueWith(name: 'second', content: 'second-ready'),
              source: Source.fresh),
        ]),
      );

      bloc.freshContent = 'first-ready';
      bloc.reload();
      await untilDone(bloc);

      bloc.freshContent = 'second-ready';
      bloc.key = 'second';
    });

    test('errors should be treated as if there\'s no value', () async {
      var shouldThrow = true;
      bloc = TestResourceBloc(
        initialKey: 'first',
        initialValue: (key) {
          if (shouldThrow) {
            throw StateError('initial value error');
          } else {
            return createFreshValue(key, content: '$key-loading');
          }
        },
      );

      expectLater(
        bloc.stream,
        emitsInOrder(<dynamic>[
          // Throw initial value on init
          isInitialLoadingState('first'),
          isStateWith(isLoading: false, name: 'first', content: 'first-ready'),
          // Throw initial value after key change
          isInitialLoadingState('second'),
          isStateWith(
              isLoading: false, name: 'second', content: 'second-ready'),
          // Successful initial value after key change
          isStateWith(isLoading: true, name: 'third', content: 'third-loading'),
          isStateWith(isLoading: false, name: 'third', content: 'third-ready'),
        ]),
      );

      bloc.freshContent = 'first-ready';
      bloc.reload();
      await untilDone(bloc);

      bloc.freshContent = 'second-ready';
      bloc.key = 'second';
      await untilDone(bloc);

      shouldThrow = false;
      bloc.freshContent = 'third-ready';
      bloc.key = 'third';
    });
  });
}
