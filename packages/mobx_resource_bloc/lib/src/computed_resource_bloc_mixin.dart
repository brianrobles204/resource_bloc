import 'package:mobx/mobx.dart';
import 'package:resource_bloc/resource_bloc.dart';

import 'autorun_while_active_stream.dart';
import 'do_stream_transformer.dart';

typedef KeyCallback<K> = K Function();

/// Behavior when the bloc is observed, either via `stream.listen` or by
/// observing computed properties (such as `state`, etc.) inside a MobX reaction
enum OnObservePolicy {
  /// Always reload when the bloc is observed, even if there is a value from
  /// a fresh source available.
  reloadAlways,

  /// Reload only if the value is cached (or there is no value).
  /// If there is a fresh value already available, the bloc will not reload.
  reloadIfCached,

  /// Reload only if there is no value. If there is an existing fresh or
  /// cache value, the bloc will not be reloaded when it is observed.
  reloadIfEmpty,

  /// Never reload the bloc when it is observed. Useful if you prefer to
  /// control when the bloc reloads manually.
  ///
  /// Note that if the key changed while the bloc was unobserved, a [KeyUpdate]
  /// event will still be added to the bloc once it is observed.
  reloadNever,
}

mixin ComputedResourceBlocMixin<K extends Object, V> on BaseResourceBloc<K, V> {
  Computed<K> get computedKey;

  OnObservePolicy get onObservePolicy;

  bool get _shouldReload {
    switch (onObservePolicy) {
      case OnObservePolicy.reloadAlways:
        return true;
      case OnObservePolicy.reloadIfCached:
        return super.state.source != Source.fresh;
      case OnObservePolicy.reloadIfEmpty:
        return !super.state.hasValue;
      case OnObservePolicy.reloadNever:
        return false;
    }
  }

  void keyUpdateAutorun() {
    try {
      final key = computedKey.value;
      final currentState = super.state;

      if (!currentState.isLoading && currentState.key == key) {
        if (_shouldReload) {
          add(Reload());
        }
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

  var _hasStreamValue = false;
  ResourceState<K, V> get _streamValue {
    final streamValue = stream.value; // read unconditionally
    return _hasStreamValue ? streamValue! : super.state;
  }

  @override
  ObservableStream<ResourceState<K, V>> get stream => _stream ??= super
      .stream
      .autorunWhileActive(
        (_) => keyUpdateAutorun(),
        onUpdate: (isRunning) => _isKeyUpdateRunning = isRunning,
      )
      .doOn(
        onData: (_) => _hasStreamValue = true,
        onCancel: () => _hasStreamValue = false,
      )
      .asObservable(name: 'ComputedResourceBloc<$K,$V>.stream');
  ObservableStream<ResourceState<K, V>>? _stream;

  bool get _shouldFallbackLoad =>
      _isKeyUpdateRunning &&
      !super.state.isLoading &&
      super.state.hasKey &&
      _shouldReload;

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
    () => _streamValue.copyWith(
      // If stream has no value, listening or observing stream should start
      // a load. Reflect incoming load state in such cases.
      isLoading: !_hasStreamValue && _shouldFallbackLoad ? true : null,
    ),
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

  @override
  Future<void> close() async {
    await stream.close();
    return super.close();
  }
}
