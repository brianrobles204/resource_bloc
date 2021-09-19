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
    final onCancel = this.onCancel;
    final EventHandler<A, ActionState<V>> _handler = (event, emit) async {
      final actionEmit =
          _ActionEmitter<V>(emit, getValue: getValue, onCancel: onCancel);
      final actionHandler = Future(() => handler(event, actionEmit));

      try {
        bloc._emitters.add(actionEmit);
        await actionHandler;
      } catch (e) {
        if (onCancel != null) {
          await actionEmit((value) => onCancel(value));
        } else {
          emit(_Error(e));
        }
      } finally {
        bloc._emitters.remove(emit);
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

  final _emitters = <_ActionEmitter<V>>{};

  @override
  Future<void> close() async {
    if (_emitters.isNotEmpty) {
      try {
        final value = await getValue(throwIfNone: true);

        for (final emit in _emitters.toList()) {
          final onCancel = emit.onCancel;
          if (onCancel != null) {
            try {
              writeValue(onCancel(value));
            } catch (e, s) {
              print('WARN: Error while writing values to truth source during '
                  'bloc close. Error: $e\n$s');
              // Swallow error
            }
          }
          emit.isCancelled = true;
          _emitters.remove(emit);
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
    required this.onCancel,
  });

  final Emitter<ActionState<V>> emit;
  final ValueGetter<V> getValue;
  final CancelCallback<V>? onCancel;
  var isCancelled = false;

  @override
  Future<V> get value => getValue(throwIfNone: false);

  @override
  bool get isDone => emit.isDone;

  @override
  Future<void> call(V Function(V value) callback) async {
    if (isCancelled) return;
    if (isDone) {
      print('''\n\n
emit was called after an action event handler completed normally.
This is usually due to an unawaited future in an event handler.
Please make sure to await all asynchronous operations with event handlers
and use emit.isDone after asynchronous operations before calling emit() to
ensure the event handler has not completed.

  **BAD**
  onAction<ResourceAction>((action, emit) {
    future.whenComplete(() => emit(...));
  });

  **GOOD**
  onAction<ResourceAction>((action, emit) async {
    await future.whenComplete(() => emit(...));
  });
''');
      return;
    }

    final origValue = await value;
    if (!isDone) {
      final newValue = callback(origValue);
      emit(_Value<V>(newValue));
    }
  }
}
