import 'dart:async';

import '../resource_bloc.dart';

typedef ActionHandler<A extends ResourceAction, V> = FutureOr<void> Function(
  A action,
  ActionEmitter<V> emit,
);

typedef CancelCallback<V> = V Function(V value);

abstract class ActionEmitter<V> {
  Future<V> get value;

  bool get isDone;

  Future<void> call(V Function(V value) callback);
}
