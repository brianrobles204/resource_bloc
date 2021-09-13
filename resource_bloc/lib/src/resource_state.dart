import 'package:equatable/equatable.dart';

class ResourceState<K extends Object, V> extends Equatable {
  ResourceState.initial()
      : isLoading = true,
        key = null,
        hasKey = false,
        hasValue = false,
        value = null,
        info = null,
        hasError = false,
        error = null;

  ResourceState.loading(K key)
      : isLoading = true,
        key = key,
        hasKey = true,
        hasValue = false,
        value = null,
        info = null,
        hasError = false,
        error = null;

  ResourceState.withValue(
    K key,
    V value, {
    required this.isLoading,
    required Source source,
    required DateTime date,
  })  : value = value,
        info = ValueInfo._(source, date),
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
        info = null;

  ResourceState.loadingWithValueAndError(
    K key,
    V value,
    Object error, {
    required Source source,
    required DateTime date,
  })  : key = key,
        value = value,
        isLoading = true,
        info = ValueInfo._(source, date),
        error = error,
        hasKey = true,
        hasValue = true,
        hasError = true;

  ResourceState._raw(
    this.key,
    this.value,
    this.error, {
    required this.isLoading,
    required this.info,
  })  : hasKey = key != null,
        hasValue = info != null,
        hasError = error != null;

  final bool hasKey;
  final K? key;

  final bool isLoading;

  final bool hasValue;
  final V? value;
  final ValueInfo? info;

  final bool hasError;
  final Object? error;

  ResourceState<K, N> map<N>(N Function(V value) callback) =>
      ResourceState._raw(
        key,
        hasValue ? callback(value as V) : null,
        error,
        isLoading: isLoading,
        info: hasValue ? info : null,
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
        info: includeValue ? info : null,
      );

  ResourceState<K, V> copyWithValue(
    V value, {
    required Source source,
    required DateTime date,
    bool? isLoading,
    bool includeError = true,
  }) =>
      ResourceState._raw(
        key,
        value,
        includeError ? error : null,
        isLoading: isLoading ?? this.isLoading,
        info: ValueInfo._(source, date),
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
        info: includeValue ? info : null,
      );

  @override
  List<Object?> get props =>
      [isLoading, hasValue, value, info, hasError, error];

  @override
  String toString() => '$runtimeType('
      'hasKey=$hasKey, '
      'key=$key, '
      'isLoading=$isLoading, '
      'hasValue=$hasValue, '
      'value=$value, '
      'info=$info, '
      'hasError=$hasError, '
      'error=$error'
      ')';
}

enum Source { fresh, cache }

class ValueInfo extends Equatable {
  ValueInfo._(this.source, this.date);

  final Source source;
  final DateTime date;

  @override
  List<Object?> get props => [source, date];

  @override
  bool? get stringify => true;
}

extension ResourceStateRequireExtensions<K extends Object, V>
    on ResourceState<K, V> {
  V get requireValue {
    if (hasValue) {
      return value as V;
    } else {
      throw StateError('$this has no value');
    }
  }

  ValueInfo get requireInfo {
    if (hasValue) {
      return info!;
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
