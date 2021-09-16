import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

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

final EventTransformer<ResourceEvent> _restartable =
    (events, mapper) => events.switchMap(mapper);
final EventTransformer<ResourceEvent> _sequential =
    (events, mapper) => events.asyncExpand(mapper);

abstract class BaseResourceBloc<K extends Object, V>
    extends Bloc<ResourceEvent, ResourceState<K, V>> {
  BaseResourceBloc({
    K? initialKey,
    this.initialValue,
  }) : super(_initialStateFor(initialKey, initialValue)) {
    on<KeyUpdate<K>>(_onKeyUpdate, transformer: _restartable);
    on<KeyError>(_onKeyError, transformer: _restartable);
    on<Reload>(_onReload, transformer: _sequential);
    on<ValueUpdate<K, V>>(_onValueUpdate, transformer: _sequential);
    on<ErrorUpdate>(_onErrorUpdate, transformer: _restartable);
    on<ResourceAction>(_onResourceAction, transformer: _sequential);
    on<TruthSourceUpdate>(_onTruthSourceUpdate, transformer: _sequential);

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
  Future<void> writeTruthSource(K key, V value);

  @protected
  Stream<V> transformActions(
    Stream<ResourceAction> actions,
    Stream<V> Function(ResourceAction) mapper,
  ) {
    return actions.flatMap(mapper);
  }

  @protected
  Stream<V> mapActionToValue(ResourceAction action) async* {
    // NO OP
  }

  @protected
  Stream<V> mappedValue(V Function(V value) mapper) async* {
    await untilValueUnlocked();
    if (state.hasValue) {
      yield mapper(state.requireValue);
    }
  }

  /// Future that completes when the value is unlocked.
  ///
  /// Value are considered locked while they are being written to the truth
  /// source, and will be unlocked once the value has been emitted from the
  /// truth source.
  ///
  /// The value should only become unlocked once the state updates to the latest
  /// truth value. Consider instead emitting the results of [flushTruthValue]
  /// if inside mapEventToState or the [on] handler.
  ///
  /// While this is safe to call inside [mapActionToValue], consider yielding
  /// [mappedValue] instead to ensure the correct value is emitted.
  @protected
  Future<void> untilValueUnlocked() =>
      _valueLock.firstWhere((lock) => !lock.isLocked);

  @protected
  Stream<V> flushTruthValue() async* {
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

  static ResourceState<K, V> _initialStateFor<K extends Object, V>(
    K? key,
    InitialValue<K, V>? initialValue,
  ) {
    if (key == null) {
      return ResourceState.initial();
    } else {
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
            isLoading: true, source: Source.fresh);
      } else {
        return ResourceState.loading(key);
      }
    }
  }

  StreamSubscription<V>? _truthSubscription;
  StreamSubscription<V>? _freshSubscription;
  StreamController<ResourceAction>? _actionController;
  final _freshSource = BehaviorSubject<Stream<V>>();
  bool _isLoadingFresh = false;

  final _valueLock = BehaviorSubject<_Lock<K, V>>.seeded(_Lock.unlocked());

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

  void _setUpFreshSubscription(K key) {
    assert(_freshSubscription == null);
    assert(_actionController == null);

    _actionController = ReplaySubject();
    final actionLock = Completer();
    final actionStream = () async* {
      await actionLock.future;
      yield* transformActions(
        _actionController!.stream,
        mapActionToValue,
      );
    }();

    void tryUnlockAction() async {
      if (!actionLock.isCompleted) {
        await untilValueUnlocked();
        _isLoadingFresh = false;
        actionLock.complete();
      }
    }

    if (!_isLoadingFresh) {
      tryUnlockAction();
    }

    final freshActionStream = SwitchLatestStream(_freshSource)
        .asBroadcastStream()
        .doOnData((_) => tryUnlockAction())
        .mergeWith([actionStream]);

    var hasEmittedValue = false;
    _freshSubscription = freshActionStream.listen(
      (value) async {
        await untilValueUnlocked();
        if (value == state.value && hasEmittedValue) return;
        hasEmittedValue = true;
        add(ValueUpdate(key, value));
      },
      onError: (Object error) => add(ErrorUpdate(error, isValueValid: true)),
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

      emit(_initialStateFor(event.key, initialValue));

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

    await emit.forEach<V>(flushTruthValue(), onData: _truthValueToState);
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

    if (_isLoadingFresh) {
      assert(() {
        print('WARN: Tried to update value while the fresh source is running '
            'and no fresh value has been emitted yet. Avoid adding '
            'ValueUpdate() to the bloc directly. Doing nothing.');
        return true;
      }());
      return;
    }

    await emit.forEach<V>(flushTruthValue(), onData: _truthValueToState);
    _valueLock.value = _Lock.locked();

    // Write to truth source, but don't await the write
    // This allows other events to be processed
    writeTruthSource(event.key, event.value)
        .catchError((error) => add(ErrorUpdate(error, isValueValid: false)));
  }

  FutureOr<void> _onErrorUpdate(
    ErrorUpdate event,
    Emitter<ResourceState<K, V>> emit,
  ) async {
    await _closeAllSubscriptions();

    emit(state.copyWithError(
      event.error,
      isLoading: false,
      includeValue: event.isValueValid,
    ));
  }

  FutureOr<void> _onResourceAction(
    ResourceAction event,
    Emitter<ResourceState<K, V>> emit,
  ) async {
    if (_actionController == null) {
      await emit.forEach<V>(flushTruthValue(), onData: _truthValueToState);
      final key = this.key;
      final value = this.value;
      if (key != null && value != null) {
        _setUpFreshSubscription(key);
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

    _actionController!.sink.add(event);
  }

  FutureOr<void> _onTruthSourceUpdate(
    TruthSourceUpdate event,
    Emitter<ResourceState<K, V>> emit,
  ) async {
    await emit.forEach<V>(flushTruthValue(), onData: _truthValueToState);
  }

  Future<void> _closeFreshSubscriptions() async {
    await _freshSubscription?.cancel();
    await _actionController?.close();
    if (!_freshSource.isClosed) _freshSource.value = Stream.empty();

    _freshSubscription = null;
    _actionController = null;
    _isLoadingFresh = false;
  }

  Future<void> _closeAllSubscriptions() async {
    await _closeFreshSubscriptions();

    await _truthSubscription?.cancel();
    _truthSubscription = null;
    if (!_valueLock.isClosed) _valueLock.value = _Lock.unlocked();
  }

  @override
  Future<void> close() async {
    await _closeAllSubscriptions();
    await _freshSource.close();
    await _valueLock.close();
    return super.close();
  }
}
