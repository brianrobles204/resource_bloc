import 'dart:async';

abstract class TruthSource<K extends Object, V> {
  TruthSource();

  factory TruthSource.from({
    required TruthReader<K, V> reader,
    required TruthWriter<K, V> writer,
  }) = CallbackTruthSource;

  factory TruthSource.noop() = _NoopTruthSource;

  Stream<V> read(K key);
  Future<void> write(K key, V value);
}

typedef TruthReader<K extends Object, V> = Stream<V> Function(K key);
typedef TruthWriter<K extends Object, V> = Future<void> Function(
  K key,
  V value,
);

class CallbackTruthSource<K extends Object, V> extends TruthSource<K, V> {
  CallbackTruthSource({required this.reader, required this.writer});

  final TruthReader<K, V> reader;
  final TruthWriter<K, V> writer;

  @override
  Stream<V> read(K key) => reader(key);

  @override
  Future<void> write(K key, V value) => writer(key, value);
}

class _NoopTruthSource<K extends Object, V> extends TruthSource<K, V> {
  final StreamController<V> _controller = StreamController.broadcast();
  K? _currentKey;

  @override
  Stream<V> read(K key) => _controller.stream.where((_) => key == _currentKey);

  @override
  Future<void> write(K key, V value) async {
    _currentKey = key;
    _controller.sink.add(value);
  }
}
