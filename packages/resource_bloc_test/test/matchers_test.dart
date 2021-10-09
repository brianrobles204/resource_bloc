import 'package:resource_bloc/resource_bloc.dart';
import 'package:resource_bloc_test/resource_bloc_test.dart';
import 'package:test/test.dart';

void main() {
  group('Resource bloc matchers match', () {
    test('empty states', () {
      expect(
        isEmptyLoadingState.matches(
            ResourceState<int, int>.initial(null, isLoading: true), {}),
        isTrue,
      );
      expect(
        isEmptyLoadingState.matches(StateSnapshot.loading(), {}),
        isTrue,
      );
      expect(
        isEmptyLoadingState.matches(
          ResourceState<int, int>.withValue(0, 1,
              source: Source.fresh, isLoading: true),
          {},
        ),
        isFalse,
      );
      expect(
        isEmptyLoadingState.matches(
          ResourceState<int, int>.initial(null, isLoading: false),
          {},
        ),
        isFalse,
      );
      expect(
        isEmptyNonLoadingState.matches(
            ResourceState<int, int>.initial(null, isLoading: false), {}),
        isTrue,
      );
      expect(
        isEmptyNonLoadingState.matches(StateSnapshot.notLoading(), {}),
        isTrue,
      );
      expect(
        isEmptyNonLoadingState.matches(
          ResourceState<int, int>.withValue(0, 1,
              source: Source.fresh, isLoading: false),
          {},
        ),
        isFalse,
      );
      expect(
        isEmptyNonLoadingState.matches(
          ResourceState<int, int>.initial(null, isLoading: true),
          {},
        ),
        isFalse,
      );
    });
    test('initial states', () {
      expect(
        isInitialLoadingState(0)
            .matches(ResourceState<int, int>.initial(0, isLoading: true), {}),
        isTrue,
      );
      expect(
        isInitialLoadingState(0)
            .matches(ResourceState<int, int>.initial(1, isLoading: true), {}),
        isFalse,
      );
      expect(
        isInitialLoadingState(0).matches(
            ResourceState<int, int>.initial(null, isLoading: true), {}),
        isFalse,
      );
      expect(
        isInitialLoadingState(0)
            .matches(ResourceState<int, int>.initial(0, isLoading: false), {}),
        isFalse,
      );

      expect(
        isInitialNonLoadingState(0)
            .matches(ResourceState<int, int>.initial(0, isLoading: false), {}),
        isTrue,
      );
      expect(
        isInitialNonLoadingState(0)
            .matches(ResourceState<int, int>.initial(1, isLoading: false), {}),
        isFalse,
      );
      expect(
        isInitialNonLoadingState(0).matches(
            ResourceState<int, int>.initial(null, isLoading: false), {}),
        isFalse,
      );
      expect(
        isInitialNonLoadingState(0)
            .matches(ResourceState<int, int>.initial(0, isLoading: true), {}),
        isFalse,
      );
    });
    test('keys', () {
      expect(
        isStateWith(key: contains(20)).matches(
          ResourceState<List<int>, int>.initial([19, 20], isLoading: true),
          {},
        ),
        isTrue,
      );
      expect(
        isStateWith(key: isNull).matches(
          ResourceState<int, int>.initial(100, isLoading: true),
          {},
        ),
        isFalse,
      );
      expect(
        isStateWith(key: isNull).matches(
          StateSnapshot.withValue(100, isLoading: true, source: Source.fresh),
          {},
        ),
        isTrue,
        reason: 'Can match with snapshots if key == null or key == isNull',
      );
      expect(
        isStateWith(key: contains(20)).matches(
          StateSnapshot.withValue(100, isLoading: true, source: Source.fresh),
          {},
        ),
        isFalse,
      );
    });
    test('values', () {
      expect(
        isLoadingWithValue(100, Source.fresh).matches(
          StateSnapshot.withValue(100, isLoading: true, source: Source.fresh),
          {},
        ),
        isTrue,
      );
      expect(
        isLoadingWithValue(100, Source.fresh).matches(
          StateSnapshot.withValue(120, isLoading: true, source: Source.fresh),
          {},
        ),
        isFalse,
      );
      expect(
        isLoadingWithValue(100, Source.fresh).matches(
          StateSnapshot.withValue(100, isLoading: true, source: Source.cache),
          {},
        ),
        isFalse,
      );
      expect(
        isLoadingWithValue(100, Source.fresh).matches(
          StateSnapshot.withValue(100, isLoading: false, source: Source.fresh),
          {},
        ),
        isFalse,
      );

      expect(
        isDoneWithValue(100, Source.fresh).matches(
          StateSnapshot.withValue(100, isLoading: false, source: Source.fresh),
          {},
        ),
        isTrue,
      );
      expect(
        isDoneWithValue(100, Source.fresh).matches(
          StateSnapshot.withValue(120, isLoading: false, source: Source.fresh),
          {},
        ),
        isFalse,
      );
      expect(
        isDoneWithValue(100, Source.fresh).matches(
          StateSnapshot.withValue(100, isLoading: false, source: Source.cache),
          {},
        ),
        isFalse,
      );
      expect(
        isDoneWithValue(100, Source.fresh).matches(
          StateSnapshot.withValue(100, isLoading: true, source: Source.fresh),
          {},
        ),
        isFalse,
      );
    });
    test('errors', () {
      expect(
        isLoadingStateWith(error: isStateError).matches(
            StateSnapshot.withError(StateError(''), isLoading: true), {}),
        isTrue,
      );
      expect(
        isLoadingStateWith(error: isStateError).matches(
          StateSnapshot.withValue(100, source: Source.cache, isLoading: true),
          {},
        ),
        isFalse,
      );
    });
    test('key errors', () {
      expect(
        isKeyErrorState(isStateError).matches(
          ResourceState<int, int>.withError(StateError(''),
              key: null, isLoading: false),
          {},
        ),
        isTrue,
      );
      expect(
        isKeyErrorState(isStateError).matches(
          ResourceState<int, int>.withError(100, key: null, isLoading: false),
          {},
        ),
        isFalse,
      );
      expect(
        isKeyErrorState(isStateError).matches(
          ResourceState<int, int>.withError(StateError(''),
              key: 100, isLoading: false),
          {},
        ),
        isFalse,
      );
      expect(
        isKeyErrorState(isStateError).matches(
          ResourceState<int, int>.withError(StateError(''),
              key: null, isLoading: true),
          {},
        ),
        isFalse,
      );
    });
    test('exact types', () {
      expect(
        isStateOf<int, int>().matches(
          ResourceState.withValue(100, 100,
              isLoading: true, source: Source.cache),
          {},
        ),
        isTrue,
      );
      expect(
        isStateOf<int, int>().matches(
          ResourceState<int, int>.initial(null, isLoading: false),
          {},
        ),
        isTrue,
      );
      expect(
        isStateOf<int, int>().matches(
          ResourceState.initial(100, isLoading: false),
          {},
        ),
        isFalse,
        reason: 'should not match inferred dynamic value type',
      );
      expect(
        isStateOf<int, int>().matches(
          ResourceState<String, String>.initial(null, isLoading: false),
          {},
        ),
        isFalse,
      );

      expect(
        isSnapshotOf<int>().matches(
          StateSnapshot.withValue(100, source: Source.cache, isLoading: true),
          {},
        ),
        isTrue,
      );
      expect(
        isSnapshotOf<int>().matches(StateSnapshot<int>.loading(), {}),
        isTrue,
      );
      expect(
        isSnapshotOf<int>().matches(
          ResourceState<String, int>.withValue('test', 100,
              isLoading: true, source: Source.fresh),
          {},
        ),
        isTrue,
      );
      expect(isSnapshotOf<int>().matches(StateSnapshot.loading(), {}), isFalse);
      expect(
        isSnapshotOf<int>().matches(StateSnapshot<String>.loading(), {}),
        isFalse,
      );
    });
  });
  group('Resource bloc matchers describe', () {
    void expectEqualDescriptions(Map<Matcher, String> cases) {
      for (final caseEntry in cases.entries) {
        expect(
          caseEntry.key.describe(StringDescription()).toString(),
          equals(caseEntry.value),
        );
      }
    }

    test('snapshots and resource states', () {
      expectEqualDescriptions({
        isStateWith(): 'StateSnapshot()',
        isStateWith(value: 100): 'StateSnapshot(value=<100>)',
        isStateWith(key: 100, value: 100):
            'ResourceState(key=<100>, value=<100>)',
        isStateWith(key: isNull): 'StateSnapshot(key=null)',
        isStateWith(key: isA<String>()):
            'ResourceState(key=<Instance of \'String\'>)',
      });
    });
    test('generic types', () {
      expectEqualDescriptions({
        isStateOf<String, String>(): 'StateSnapshot<String>()',
        isStateOf<String, String>(key: 100):
            'ResourceState<String, String>(key=<100>)',
        isSnapshotOf<int>(): 'StateSnapshot<int>()',
        isSnapshotOf<int>(isLoading: true):
            'StateSnapshot<int>(isLoading=<true>)',
      });
    });
    test('properties', () {
      expectEqualDescriptions({
        isStateWith(isLoading: true): 'StateSnapshot(isLoading=<true>)',
        isStateWith(key: 100): 'ResourceState(key=<100>)',
        isStateWith(value: 'x'): 'StateSnapshot(value=\'x\')',
        isStateWith(source: Source.cache):
            'StateSnapshot(source=<Source.cache>)',
        isStateWith(error: 5.0): 'StateSnapshot(error=<5.0>)',
        isStateWith(isLoading: false, value: 100):
            'StateSnapshot(isLoading=<false>, value=<100>)',
      });
    });
  });
  group('Resource matchers describe mismatched', () {
    void expectEqualDescriptions(Iterable<_MismatchCase> cases) {
      for (final caseEntry in cases) {
        expect(caseEntry.actual, equals(caseEntry.expected));
      }
    }

    test('snapshots and resource states', () {
      expectEqualDescriptions({
        _case(
          matcher: isStateWith(),
          item: 'unrelated item',
          expected: 'is not an instance of StateSnapshot',
        ),
        _case(
          matcher: isStateWith(key: 'red', isLoading: true),
          item: StateSnapshot.loading(),
          expected: 'is not an instance of ResourceState',
        ),
        _case(
          matcher: isStateOf<String, String>(key: 'red', isLoading: true),
          item: ResourceState<String, bool>.initial('red', isLoading: true),
          expected: 'is not an instance of ResourceState<String, String>',
        ),
        _case(
          matcher: isSnapshotOf<bool>(),
          item: ResourceState<bool, String>.initial(null, isLoading: false),
          expected: 'is not an instance of StateSnapshot<bool>',
        ),
      });
    });

    test('properties (solo)', () {
      expectEqualDescriptions({
        _case(
          matcher: isEmptyLoadingState,
          item: ResourceState<String, String>.initial(null, isLoading: false),
          expected: 'is not loading',
        ),
        _case(
          matcher: isEmptyNonLoadingState,
          item: ResourceState<String, String>.initial(null, isLoading: true),
          expected: 'is loading',
        ),
        _case(
          matcher: isStateWith(key: 100),
          item: ResourceState.initial(99, isLoading: true),
          expected: 'has a key that is <99>',
        ),
        _case(
          matcher: isStateWith(value: 100),
          item: StateSnapshot.withValue(99,
              isLoading: true, source: Source.fresh),
          expected: 'has a value that is <99>',
        ),
        _case(
          matcher: isStateWith(value: 100),
          item: StateSnapshot.loading(),
          expected: 'has a value that is <null>',
        ),
        _case(
          matcher: isStateWith(error: 100),
          item: StateSnapshot.withError(99, isLoading: true),
          expected: 'has an error that is <99>',
        ),
        _case(
          matcher: isStateWith(error: 100),
          item: StateSnapshot.loading(),
          expected: 'has an error that is <null>',
        ),
        _case(
          matcher: isStateWith(source: Source.cache),
          item: StateSnapshot.withValue(100,
              isLoading: false, source: Source.fresh),
          expected: 'has a fresh source',
        ),
        _case(
          matcher: isStateWith(source: Source.fresh),
          item: StateSnapshot.withValue(100,
              isLoading: false, source: Source.cache),
          expected: 'has a cache source',
        ),
        _case(
          matcher: isStateWith(source: Source.cache),
          item: StateSnapshot.loading(),
          expected: 'has no source',
        ),
      });
    });
    test('properties with isNull matcher', () {
      expectEqualDescriptions({
        _case(
          matcher: isStateWith(key: isNull),
          item: ResourceState.initial(99, isLoading: true),
          expected: 'has a key that is <99>',
        ),
        _case(
          matcher: isStateWith(value: isNull),
          item: StateSnapshot.withValue(99,
              isLoading: true, source: Source.fresh),
          expected: 'has a value that is <99>',
        ),
        _case(
          matcher: isStateWith(error: isNull),
          item: StateSnapshot.withError(99, isLoading: true),
          expected: 'has an error that is <99>',
        ),
      });
    });
    test('properties with complex matchers', () {
      expectEqualDescriptions({
        _case(
            matcher: isStateWith(value: allOf(99, contains('8'))),
            item: StateSnapshot.withValue(99,
                isLoading: true, source: Source.fresh),
            expected: 'has a value that is not a string, map or iterable'),
      });
    });
    test('properties (solo) after isLoading mismatch', () {
      expectEqualDescriptions({
        _case(
          matcher: isLoadingStateWith(key: 100),
          item: ResourceState.initial(99, isLoading: false),
          expected: 'is not loading with a key which is <99>',
        ),
        _case(
          matcher: isLoadingStateWith(value: 100),
          item: StateSnapshot.withValue(99,
              isLoading: false, source: Source.cache),
          expected: 'is not loading with a value which is <99>',
        ),
        _case(
          matcher: isLoadingStateWith(error: 100),
          item: StateSnapshot.withError(99, isLoading: false),
          expected: 'is not loading with an error which is <99>',
        ),
        _case(
          matcher: isLoadingStateWith(source: Source.cache),
          item: StateSnapshot.withValue(99,
              isLoading: false, source: Source.fresh),
          expected: 'is not loading with a fresh source',
        ),
      });
    });
    test('properties (multiple)', () {
      expectEqualDescriptions({
        _case(
          matcher: isLoadingWithValue(100, Source.fresh),
          item: StateSnapshot.withValueAndError(99, 99,
              isLoading: false, source: Source.cache),
          expected: 'is not loading, with a value which is <99>, '
              'and a cache source',
        ),
        _case(
          matcher: isLoadingWithValue(100, Source.fresh, error: 100),
          item: StateSnapshot.withValueAndError(99, 99,
              isLoading: false, source: Source.cache),
          expected: 'is not loading, with a value which is <99>, '
              'with an error which is <99>, and a cache source',
        ),
        _case(
          matcher: isLoadingStateWith(value: 100, error: 100),
          item: StateSnapshot.withValueAndError(99, 99,
              isLoading: false, source: Source.cache),
          expected: 'is not loading, with a value which is <99>, '
              'and an error which is <99>',
        ),
        _case(
          matcher: isStateWith(value: 100, error: 100, source: Source.fresh),
          item: StateSnapshot.withValueAndError(99, 99,
              isLoading: false, source: Source.cache),
          expected: 'has a value that is <99>, '
              'with an error which is <99>, and a cache source',
        ),
      });
    });
  });
}

_MismatchCase _case({
  required Matcher matcher,
  required dynamic item,
  required String expected,
}) =>
    _MismatchCase(matcher, item, expected);

class _MismatchCase {
  _MismatchCase(this.matcher, this.item, this.expected);

  final Matcher matcher;
  final dynamic item;
  final String expected;

  String get actual {
    final matchState = {};
    final matches = matcher.matches(item, matchState);
    assert(!matches);

    return matcher
        .describeMismatch(item, StringDescription(), matchState, false)
        .toString();
  }
}
