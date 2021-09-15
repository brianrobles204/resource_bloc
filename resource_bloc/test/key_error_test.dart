import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('key errors', () {
    late TestResourceBloc bloc;

    setUp(() {
      bloc = TestResourceBloc();
    });

    tearDown(() {
      bloc.close();
    });

    test('pass errors to the state', () {});

    test('overwrite existing data with an error', () {});

    test('after errors are still reflected', () {});

    test('stop all loading including further fresh / truth updates', () {});

    test('stop all loading even during reload', () {});

    test('stop all loading even during truth read', () {});

    test('stop all loading even during truth write', () {});
  });
}
