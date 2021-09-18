import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

import 'action_handler.dart';
import 'resource_event.dart';

typedef ValueGetter<V> = Future<V> Function({required bool throwIfNone});

typedef ValueWriter<V> = void Function(V value);

class ActionHandlerRef<A extends ResourceAction, V> {
  ActionHandlerRef(
    this.handler, {
    required this.transformer,
    required this.onCancel,
  });

  final ActionHandler<A, V> handler;
  final EventTransformer<ResourceAction>? transformer;
  final CancelCallback<V>? onCancel;

  Type get actionType => A;

  void registerOn(ActionBloc<V> bloc, {required ValueGetter<V> getValue}) {
    final EventHandler<A, ActionState<V>> _handler = (event, emit) async {
      final actionEmit = _ActionEmitter<V>(emit, getValue: getValue);
      final actionHandler = handler(event, actionEmit);
      final onCancel = this.onCancel;

      if (onCancel != null) {
        try {
          bloc._cancelCallbacks[emit] = onCancel;
          await actionHandler;
        } catch (e) {
          await actionEmit((value) => onCancel(value));
        } finally {
          bloc._cancelCallbacks.remove(emit);
        }
      } else {
        return actionHandler;
      }
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
  ActionBloc({
    required Iterable<ActionHandlerRef<dynamic, V>> handlerRefs,
    required this.getValue,
    required this.writeValue,
  }) : super(ActionState.initial()) {
    for (final handlerRef in handlerRefs) {
      handlerRef.registerOn(this, getValue: getValue);
    }
  }

  final ValueGetter<V> getValue;
  final ValueWriter<V> writeValue;

  Stream<V> get valueStream =>
      stream.whereType<_Value<V>>().map((state) => state.value);

  final _cancelCallbacks = <Object, CancelCallback<V>>{};

  @override
  Future<void> close() async {
    if (_cancelCallbacks.isNotEmpty) {
      try {
        final value = await getValue(throwIfNone: true);

        for (final callback in List.of(_cancelCallbacks.values)) {
          try {
            writeValue(callback(value));
          } catch (e, s) {
            print('WARN: Error while writing values to truth source during '
                'bloc close. Error: $e\n$s');
            // Swallow error
          }
        }
      } catch (e, s) {
        print('INFO: No value available for cancel callback. Error: $e\n$s');
        // Swallow error
      }
    }
    return super.close();
  }
}

class _ActionEmitter<V> extends ActionEmitter<V> {
  _ActionEmitter(
    this.emit, {
    required this.getValue,
  });

  final Emitter<ActionState<V>> emit;
  final ValueGetter<V> getValue;

  @override
  Future<V> get value => getValue(throwIfNone: false);

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
