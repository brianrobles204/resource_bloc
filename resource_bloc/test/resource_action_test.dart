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

    test('work after fresh load', () {});

    test('work concurrently', () {});

    test('will not use initial value', () {});

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
