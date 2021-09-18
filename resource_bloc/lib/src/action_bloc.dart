import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

import 'action_handler.dart';
import 'resource_event.dart';

typedef ValueGetter<V> = Future<V> Function();

class ActionHandlerRef<A extends ResourceAction, V> {
  ActionHandlerRef(
    this.handler, {
    required this.transformer,
    required this.getValue,
  });

  final ActionHandler<A, V> handler;
  final EventTransformer<ResourceAction>? transformer;
  final ValueGetter<V> getValue;

  Type get actionType => A;

  void registerOn(ActionBloc<V> bloc) {
    final EventHandler<A, ActionState<V>> _handler = (event, emit) {
      final actionEmit = _ActionEmitter<V>(emit, getValue: getValue);
      return handler(event, actionEmit);
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

class _ActionEmitter<V> extends ActionEmitter<V> {
  _ActionEmitter(
    this.emit, {
    required this.getValue,
  });

  final Emitter<ActionState<V>> emit;
  final ValueGetter<V> getValue;

  @override
  Future<V> get value => getValue();

  @override
  bool get isDone => emit.isDone;

  @override
  Future<void> call(V Function(V value) callback) async {
    final origValue = await value;
    if (!isDone) {
      final newValue = callback(origValue);
      emit(ActionState.value(newValue));
    }
  }
}
