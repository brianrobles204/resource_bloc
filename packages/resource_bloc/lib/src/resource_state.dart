import 'package:equatable/equatable.dart';

enum Source { fresh, cache }

class StateSnapshot<V> extends Equatable {
  StateSnapshot.notLoading()
      : isLoading = false,
        value = null,
        source = null,
        error = null;

  StateSnapshot.loading()
      : isLoading = true,
        value = null,
        source = null,
        error = null;

  StateSnapshot.withValue(
    V this.value, {
    required this.isLoading,
    required Source this.source,
  }) : error = null;

  StateSnapshot.withError(
    Object this.error, {
    required this.isLoading,
  })  : value = null,
        source = null;

  StateSnapshot.withValueAndError(
    V this.value,
    Object this.error, {
    required Source this.source,
    required this.isLoading,
  });

  StateSnapshot._raw(
    this.value,
    this.error, {
    required this.source,
    required this.isLoading,
  });

  final bool isLoading;

  final V? value;
  final Source? source;
  bool get hasValue => source != null;

  final Object? error;
  bool get hasError => error != null;

  StateSnapshot<N> map<N>(N Function(V value) callback) => StateSnapshot._raw(
        hasValue ? callback(value as V) : null,
        error,
        isLoading: isLoading,
        source: hasValue ? source : null,
      );

  StateSnapshot<V> copyWith({
    bool? isLoading,
    bool includeValue = true,
    bool includeError = true,
  }) =>
      StateSnapshot._raw(
        includeValue ? value : null,
        includeError ? error : null,
        isLoading: isLoading ?? this.isLoading,
        source: includeValue ? source : null,
      );

  StateSnapshot<V> copyWithValue(
    V value, {
    required Source source,
    bool? isLoading,
    bool includeError = true,
  }) =>
      StateSnapshot._raw(
        value,
        includeError ? error : null,
        isLoading: isLoading ?? this.isLoading,
        source: source,
      );

  StateSnapshot<V> copyWithError(
    Object error, {
    bool? isLoading,
    bool includeValue = true,
  }) =>
      StateSnapshot._raw(
        includeValue ? value : null,
        error,
        isLoading: isLoading ?? this.isLoading,
        source: includeValue ? source : null,
      );

  @override
  List<Object?> get props => [isLoading, value, source, error];

  @override
  String toString() => '$runtimeType('
      'isLoading=$isLoading, '
      'value=$value, '
      'source=$source, '
      'error=$error'
      ')';
}

class ResourceState<K extends Object, V> extends StateSnapshot<V> {
  ResourceState.initial(
    this.key, {
    required bool isLoading,
  }) : super._raw(null, null, source: null, isLoading: isLoading);

  ResourceState.withValue(
    K this.key,
    V value, {
    required bool isLoading,
    required Source source,
  }) : super.withValue(value, isLoading: isLoading, source: source);

  ResourceState.withError(
    Object error, {
    required this.key,
    required bool isLoading,
  }) : super.withError(error, isLoading: isLoading);

  ResourceState.withValueAndError(
    K this.key,
    V value,
    Object error, {
    required Source source,
    required bool isLoading,
  }) : super.withValueAndError(
          value,
          error,
          source: source,
          isLoading: isLoading,
        );

  ResourceState._raw(
    this.key,
    V? value,
    Object? error, {
    required Source? source,
    required bool isLoading,
  }) : super._raw(value, error, source: source, isLoading: isLoading);

  final K? key;
  bool get hasKey => key != null;

  @override
  ResourceState<K, N> map<N>(N Function(V value) callback) =>
      ResourceState._raw(
        key,
        hasValue ? callback(value as V) : null,
        error,
        isLoading: isLoading,
        source: hasValue ? source : null,
      );

  @override
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

  @override
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

  @override
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
  List<Object?> get props => [key, ...super.props];

  @override
  String toString() => '$runtimeType('
      'isLoading=$isLoading, '
      'key=$key, '
      'value=$value, '
      'source=$source, '
      'error=$error'
      ')';
}

extension StateSnapshotExtensions<V> on StateSnapshot<V> {
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

extension ResourceStateRequireExtensions<K extends Object, V>
    on ResourceState<K, V> {
  K get requireKey {
    if (hasKey) {
      return key!;
    } else {
      throw StateError('$this has no key');
    }
  }
}
