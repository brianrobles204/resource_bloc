import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

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
      final actionHandler = Future(() => handler(event, actionEmit));
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
        try {
          await actionHandler;
        } catch (e) {
          emit(_Error(e));
        }
      }
    };

    bloc.on<A>(_handler, transformer: transformer);
  }
}

@sealed
abstract class ActionState<V> extends Equatable {
  const ActionState();
}

class _Initial<V> extends ActionState<V> {
  const _Initial();

  @override
  List<Object?> get props => [];
}

class _Value<V> extends ActionState<V> {
  _Value(this.value);

  final V value;

  @override
  List<Object?> get props => [value];
}

class _Error<V> extends ActionState<V> {
  _Error(this.error);

  final Object error;

  @override
  List<Object?> get props => [error];
}

class ActionBloc<V> extends Bloc<ResourceAction, ActionState<V>> {
  ActionBloc({
    required Iterable<ActionHandlerRef<dynamic, V>> handlerRefs,
    required this.getValue,
    required this.writeValue,
  }) : super(_Initial<V>()) {
    for (final handlerRef in handlerRefs) {
      handlerRef.registerOn(this, getValue: getValue);
    }
  }

  final ValueGetter<V> getValue;
  final ValueWriter<V> writeValue;

  V _toValue(ActionState<V> state) {
    if (state is _Value<V>) {
      return state.value;
    } else {
      if (state is _Error<V>) {
        throw state.error;
      } else {
        throw StateError('The bloc has no valid value');
      }
    }
  }

  Stream<V> get valueStream => stream
      .where((state) => state is _Value<V> || state is _Error<V>)
      .map(_toValue);

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
      emit(_Value<V>(newValue));
    }
  }
}
