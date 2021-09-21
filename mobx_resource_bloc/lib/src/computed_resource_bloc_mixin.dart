import 'package:mobx/mobx.dart';
import 'package:mobx_resource_bloc/src/autorun_while_active_stream.dart';
import 'package:resource_bloc/resource_bloc.dart';

typedef KeyCallback<K> = K Function();

mixin ComputedResourceBlocMixin<K extends Object, V> on BaseResourceBloc<K, V> {
  KeyCallback<K> get keyCallback;

  void _updateKey() {
    try {
      final key = keyCallback();
      add(KeyUpdate(key));
    } catch (error) {
      add(KeyError(error));
    }
  }

  @override
  ObservableStream<ResourceState<K, V>> get stream =>
      _stream ??= AutorunWhileActiveStream(
        (_) => _updateKey(),
        super.stream,
      ).asObservable(
        initialValue: super.state,
        name: 'ComputedResourceBloc<$K,$V>.stream',
      );
  ObservableStream<ResourceState<K, V>>? _stream;

  @override
  ResourceState<K, V> get state => _state.value;
  late final _state =
      Computed(() => stream.value!, name: 'ComputedResourceBloc<$K,$V>.state');

  @override
  K? get key => _key.value;
  late final _key =
      Computed(() => state.key, name: 'ComputedResourceBloc<$K,$V>.key');

  @override
  V? get value => _value.value;
  late final _value =
      Computed(() => state.value, name: 'ComputedResourceBloc<$K,$V>.value');
}
