import 'package:mobx/mobx.dart';
import 'package:mobx_resource_bloc/src/autorun_while_active_stream.dart';
import 'package:resource_bloc/resource_bloc.dart';

typedef KeyCallback<K> = K Function();

mixin ComputedResourceBlocMixin<K extends Object, V> on BaseResourceBloc<K, V> {
  Computed<K> get computedKey;

  void keyUpdateAutorun() {
    try {
      final key = computedKey.value;
      final initialState = BaseResourceBloc.initialStateFor<K, V>(
        key,
        initialValue,
        isLoading: false,
      );

      if (super.state == initialState) {
        add(Reload());
      } else {
        add(KeyUpdate(key));
      }
    } on MobXCaughtException catch (error) {
      add(KeyError(error.exception));
    } catch (error) {
      add(KeyError(error));
    }
  }

  var _isKeyUpdateRunning = false;

  @override
  ObservableStream<ResourceState<K, V>> get stream => _stream ??= super
      .stream
      .autorunWhileActive(
        (_) => keyUpdateAutorun(),
        onUpdate: (isRunning) => _isKeyUpdateRunning = isRunning,
      )
      .asObservable(name: 'ComputedResourceBloc<$K,$V>.stream');
  ObservableStream<ResourceState<K, V>>? _stream;

  ResourceState<K, V> get _streamValue {
    return stream.value ??
        () {
          if (_isKeyUpdateRunning &&
              super.state == initialState(isLoading: false)) {
            return initialState(isLoading: true);
          } else {
            return super.state;
          }
        }();
  }

  @override
  ResourceState<K, V> get state => _state.value;
  late final _state = Computed(
    () => _streamValue,
    name: 'ComputedResourceBloc<$K,$V>.state',
  );

  @override
  K? get key => _key.value;
  late final _key = Computed(
    () => _streamValue.key,
    name: 'ComputedResourceBloc<$K,$V>.key',
  );

  @override
  V? get value => _value.value;
  late final _value = Computed(
    () => _streamValue.value,
    name: 'ComputedResourceBloc<$K,$V>.value',
  );
}
