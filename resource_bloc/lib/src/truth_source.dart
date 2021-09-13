import 'dart:async';

import 'base_resource_bloc.dart';

abstract class TruthSource<K extends Object, V> {
  TruthSource();

  factory TruthSource.from({
    required TruthReader<K, V> reader,
    required TruthWriter<K, V> writer,
  }) = CallbackTruthSource;

  factory TruthSource.noop() = _NoopTruthSource;

  Stream<Result<V>> read(K key);
  Future<void> write(K key, V value, DateTime date);
}

typedef TruthReader<K extends Object, V> = Stream<Result<V>> Function(K key);
typedef TruthWriter<K extends Object, V> = Future<void> Function(
  K key,
  V value,
  DateTime date,
);

class CallbackTruthSource<K extends Object, V> extends TruthSource<K, V> {
  CallbackTruthSource({required this.reader, required this.writer});

  final TruthReader<K, V> reader;
  final TruthWriter<K, V> writer;

  @override
  Stream<Result<V>> read(K key) => reader(key);

  @override
  Future<void> write(K key, V value, DateTime date) => writer(key, value, date);
}

class _NoopTruthSource<K extends Object, V> extends TruthSource<K, V> {
  final StreamController<Result<V>> _controller = StreamController.broadcast();
  K? _currentKey;

  @override
  Stream<Result<V>> read(K key) =>
      _controller.stream.where((_) => key == _currentKey);

  @override
  Future<void> write(K key, V value, DateTime date) async {
    _currentKey = key;
    _controller.sink.add(Result(value, date));
  }
}
