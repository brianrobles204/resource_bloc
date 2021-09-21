import 'package:mobx_resource_bloc/mobx_resource_bloc.dart';
import 'package:resource_bloc/resource_bloc.dart';

abstract class ComputedBaseResourceBloc<K extends Object, V> = BaseResourceBloc<
    K, V> with ComputedResourceBlocMixin<K, V>;

abstract class ComputedResourceBloc<K extends Object, V>
    extends ComputedBaseResourceBloc<K, V> with ReloadResourceBlocMixin {
  ComputedResourceBloc(
    this.keyCallback, {
    InitialValue<K, V>? initialValue,
  }) : super(initialValue: initialValue);

  factory ComputedResourceBloc.from(
    KeyCallback<K> keyCallback, {
    required FreshSource<K, V> freshSource,
    required TruthSource<K, V> truthSource,
    InitialValue<K, V>? initialValue,
  }) = CallbackComputedResourceBloc;

  @override
  final KeyCallback<K> keyCallback;
}

class CallbackComputedResourceBloc<K extends Object, V>
    extends ComputedResourceBloc<K, V> with CallbackResourceBlocMixin<K, V> {
  CallbackComputedResourceBloc(
    KeyCallback<K> keyCallback, {
    required this.freshSource,
    required this.truthSource,
    InitialValue<K, V>? initialValue,
  }) : super(
          keyCallback,
          initialValue: initialValue,
        );

  @override
  final FreshSource<K, V> freshSource;

  @override
  final TruthSource<K, V> truthSource;
}
