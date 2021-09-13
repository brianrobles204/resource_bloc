import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

abstract class ResourceEvent extends Equatable {
  const ResourceEvent();
}

@sealed
class KeyUpdate<K extends Object> extends ResourceEvent {
  const KeyUpdate(this.key);

  final K key;

  @override
  List<Object?> get props => [key];
}

@sealed
class KeyError extends ResourceEvent {
  const KeyError(this.error);

  final Object error;

  @override
  List<Object?> get props => [error];
}

class Reload extends ResourceEvent {
  const Reload();

  @override
  List<Object?> get props => [];
}

abstract class ResourceAction extends ResourceEvent {
  const ResourceAction();
}

@sealed
class ValueUpdate<K extends Object, V> extends ResourceEvent {
  ValueUpdate(this.key, this.value);

  final K key;
  final V value;

  @override
  List<Object?> get props => [value];
}

@sealed
class ErrorUpdate extends ResourceEvent {
  ErrorUpdate(this.error);

  final Object error;

  @override
  List<Object?> get props => [error];
}
