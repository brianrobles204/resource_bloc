import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

import 'resource_event.dart';
import 'resource_state.dart';

typedef InitialValue<K extends Object, V> = V? Function(K key);

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

  StreamSubscription<V>? _truthSubscription;
  StreamSubscription<V>? _freshSubscription;
  StreamController<ResourceAction>? _actionController;
  bool _isLoadingFresh = false;

  final _valueLock = BehaviorSubject.seeded(false);
  Future<void> _untilValueUnlocked() =>
      _valueLock.firstWhere((isLocked) => !isLocked);

  @protected
  Future<V?> get truthValue async {
    await _untilValueUnlocked();
    return state.value;
  }

  @protected
  Stream<V> readFreshSource(K key);

  @protected
  Stream<V> readTruthSource(K key);

  @protected
  Future<void> writeTruthSource(K key, V value);

  @protected
  Stream<V> mappedValue(V Function(V value) mapper) async* {
    await _untilValueUnlocked();
    if (state.hasValue) {
      yield mapper(state.requireValue);
    }
  }

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

  void _setUpTruthSubscription(K newKey) {
    _truthSubscription = readTruthSource(newKey).listen(
      (value) => add(_TruthValue(value)),
      onError: (error) => add(ErrorUpdate(error)),
      onDone: () => _valueLock.value = false,
      cancelOnError: true,
    );
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
        } catch (e) {
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
    await _freshSubscription?.cancel();
    await _truthSubscription?.cancel();

    if (key != event.key) {
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
    await _freshSubscription?.cancel();
    await _truthSubscription?.cancel();

    yield ResourceState.withError(
      event.error,
      key: null,
      isLoading: false,
    );
  }

  Stream<ResourceState<K, V>> _mapReloadToState() async* {
    final key = this.key;
    if (key == null) {
      assert(() {
        print('WARN: Tried to reload, but no key is set. Doing nothing.');
        return true;
      }());
      return;
    }

    yield state.copyWith(isLoading: true);

    await _freshSubscription?.cancel();
    await _actionController?.close();
    _isLoadingFresh = true;

    _actionController = ReplaySubject();
    final actionLock = Completer();
    final actionStream = () async* {
      await actionLock.future;
      yield* transformActions(
        _actionController!.stream,
        mapActionToValue,
      );
    }();

    final freshActionStream = readFreshSource(key).doOnData(
      (value) {
        if (_isLoadingFresh) {
          _isLoadingFresh = false;
          actionLock.complete();
        }
      },
    ).mergeWith([actionStream]);

    var hasEmittedValue = false;
    _freshSubscription = freshActionStream.listen(
      (value) async {
        final latestValue = await truthValue;
        if (value == latestValue && hasEmittedValue) return;
        hasEmittedValue = true;
        add(ValueUpdate(key, value));
      },
      onError: (Object error) => add(ErrorUpdate(error)),
      onDone: () {
        _isLoadingFresh = false;
        _freshSubscription = null;
        _actionController = null;
      },
      cancelOnError: true,
    );
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

    await _untilValueUnlocked();
    _valueLock.value = true;

    if (_truthSubscription == null) {
      _setUpTruthSubscription(event.key);
    }

    await writeTruthSource(event.key, event.value);
  }

  Stream<ResourceState<K, V>> _mapErrorUpdateToState(ErrorUpdate event) async* {
    await _freshSubscription?.cancel();
    await _truthSubscription?.cancel();

    yield state.copyWithError(event.error, isLoading: false);
  }

  Stream<ResourceState<K, V>> _mapResourceActionToState(
    ResourceAction event,
  ) async* {
    if (_actionController == null) {
      assert(() {
        print('WARN: Tried to perform a resource action $event, '
            'but no actions are being processed by the bloc. '
            'Try setting a key and / or adding a Reload() event.');
        return true;
      }());
      return;
    }
    _actionController!.sink.add(event);
  }

  Stream<ResourceState<K, V>> _mapTruthValueToState(_TruthValue event) async* {
    if (_isLoadingFresh) {
      yield state.copyWithValue(
        event.value,
        source: Source.cache,
      );
    } else {
      yield ResourceState.withValue(
        key!,
        event.value,
        isLoading: false,
        source: Source.fresh,
      );
    }
    _valueLock.value = false;
  }

  @override
  Future<void> close() async {
    await _freshSubscription?.cancel();
    await _truthSubscription?.cancel();
    await _actionController?.close();
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
