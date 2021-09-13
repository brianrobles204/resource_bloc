import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

import 'resource_event.dart';
import 'resource_state.dart';

abstract class BaseResourceBloc<K extends Object, V>
    extends Bloc<ResourceEvent, ResourceState<K, V>> {
  BaseResourceBloc({K? initialKey})
      : super(
          initialKey != null
              ? ResourceState.loading(initialKey)
              : ResourceState.initial(),
        );

  StreamSubscription<V>? _truthSubscription;
  StreamSubscription<V>? _freshSubscription;
  StreamController<ResourceAction>? _actionController;
  bool _isLoadingFresh = false;

  final _valueLock = BehaviorSubject.seeded(false);
  Future<void> _untilValueUnlocked() =>
      _valueLock.firstWhere((isLocked) => !isLocked);

  K? get key => state.key;

  V? get value => state.value;

  @protected
  Future<V?> get truthValue async {
    await _untilValueUnlocked();
    return state.value;
  }

  @protected
  V? getInitialValue(K key);

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

  void _setupTruthSubscription(K newKey) {
    _truthSubscription = readTruthSource(newKey).listen(
      (value) => add(_TruthValue(value)),
      onError: (error) => add(ErrorUpdate(error)),
      onDone: () => _valueLock.value = false,
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
    await _freshSubscription?.cancel();
    await _truthSubscription?.cancel();

    if (key != event.key) {
      if (key != null || !state.hasError) {
        final initialValue = getInitialValue(event.key);
        yield initialValue != null
            ? ResourceState.withValue(
                event.key,
                initialValue,
                isLoading: true,
                source: Source.fresh,
              )
            : ResourceState.loading(event.key);
      } else {
        // Previously with key error. Emit the prior error but with the new key.
        yield ResourceState.withError(
          state.requireError,
          key: event.key,
          isLoading: true,
        );
      }

      _setupTruthSubscription(event.key);

      add(Reload());
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
    if (key == null) return;

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
    if (key != event.key) return;

    await _untilValueUnlocked();
    _valueLock.value = true;

    if (_truthSubscription == null) {
      _setupTruthSubscription(event.key);
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
    if (_actionController == null) return;
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
