import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

import 'resource_event.dart';
import 'resource_state.dart';

typedef InitialValue<K extends Object, V> = V? Function(K key);

class _Lock<V> {
  const _Lock.withValue(this.value)
      : hasValue = true,
        isLocked = true;
  const _Lock.locked()
      : value = null,
        hasValue = false,
        isLocked = true;
  const _Lock.unlocked()
      : value = null,
        hasValue = false,
        isLocked = false;

  final V? value;
  final bool hasValue;
  final bool isLocked;
}

abstract class BaseResourceBloc<K extends Object, V>
    extends Bloc<ResourceEvent, ResourceState<K, V>> {
  BaseResourceBloc({
    K? initialKey,
    this.initialValue,
  }) : super(_initialStateFor(initialKey, initialValue)) {
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
  /// Must not be awaited inside [mapEventToState], as it may never complete.
  /// The value should only get unlocked once the state updates to the latest
  /// truth value.
  ///
  /// Consider yielding the results of [flushState] if inside mapEventToState.
  ///
  /// While this is safe to call inside [mapActionToValue], consider yielding
  /// [mappedValue] instead to ensure the correct value is emitted.
  @protected
  Future<void> untilValueUnlocked() =>
      _valueLock.firstWhere((lock) => !lock.isLocked);

  @protected
  Stream<ResourceState<K, V>> flushState() async* {
    if (_valueLock.value.isLocked) {
      await _valueLock.firstWhere((lock) => lock.hasValue);
      yield _stateForTruthValue(_valueLock.value.value!);
      _valueLock.value = _Lock.unlocked();
    }
  }

  ResourceState<K, V> _stateForTruthValue(V value) {
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

  final _valueLock = BehaviorSubject<_Lock<V>>.seeded(_Lock.unlocked());

  void _setUpTruthSubscription(K newKey) {
    assert(_truthSubscription == null);
    _truthSubscription = readTruthSource(newKey).listen(
      (value) {
        _valueLock.value = _Lock.withValue(value);
        add(_TruthValue(value));
      },
      onError: (error) => add(ErrorUpdate(error)),
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

    void tryUnlockAction() {
      if (!actionLock.isCompleted) {
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
      onError: (Object error) => add(ErrorUpdate(error)),
      onDone: () => _isLoadingFresh = false,
      cancelOnError: true,
    );
  }

  @override
  @mustCallSuper
  Stream<ResourceState<K, V>> mapEventToState(ResourceEvent event) async* {
    if (event is KeyUpdate<K>) {
      yield* _mapKeyUpdateToState(event);
    } else if (event is KeyError) {
      yield* _mapKeyErrorToState(event);
    } else if (event is Reload) {
      yield* _mapReloadToState();
    } else if (event is ValueUpdate<K, V>) {
      yield* _mapValueUpdateToState(event);
    } else if (event is ErrorUpdate) {
      yield* _mapErrorUpdateToState(event);
    } else if (event is ResourceAction) {
      yield* _mapResourceActionToState(event);
    } else if (event is _TruthValue<V>) {
      yield* _mapTruthValueToState(event);
    }
  }

  Stream<ResourceState<K, V>> _mapKeyUpdateToState(KeyUpdate<K> event) async* {
    if (key != event.key) {
      await _closeAllSubscriptions();

      if (key != null || !state.hasError) {
        yield _initialStateFor(event.key, initialValue);
      } else {
        // Previously with key error. Emit the prior error but with the new key.
        yield ResourceState.withError(
          state.requireError,
          key: event.key,
          isLoading: true,
        );
      }

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

  Stream<ResourceState<K, V>> _mapKeyErrorToState(KeyError event) async* {
    await _closeAllSubscriptions();

    yield ResourceState.withError(
      event.error,
      key: null,
      isLoading: false,
    );
  }

  Stream<ResourceState<K, V>> _mapReloadToState() async* {
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

    yield* flushState();
    yield state.copyWith(isLoading: true);

    await _closeFreshSubscriptions();
    _isLoadingFresh = true;
    _setUpFreshSubscription(key);

    _freshSource.value = readFreshSource(key);
  }

  Stream<ResourceState<K, V>> _mapValueUpdateToState(
    ValueUpdate<K, V> event,
  ) async* {
    if (key != event.key) {
      assert(() {
        print('WARN: Tried to update value, but the current key \'$key\' does '
            'not match the value update key \'${event.key}\'. Doing nothing.');
        return true;
      }());
      return;
    }

    yield* flushState();
    _valueLock.value = _Lock.locked();

    if (_truthSubscription == null) {
      _setUpTruthSubscription(event.key);
    }

    await writeTruthSource(event.key, event.value);
  }

  Stream<ResourceState<K, V>> _mapErrorUpdateToState(ErrorUpdate event) async* {
    await _closeAllSubscriptions();
    yield state.copyWithError(event.error, isLoading: false);
  }

  Stream<ResourceState<K, V>> _mapResourceActionToState(
    ResourceAction event,
  ) async* {
    if (_actionController == null) {
      yield* flushState();
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

  Stream<ResourceState<K, V>> _mapTruthValueToState(_TruthValue event) async* {
    yield* flushState();
  }

  Future<void> _closeAllSubscriptions() async {
    await _closeFreshSubscriptions();

    await _truthSubscription?.cancel();
    _truthSubscription = null;
    if (!_valueLock.isClosed) _valueLock.value = _Lock.unlocked();
  }

  Future<void> _closeFreshSubscriptions() async {
    await _freshSubscription?.cancel();
    await _actionController?.close();
    if (!_freshSource.isClosed) _freshSource.value = Stream.empty();

    _freshSubscription = null;
    _actionController = null;
    _isLoadingFresh = false;
  }

  @override
  Future<void> close() async {
    await _closeAllSubscriptions();
    await _freshSource.close();
    await _valueLock.close();
    return super.close();
  }
}

/// Event added when the truth source emits a new value.
///
/// Private to avoid spoofing of truth value. Only the truth source can
/// emit this event.
class _TruthValue<V> extends ResourceEvent {
  _TruthValue(this.value);

  final V value;

  @override
  List<Object?> get props => [value];
}
