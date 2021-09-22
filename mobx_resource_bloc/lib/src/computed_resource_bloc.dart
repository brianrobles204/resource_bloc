import 'package:mobx/mobx.dart';
import 'package:mobx_resource_bloc/mobx_resource_bloc.dart';
import 'package:resource_bloc/resource_bloc.dart';

abstract class ComputedBaseResourceBloc<K extends Object, V>
    extends BaseResourceBloc<K, V> with ComputedResourceBlocMixin<K, V> {
  ComputedBaseResourceBloc({
    required KeyCallback<K> key,
    InitialValue<K, V>? initialValue,
  }) : this.computed(
          computedKey: Computed(key, name: 'ComputedResourceBloc<$K,$V>.key'),
          initialValue: initialValue,
        );

  ComputedBaseResourceBloc.computed({
    required this.computedKey,
    InitialValue<K, V>? initialValue,
  }) : super(
          initialKey: computedKey.value,
          initialValue: initialValue,
        );

  @override
  final Computed<K> computedKey;
}

abstract class ComputedResourceBloc<K extends Object, V>
    extends ComputedBaseResourceBloc<K, V> with ReloadResourceBlocMixin {
  ComputedResourceBloc({
    required KeyCallback<K> key,
    InitialValue<K, V>? initialValue,
  }) : super(key: key, initialValue: initialValue);

  factory ComputedResourceBloc.from({
    required KeyCallback<K> key,
    required FreshSource<K, V> freshSource,
    required TruthSource<K, V> truthSource,
    InitialValue<K, V>? initialValue,
  }) = CallbackComputedResourceBloc;
}

class CallbackComputedResourceBloc<K extends Object, V>
    extends ComputedResourceBloc<K, V> with CallbackResourceBlocMixin<K, V> {
  CallbackComputedResourceBloc({
    required KeyCallback<K> key,
    required this.freshSource,
    required this.truthSource,
    InitialValue<K, V>? initialValue,
  }) : super(key: key, initialValue: initialValue);

  @override
  final FreshSource<K, V> freshSource;

  @override
  final TruthSource<K, V> truthSource;
}
