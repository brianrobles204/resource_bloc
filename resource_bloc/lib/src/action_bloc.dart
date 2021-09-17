import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

import 'resource_event.dart';

class ActionHandlerRef<A extends ResourceAction, V> {
  ActionHandlerRef(this.handler, {required this.transformer});

  final EventHandler<A, V> handler;
  final EventTransformer<ResourceAction>? transformer;

  Type get actionType => A;

  void registerOn(ActionBloc<V> bloc) {
    final EventHandler<A, ActionState<V>> _handler = (event, emit) {
      final _emit = _ActionStateEmitter(emit);
      return handler(event, _emit);
    };

    bloc.on<A>(_handler, transformer: transformer);
  }
}

@sealed
abstract class ActionState<V> extends Equatable {
  const ActionState();

  factory ActionState.initial() => _Initial<V>._();

  factory ActionState.value(V _value) => _Value<V>(_value);
}

class _Initial<V> extends ActionState<V> {
  const _Initial._();

  @override
  List<Object?> get props => [];
}

class _Value<V> extends ActionState<V> {
  _Value(this.value);

  final V value;

  @override
  List<Object?> get props => [value];
}

class ActionBloc<V> extends Bloc<ResourceAction, ActionState<V>> {
  ActionBloc(Iterable<ActionHandlerRef<dynamic, V>> handlerRefs)
      : super(ActionState.initial()) {
    for (final handlerRef in handlerRefs) {
      handlerRef.registerOn(this);
    }
  }

  Stream<V> get valueStream =>
      stream.whereType<_Value<V>>().map((state) => state.value);
}

abstract class _MapEmitter<Source, Target> implements Emitter<Target> {
  _MapEmitter(this.source);

  final Emitter<Source> source;

  /// Maps the incoming values from the target emitter into a
  /// type the source can understand.
  Source map(Target value);

  @override
  Future<void> onEach<T>(
    Stream<T> stream, {
    required void Function(T data) onData,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) =>
      source.onEach<T>(stream, onData: onData, onError: onError);

  @override
  Future<void> forEach<T>(
    Stream<T> stream, {
    required Target Function(T data) onData,
    Target Function(Object error, StackTrace stackTrace)? onError,
  }) =>
      source.forEach<T>(
        stream,
        onData: (data) => map(onData(data)),
        onError: onError != null
            ? (error, stacktrace) => map(onError(error, stacktrace))
            : null,
      );

  @override
  bool get isDone => source.isDone;

  @override
  void call(Target state) => source.call(map(state));
}

class _ActionStateEmitter<V> extends _MapEmitter<ActionState<V>, V> {
  _ActionStateEmitter(Emitter<ActionState<V>> source) : super(source);

  @override
  ActionState<V> map(V value) => ActionState.value(value);
}
