import 'package:mobx/mobx.dart';
import 'package:mobx_resource_bloc/mobx_resource_bloc.dart';
import 'package:resource_bloc/resource_bloc.dart';

abstract class ComputedBaseResourceBloc<K extends Object, V>
    extends BaseResourceBloc<K, V> with ComputedResourceBlocMixin<K, V> {
  ComputedBaseResourceBloc({
    required KeyCallback<K> key,
    InitialValue<K, V>? initialValue,
  }) : this._computed(
          computedKey: Computed(key, name: 'ComputedResourceBloc<$K,$V>.key'),
          initialValue: initialValue,
        );

  ComputedBaseResourceBloc._computed({
    required this.computedKey,
    InitialValue<K, V>? initialValue,
  }) : super.fromState(
          _initialStateFor(computedKey, initialValue),
          initialValue: initialValue,
        );

  @override
  final Computed<K> computedKey;

  static ResourceState<K, V> _initialStateFor<K extends Object, V>(
    Computed<K> computedKey,
    InitialValue<K, V>? initialValue,
  ) {
    try {
      final key = computedKey.value;
      return BaseResourceBloc.initialStateFor(
        key,
        initialValue,
        isLoading: false,
      );
    } on MobXCaughtException catch (e) {
      return ResourceState.withError(e.exception, key: null, isLoading: false);
    }
  }
}

abstract class ComputedResourceBloc<K extends Object, V>
    extends ComputedBaseResourceBloc<K, V> with ReloadResourceBlocMixin {
  ComputedResourceBloc({
    required KeyCallback<K> key,
    InitialValue<K, V>? initialValue,
    OnObservePolicy? onObservePolicy,
  })  : _onObservePolicy = onObservePolicy,
        super(key: key, initialValue: initialValue);

  factory ComputedResourceBloc.from({
    required KeyCallback<K> key,
    required FreshSource<K, V> freshSource,
    required TruthSource<K, V> truthSource,
    InitialValue<K, V>? initialValue,
    OnObservePolicy? onObservePolicy,
  }) = CallbackComputedResourceBloc;

  static OnObservePolicy defaultOnObservePolicy =
      OnObservePolicy.reloadIfCached;

  final OnObservePolicy? _onObservePolicy;

  @override
  OnObservePolicy get onObservePolicy =>
      _onObservePolicy ?? defaultOnObservePolicy;
}

class CallbackComputedResourceBloc<K extends Object, V>
    extends ComputedResourceBloc<K, V> with CallbackResourceBlocMixin<K, V> {
  CallbackComputedResourceBloc({
    required KeyCallback<K> key,
    required this.freshSource,
    required this.truthSource,
    InitialValue<K, V>? initialValue,
    OnObservePolicy? onObservePolicy,
  }) : super(
          key: key,
          initialValue: initialValue,
          onObservePolicy: onObservePolicy,
        );

  @override
  final FreshSource<K, V> freshSource;

  @override
  final TruthSource<K, V> truthSource;
}
