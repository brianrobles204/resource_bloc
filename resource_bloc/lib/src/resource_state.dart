import 'package:equatable/equatable.dart';

class ResourceState<K extends Object, V> extends Equatable {
  ResourceState.initial()
      : isLoading = true,
        key = null,
        value = null,
        source = null,
        error = null;

  ResourceState.loading(K this.key)
      : isLoading = true,
        value = null,
        source = null,
        error = null;

  ResourceState.withValue(
    K this.key,
    V this.value, {
    required this.isLoading,
    required Source this.source,
  }) : error = null;

  ResourceState.withError(
    Object this.error, {
    required this.key,
    required this.isLoading,
  })  : value = null,
        source = null;

  ResourceState.loadingWithValueAndError(
    K this.key,
    V this.value,
    Object this.error, {
    required Source this.source,
  }) : isLoading = true;

  ResourceState._raw(
    this.key,
    this.value,
    this.error, {
    required this.source,
    required this.isLoading,
  });

  final bool isLoading;

  final K? key;
  bool get hasKey => key != null;

  final V? value;
  final Source? source;
  bool get hasValue => source != null;

  final Object? error;
  bool get hasError => error != null;

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
      'isLoading=$isLoading, '
      'key=$key, '
      'value=$value, '
      'source=$source, '
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
