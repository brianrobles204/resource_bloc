import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

import 'action_bloc.dart';
import 'action_handler.dart';
import 'resource_event.dart';
import 'resource_state.dart';

typedef InitialValue<K extends Object, V> = V? Function(K key);

class _Lock<K extends Object, V> {
  const _Lock.withValue(K this.key, V this.value)
      : hasValue = true,
        isLocked = true;
  const _Lock.locked()
      : key = null,
        value = null,
        hasValue = false,
        isLocked = true;
  const _Lock.unlocked()
      : key = null,
        value = null,
        hasValue = false,
        isLocked = false;

  final K? key;
  final V? value;
  final bool hasValue;
  final bool isLocked;
}

abstract class BaseResourceBloc<K extends Object, V>
    extends Bloc<ResourceEvent, ResourceState<K, V>> {
  BaseResourceBloc({
    K? initialKey,
    this.initialValue,
  }) : super(_initialStateFor(initialKey, initialValue, isLoading: false)) {
    _onSequential<KeyUpdate<K>>(_onKeyUpdate);
    _onSequential<KeyError>(_onKeyError);
    _onSequential<Reload>(_onReload);
    _onSequential<ValueUpdate<K, V>>(_onValueUpdate);
    _onSequential<ErrorUpdate>(_onErrorUpdate);
    _onSequential<ResourceAction>(_onResourceAction);
    _onSequential<TruthSourceUpdate>(_onTruthSourceUpdate);

    if (initialKey != null) {
      _setUpTruthSubscription(initialKey);
    }
  }

  final InitialValue<K, V>? initialValue;

  K? get key => state.key;

  V? get value => state.value;

  @protected
  Stream<V> readFreshSource(K key);

  @protected
  Stream<V> readTruthSource(K key);

  @protected
  FutureOr<void> writeTruthSource(K key, V value);

  final _actionHandlerRefs = <ActionHandlerRef<dynamic, V>>[];
  final _valueLock = BehaviorSubject<_Lock<K, V>>.seeded(_Lock.unlocked());
  bool _isLoadingFresh = false;

  void onAction<A extends ResourceAction>(
    ActionHandler<A, V> handler, {
    EventTransformer<ResourceAction>? transformer,
    CancelCallback<V>? onCancel,
  }) {
    assert(
      !_actionHandlerRefs.any((handlerRef) => handlerRef.actionType == A),
      'onAction<$A> was caught multiple times. '
      'There should only be a single action handler per action type.',
    );

    final handlerRef = ActionHandlerRef<A, V>(
      handler,
      transformer: transformer,
      onCancel: onCancel,
    );

    _actionHandlerRefs.add(handlerRef);
  }

  /// Future that completes when the value is unlocked.
  ///
  /// Value are considered locked while they are being written to the truth
  /// source, and will be unlocked once the value has been emitted from the
  /// truth source.
  ///
  /// The value should only become unlocked once the state updates to the latest
  /// truth value. Consider instead emitting the results of [_flushTruthValue]
  /// if inside mapEventToState or the [on] handler.
  ///
  /// While this is safe to call inside [mapActionToValue], consider yielding
  /// [mappedValue] instead to ensure the correct value is emitted.
  Future<void> _untilValueUnlocked() =>
      _valueLock.firstWhere((lock) => !lock.isLocked);

  Stream<V> _flushTruthValue() async* {
    if (_valueLock.value.isLocked) {
      await _valueLock.firstWhere((lock) => lock.hasValue);
      if (key == _valueLock.value.key) {
        yield _valueLock.value.value!;
      }
      _valueLock.value = _Lock.unlocked();
    }
  }

  ResourceState<K, V> _truthValueToState(V value) {
    assert(key != null);
    if (_isLoadingFresh) {
      return state.copyWithValue(
        value,
        source: Source.cache,
      );
    } else {
      return ResourceState.withValue(
        key!,
        value,
        isLoading: false,
        source: Source.fresh,
      );
    }
  }

  final _eventQueue = BehaviorSubject<List<Object>>.seeded([], sync: true);

  /// Implementation of [on] that processes all events sequentially, even
  /// between different types of events. Similar to the original bloc behavior.
  void _onSequential<E extends ResourceEvent>(
    EventHandler<E, ResourceState<K, V>> handler,
  ) {
    final EventHandler<E, ResourceState<K, V>> _handler = (event, emit) async {
      final queueKey = Object();
      _eventQueue.value = [..._eventQueue.value, queueKey];
      await _eventQueue.firstWhere((queue) => queue.first == queueKey);
      try {
        await handler(event, emit);
      } finally {
        assert(_eventQueue.value.first == queueKey);
        _eventQueue.value = _eventQueue.value.sublist(1);
      }
    };

    on<E>(_handler);
  }

  static ResourceState<K, V> _initialStateFor<K extends Object, V>(
    K? key,
    InitialValue<K, V>? initialValue, {
    required bool isLoading,
  }) {
    if (key != null) {
      final value = () {
        try {
          return initialValue?.call(key);
        } catch (e, s) {
          assert(() {
            print('WARN: Initial value callback threw on key \'$key\'. '
                'Ignoring initial value. Error: $e');
            print(s);
            return true;
          }());
          return null;
        }
      }();

      if (value != null) {
        return ResourceState.withValue(key, value,
            isLoading: isLoading, source: Source.cache);
      }
    }

    return ResourceState.initial(key, isLoading: isLoading);
  }

  StreamSubscription<V>? _truthSubscription;
  StreamSubscription<V>? _freshSubscription;
  ActionBloc<V>? _actionBloc;
  final _freshSource = BehaviorSubject<Stream<V>>();
  final _actionSource = BehaviorSubject<Stream<V>>();

  void _setUpTruthSubscription(K newKey) {
    assert(_truthSubscription == null);
    _truthSubscription = readTruthSource(newKey).listen(
      (value) {
        _valueLock.value = _Lock.withValue(newKey, value);
        add(const TruthSourceUpdate());
      },
      onError: (error) => add(ErrorUpdate(error, isValueValid: false)),
      onDone: () => _valueLock.value = _Lock.unlocked(),
      cancelOnError: true,
    );
  }

  void _setUpActionBloc(K key) {
    assert(_actionBloc == null);

    void assertCorrectKey() {
      if (key != this.key) {
        throw StateError('Tried to read value from a different key.');
      }
    }

    V requireValue() {
      assertCorrectKey();
      return state.requireValue;
    }

    _actionBloc = ActionBloc(
      handlerRefs: _actionHandlerRefs,
      getValue: ({required bool throwIfNone}) async {
        assertCorrectKey();

        if (throwIfNone) {
          return requireValue();
        } else {
          await _untilValueUnlocked();
          assertCorrectKey();
          if (!_isReadyForAction()) {
            await stream
                .firstWhere((state) => _isReadyForAction() || state.key != key);
          }
          return requireValue();
        }
      },
      writeValue: (value) => writeTruthSource(key, value),
    );

    _actionSource.value = _actionBloc!.valueStream;
  }

  bool _isReadyForAction() =>
      state.source == Source.fresh ||
      (state.source == Source.cache && !state.isLoading);

  void _setUpFreshSubscription(K key) {
    assert(_freshSubscription == null);

    void tryUnlockAction() async {
      await _untilValueUnlocked();
      _isLoadingFresh = false;
    }

    final freshActionStream = SwitchLatestStream(_freshSource)
        .asBroadcastStream()
        .doOnData((_) => tryUnlockAction())
        .mergeWith([SwitchLatestStream(_actionSource)]);

    var hasEmittedValue = false;
    _freshSubscription = freshActionStream.listen(
      (value) async {
        await _untilValueUnlocked();
        if (value == state.value && hasEmittedValue) return;
        hasEmittedValue = true;
        add(ValueUpdate(key, value));
      },
      onError: (Object error) async {
        await _untilValueUnlocked();
        add(ErrorUpdate(error, isValueValid: true));
      },
      onDone: () => _isLoadingFresh = false,
      cancelOnError: true,
    );
  }

  FutureOr<void> _onKeyUpdate(
    KeyUpdate<K> event,
    Emitter<ResourceState<K, V>> emit,
  ) async {
    if (key != event.key) {
      await _closeAllSubscriptions();

      emit(_initialStateFor(event.key, initialValue, isLoading: true));

      _isLoadingFresh = true;
      _setUpTruthSubscription(event.key);
      add(Reload());
    } else {
      assert(() {
        print('INFO: Tried to update key, but the new key \'${event.key}\' '
            'matches the current key. Doing nothing.');
        return true;
      }());
    }
  }

  FutureOr<void> _onKeyError(
    KeyError event,
    Emitter<ResourceState<K, V>> emit,
  ) async {
    await _closeAllSubscriptions();

    emit(ResourceState.withError(
      event.error,
      key: null,
      isLoading: false,
    ));
  }

  FutureOr<void> _onReload(
    Reload event,
    Emitter<ResourceState<K, V>> emit,
  ) async {
    if (_freshSubscription != null && _isLoadingFresh) {
      assert(() {
        print('INFO: Tried to reload while already reloading. Doing nothing.');
        return true;
      }());
      return;
    }

    final key = this.key;
    if (key == null) {
      assert(() {
        print('WARN: Tried to reload, but no key is set. Doing nothing.');
        return true;
      }());
      return;
    }

    await emit.forEach<V>(_flushTruthValue(), onData: _truthValueToState);
    emit(state.copyWith(isLoading: true));

    await _closeFreshSubscriptions();
    _isLoadingFresh = true;
    _setUpFreshSubscription(key);

    if (_truthSubscription == null) {
      _setUpTruthSubscription(key);
    }

    _freshSource.value = readFreshSource(key);
  }

  FutureOr<void> _onValueUpdate(
    ValueUpdate<K, V> event,
    Emitter<ResourceState<K, V>> emit,
  ) async {
    if (key != event.key) {
      assert(() {
        print('WARN: Tried to update value, but the current key \'$key\' does '
            'not match the value update key \'${event.key}\'. Doing nothing.');
        return true;
      }());
      return;
    }

    if (_freshSubscription == null) {
      assert(() {
        print('WARN: Tried to update value with event \'$event\', but no fresh '
            'subscription is currently running. Doing nothing.');
        return true;
      }());
      return;
    }

    if (_truthSubscription == null) {
      assert(() {
        print('WARN: Tried to update value with event \'$event\', but no truth '
            'subscription is currently running. Doing nothing.');
        return true;
      }());
      return;
    }

    if (_isLoadingFresh && state.source != Source.fresh) {
      assert(() {
        print('WARN: Tried to update value while the fresh source is running '
            'and no fresh value has been emitted yet. Avoid adding '
            'ValueUpdate() to the bloc directly. Doing nothing.');
        return true;
      }());
      return;
    }

    if (_valueLock.value.isLocked) {
      await _valueLock.firstWhere((lock) => lock.hasValue);
      if (key == _valueLock.value.key) {
        emit(_truthValueToState(_valueLock.value.value!));
      }
    }
    _valueLock.value = _Lock.locked();

    // Write to truth source, but don't await the write
    // This allows other events to be processed
    () async {
      try {
        await writeTruthSource(event.key, event.value);
      } catch (error) {
        add(ErrorUpdate(error, isValueValid: false));
      }
    }();
  }

  FutureOr<void> _onErrorUpdate(
    ErrorUpdate event,
    Emitter<ResourceState<K, V>> emit,
  ) async {
    final cancelValue = await _actionBloc?.cancel();
    if (cancelValue != null) {
      // Use key captured by action bloc write value
      _actionBloc?.writeValue(cancelValue);
    }

    await _closeAllSubscriptions();

    var errorState = state.copyWithError(
      event.error,
      isLoading: false,
      includeValue: event.isValueValid,
    );

    if (cancelValue != null) {
      errorState = errorState.copyWithValue(
        cancelValue,
        source: errorState.source ?? Source.fresh,
      );
    }

    emit(errorState);
  }

  FutureOr<void> _onResourceAction(
    ResourceAction event,
    Emitter<ResourceState<K, V>> emit,
  ) async {
    if (_actionBloc == null) {
      final key = this.key;
      if (key != null) {
        if (_freshSubscription == null) _setUpFreshSubscription(key);
        if (_actionBloc == null) _setUpActionBloc(key);
      } else {
        assert(() {
          print('WARN: Tried to perform a resource action $event, '
              'but no actions can be processed by the bloc. '
              'Try setting a key and / or adding a Reload() event.');
          return true;
        }());
        return;
      }
    }

    _actionBloc!.add(event);
  }

  FutureOr<void> _onTruthSourceUpdate(
    TruthSourceUpdate event,
    Emitter<ResourceState<K, V>> emit,
  ) async {
    await emit.forEach<V>(_flushTruthValue(), onData: _truthValueToState);
  }

  Future<void> _closeActionBloc() async {
    await _actionBloc?.close();
    if (!_actionSource.isClosed) _actionSource.value = Stream.empty();

    _actionBloc = null;
  }

  Future<void> _closeFreshSubscriptions() async {
    await _freshSubscription?.cancel();
    if (!_freshSource.isClosed) _freshSource.value = Stream.empty();

    _freshSubscription = null;
    _isLoadingFresh = false;
  }

  Future<void> _closeAllSubscriptions() async {
    await _truthSubscription?.cancel();
    _truthSubscription = null;

    await _closeFreshSubscriptions();
    await _closeActionBloc();

    if (!_valueLock.isClosed) _valueLock.value = _Lock.unlocked();
  }

  @override
  Future<void> close() async {
    await _closeAllSubscriptions();
    await _freshSource.close();
    await _actionSource.close();
    await _valueLock.close();
    await _eventQueue.close();
    return super.close();
  }
}
