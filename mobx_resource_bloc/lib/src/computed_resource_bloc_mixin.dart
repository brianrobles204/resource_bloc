import 'package:mobx/mobx.dart';
import 'package:mobx_resource_bloc/src/autorun_while_active_stream.dart';
import 'package:resource_bloc/resource_bloc.dart';

typedef KeyCallback<K> = K Function();

mixin ComputedResourceBlocMixin<K extends Object, V> on BaseResourceBloc<K, V> {
  Computed<K> get computedKey;

  void keyUpdateAutorun() {
    try {
      final key = computedKey.value;
      final currentState = super.state;

      if (!currentState.isLoading && currentState.key == key) {
        add(Reload());
      } else if (key != super.state.key) {
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

  ResourceState<K, V> get _fallbackState => super.state;

  bool get _shouldFallbackLoad =>
      _isKeyUpdateRunning && !super.state.isLoading && super.state.hasKey;

  @override
  ResourceState<K, V> get state {
    final currentState = _state.value;
    if (!mainContext.isComputingDerivation() && _shouldFallbackLoad) {
      // Only show fallback loading if inside MobX derivation
      // Ordinary calls to state should show the original state
      return currentState.copyWith(isLoading: false);
    } else {
      return currentState;
    }
  }

  late final _state = Computed(
    () =>
        stream.value ??
        // If stream has no value, listening or observing stream should start a
        // load. Set fallback to reflect incoming load state.
        _fallbackState.copyWith(isLoading: _shouldFallbackLoad ? true : null),
    name: 'ComputedResourceBloc<$K,$V>.state',
  );

  @override
  K? get key => _key.value;
  late final _key = Computed(
    () => (stream.value ?? _fallbackState).key,
    name: 'ComputedResourceBloc<$K,$V>.key',
  );

  @override
  V? get value => _value.value;
  late final _value = Computed(
    () => (stream.value ?? _fallbackState).value,
    name: 'ComputedResourceBloc<$K,$V>.value',
  );

  @override
  Future<void> close() async {
    await stream.close();
    return super.close();
  }
}
