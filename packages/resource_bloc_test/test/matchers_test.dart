import 'package:resource_bloc/resource_bloc.dart';
import 'package:resource_bloc_test/resource_bloc_test.dart';
import 'package:test/test.dart';

void main() {
  group('Resource bloc matchers', () {
    test('match empty states', () {
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
    test('match initial states', () {
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
    test('match keys', () {
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
    test('match values', () {
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
    test('match errors', () {
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
    test('match exact types', () {
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
}
