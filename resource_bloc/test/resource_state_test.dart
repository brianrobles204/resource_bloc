import 'package:resource_bloc/resource_bloc.dart';
import 'package:test/test.dart';

void main() {
  group('resource states', () {
    test('hasKey', () {
      final withKey =
          ResourceState<String, int>.initial('key', isLoading: false);
      expect(withKey.hasKey, isTrue);

      final nilKey = ResourceState<String, int>.initial(null, isLoading: false);
      expect(nilKey.hasKey, isFalse);
    });

    test('hasValue', () {
      final withValue = ResourceState.withValue('key', 1,
          isLoading: false, source: Source.cache);
      expect(withValue.hasValue, isTrue);

      final nilValue =
          ResourceState<String, int>.initial('key', isLoading: false);
      expect(nilValue.hasValue, isFalse);

      // Also works with nullable value type (V?)
      final withNullValue = ResourceState<String, int?>.withValue('key', null,
          isLoading: false, source: Source.cache);
      expect(withNullValue.hasValue, isTrue);

      final nilNullValue =
          ResourceState<String, int?>.initial('key', isLoading: false);
      expect(nilNullValue.hasValue, isFalse);
    });

    test('hasError', () {
      final withError = ResourceState<String, int>.withError(StateError('e'),
          key: 'key', isLoading: false);
      expect(withError.hasError, isTrue);

      final nilError =
          ResourceState<String, int>.initial('key', isLoading: false);
      expect(nilError.hasError, isFalse);
    });

    test('equality', () {
      final typeA = ResourceState<String, int>.initial(null, isLoading: false);
      final typeB = ResourceState<String, int?>.initial(null, isLoading: false);
      expect(typeA, isNot(equals(typeB)));
    });

    group('copyFunctions', () {
      final orig = ResourceState.withValueAndError('key', 'value', 'error',
          source: Source.fresh, isLoading: false);

      test('copyWith', () {
        expect(orig.copyWith(), equals(orig));

        final isLoadingState = ResourceState.withValueAndError(
            'key', 'value', 'error',
            source: Source.fresh, isLoading: true);
        expect(orig.copyWith(isLoading: true), equals(isLoadingState));

        final withoutValueState = ResourceState<String, String>.withError(
            'error',
            key: 'key',
            isLoading: false);
        expect(orig.copyWith(includeValue: false), equals(withoutValueState));

        final withoutErrorState = ResourceState.withValue('key', 'value',
            isLoading: false, source: Source.fresh);
        expect(orig.copyWith(includeError: false), equals(withoutErrorState));
      });

      test('copyWithValue', () {
        final newValue = ResourceState.withValueAndError('key', 'new', 'error',
            source: Source.cache, isLoading: false);
        expect(
            orig.copyWithValue('new', source: Source.cache), equals(newValue));

        final newLoadingState = ResourceState.withValueAndError(
            'key', 'new', 'error',
            source: Source.cache, isLoading: true);
        expect(orig.copyWithValue('new', source: Source.cache, isLoading: true),
            equals(newLoadingState));

        final newValueWithoutError = ResourceState.withValue('key', 'new',
            isLoading: false, source: Source.cache);
        expect(
            orig.copyWithValue('new',
                source: Source.cache, includeError: false),
            equals(newValueWithoutError));
      });

      test('copyWithError', () {
        final newError = ResourceState.withValueAndError('key', 'value', 'new',
            source: Source.fresh, isLoading: false);
        expect(orig.copyWithError('new'), equals(newError));

        final newLoadingState = ResourceState.withValueAndError(
            'key', 'value', 'new',
            source: Source.fresh, isLoading: true);
        expect(orig.copyWithError('new', isLoading: true),
            equals(newLoadingState));

        final newErrorWithoutValue = ResourceState<String, String>.withError(
            'new',
            key: 'key',
            isLoading: false);
        expect(orig.copyWithError('new', includeValue: false),
            equals(newErrorWithoutValue));
      });
    });

    test('map', () {
      final withValue = ResourceState.withValueAndError('key', '100', 'error',
          source: Source.fresh, isLoading: false);
      final mappedValue = ResourceState.withValueAndError('key', 100, 'error',
          source: Source.fresh, isLoading: false);

      expect(withValue.map((value) => int.parse(value)), equals(mappedValue));

      final withoutValue = ResourceState<String, String>.withError('error',
          key: 'key', isLoading: false);
      final mappedWithoutValue = ResourceState<String, int>.withError('error',
          key: 'key', isLoading: false);
      expect(withoutValue.map((value) => int.parse(value)),
          equals(mappedWithoutValue));
    });

    group('extensions', () {
      test('requireKey', () {
        final withKey =
            ResourceState<String, int>.initial('key', isLoading: false);
        expect(withKey.requireKey, equals('key'));

        final nilKey =
            ResourceState<String, int>.initial(null, isLoading: false);
        expect(() => nilKey.requireKey, throwsStateError);
      });

      test('requireValue', () {
        final withValue = ResourceState.withValue('key', 1,
            isLoading: false, source: Source.cache);
        expect(withValue.requireValue, equals(1));

        final nilValue =
            ResourceState<String, int>.initial('key', isLoading: false);
        expect(() => nilValue.requireValue, throwsStateError);

        // Also works with nullable value type (V?)
        final withNullValue = ResourceState<String, int?>.withValue('key', null,
            isLoading: false, source: Source.cache);
        expect(withNullValue.requireValue, isNull);

        final nilNullValue =
            ResourceState<String, int?>.initial('key', isLoading: false);
        expect(() => nilNullValue.requireValue, throwsStateError);
      });

      test('requireSource', () {
        final withValue = ResourceState.withValue('key', 1,
            isLoading: false, source: Source.cache);
        expect(withValue.requireSource, equals(Source.cache));

        final nilValue =
            ResourceState<String, int>.initial('key', isLoading: false);
        expect(() => nilValue.requireSource, throwsStateError);

        // Also works with nullable value type (V?)
        final withNullValue = ResourceState<String, int?>.withValue('key', null,
            isLoading: false, source: Source.cache);
        expect(withNullValue.requireSource, Source.cache);

        final nilNullValue =
            ResourceState<String, int?>.initial('key', isLoading: false);
        expect(() => nilNullValue.requireSource, throwsStateError);
      });

      test('requireError', () {
        final withError = ResourceState<String, int>.withError('error',
            key: 'key', isLoading: false);
        expect(withError.requireError, equals('error'));

        final nilError =
            ResourceState<String, int>.initial('key', isLoading: false);
        expect(() => nilError.requireError, throwsStateError);
      });
    });
  });
}
