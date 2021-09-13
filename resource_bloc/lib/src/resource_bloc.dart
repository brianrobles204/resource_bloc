import 'base_resource_bloc.dart';
import 'resource_event.dart';
import 'truth_source.dart';

typedef InitialValue<K extends Object, V> = V Function(K key);
typedef FreshSource<K extends Object, V> = Stream<V> Function(K key);

abstract class ResourceBloc<K extends Object, V> extends BaseResourceBloc<K, V>
    with ReloadResourceBlocMixin<K, V>, KeySetterResourceBlocMixin<K, V> {
  ResourceBloc({K? initialKey}) : super(initialKey: initialKey);

  factory ResourceBloc.from({
    required FreshSource<K, V> freshSource,
    required TruthSource<K, V> truthSource,
    InitialValue<K, V>? initialValue,
    K? initialKey,
  }) = CallbackResourceBloc;
}

mixin ReloadResourceBlocMixin<K extends Object, V> on BaseResourceBloc<K, V> {
  void reload() => add(Reload());
}

mixin KeySetterResourceBlocMixin<K extends Object, V>
    on BaseResourceBloc<K, V> {
  set key(K? value) {
    if (value != null) {
      add(KeyUpdate(value));
    } else {
      add(KeyError(StateError('Resource bloc keys cannot be set to null')));
    }
  }

  void applyKey(K Function() callback) {
    try {
      final key = callback();
      add(KeyUpdate(key));
    } catch (error) {
      add(KeyError(error));
    }
  }
}

mixin CallbackResourceBlocMixin<K extends Object, V> on BaseResourceBloc<K, V> {
  InitialValue<K, V>? get initialValue;
  FreshSource<K, V> get freshSource;
  TruthSource<K, V> get truthSource;

  @override
  V? getInitialValue(K key) => initialValue?.call(key);

  @override
  Stream<V> readFreshSource(K key) => freshSource(key);

  @override
  Stream<V> readTruthSource(K key) => truthSource.read(key);

  @override
  Future<void> writeTruthSource(K key, V value) =>
      truthSource.write(key, value);
}

class CallbackResourceBloc<K extends Object, V> extends ResourceBloc<K, V>
    with CallbackResourceBlocMixin<K, V> {
  CallbackResourceBloc({
    required this.freshSource,
    required this.truthSource,
    this.initialValue,
    K? initialKey,
  }) : super(initialKey: initialKey);

  @override
  final InitialValue<K, V>? initialValue;

  @override
  final FreshSource<K, V> freshSource;

  @override
  final TruthSource<K, V> truthSource;
}
