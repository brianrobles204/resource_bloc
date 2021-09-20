import 'dart:async';

abstract class TruthSource<K extends Object, V> {
  TruthSource();

  factory TruthSource.from({
    required TruthReader<K, V> reader,
    required TruthWriter<K, V> writer,
  }) = CallbackTruthSource;

  factory TruthSource.noop() = _NoopTruthSource;

  Stream<V> read(K key);
  FutureOr<void> write(K key, V value);
}

typedef TruthReader<K extends Object, V> = Stream<V> Function(K key);
typedef TruthWriter<K extends Object, V> = FutureOr<void> Function(
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
  FutureOr<void> write(K key, V value) => writer(key, value);
}

class _NoopTruthSource<K extends Object, V> extends TruthSource<K, V> {
  final StreamController<MapEntry<K, V>> _controller =
      StreamController.broadcast();

  @override
  Stream<V> read(K key) => _controller.stream
      .where((entry) => entry.key == key)
      .map((entry) => entry.value);

  @override
  FutureOr<void> write(K key, V value) {
    _controller.sink.add(MapEntry(key, value));
  }
}
