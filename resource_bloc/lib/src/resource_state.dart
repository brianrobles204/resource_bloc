import 'package:equatable/equatable.dart';

class ResourceState<K extends Object, V> extends Equatable {
  ResourceState.initial()
      : isLoading = true,
        key = null,
        hasKey = false,
        hasValue = false,
        value = null,
        source = null,
        hasError = false,
        error = null;

  ResourceState.loading(K key)
      : isLoading = true,
        key = key,
        hasKey = true,
        hasValue = false,
        value = null,
        source = null,
        hasError = false,
        error = null;

  ResourceState.withValue(
    K key,
    V value, {
    required this.isLoading,
    required Source source,
  })  : value = value,
        source = source,
        key = key,
        hasKey = true,
        hasValue = true,
        hasError = false,
        error = null;

  ResourceState.withError(
    Object error, {
    required this.key,
    required this.isLoading,
  })  : error = error,
        hasError = true,
        hasKey = key != null,
        hasValue = false,
        value = null,
        source = null;

  ResourceState.loadingWithValueAndError(
    K key,
    V value,
    Object error, {
    required Source source,
  })  : key = key,
        value = value,
        isLoading = true,
        source = source,
        error = error,
        hasKey = true,
        hasValue = true,
        hasError = true;

  ResourceState._raw(
    this.key,
    this.value,
    this.error, {
    required this.isLoading,
    required this.source,
  })  : hasKey = key != null,
        hasValue = source != null,
        hasError = error != null;

  final bool hasKey;
  final K? key;

  final bool isLoading;

  final bool hasValue;
  final V? value;
  final Source? source;

  final bool hasError;
  final Object? error;

  ResourceState<K, N> map<N>(N Function(V value) callback) =>
      ResourceState._raw(
        key,
        hasValue ? callback(value as V) : null,
        error,
        isLoading: isLoading,
        source: hasValue ? source : null,
      );

  ResourceState<K, V> copyWith({
    bool? isLoading,
    bool includeValue = true,
    bool includeError = true,
  }) =>
      ResourceState._raw(
        key,
        includeValue ? value : null,
        includeError ? error : null,
        isLoading: isLoading ?? this.isLoading,
        source: includeValue ? source : null,
      );

  ResourceState<K, V> copyWithValue(
    V value, {
    required Source source,
    bool? isLoading,
    bool includeError = true,
  }) =>
      ResourceState._raw(
        key,
        value,
        includeError ? error : null,
        isLoading: isLoading ?? this.isLoading,
        source: source,
      );

  ResourceState<K, V> copyWithError(
    Object error, {
    bool? isLoading,
    bool includeValue = true,
  }) =>
      ResourceState._raw(
        key,
        includeValue ? value : null,
        error,
        isLoading: isLoading ?? this.isLoading,
        source: includeValue ? source : null,
      );

  @override
  List<Object?> get props =>
      [isLoading, hasValue, value, source, hasError, error];

  @override
  String toString() => '$runtimeType('
      'hasKey=$hasKey, '
      'key=$key, '
      'isLoading=$isLoading, '
      'hasValue=$hasValue, '
      'value=$value, '
      'source=$source, '
      'hasError=$hasError, '
      'error=$error'
      ')';
}

enum Source { fresh, cache }

extension ResourceStateRequireExtensions<K extends Object, V>
    on ResourceState<K, V> {
  V get requireValue {
    if (hasValue) {
      return value as V;
    } else {
      throw StateError('$this has no value');
    }
  }

  Source get requireSource {
    if (hasValue) {
      return source!;
    } else {
      throw StateError('$this has no value, and no source');
    }
  }

  Object get requireError {
    if (hasError) {
      return error!;
    } else {
      throw StateError('$this has no error');
    }
  }
}
