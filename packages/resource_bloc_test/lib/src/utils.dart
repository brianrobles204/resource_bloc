import 'dart:async';

import 'package:resource_bloc/resource_bloc.dart';

/// Returns a future that finishes when the bloc is done loading
/// (i.e. isLoading turns false).
///
/// If the state is already not loading, the future completes instantly.
FutureOr<void> untilDoneLoading(BaseResourceBloc bloc) =>
    untilState(bloc, (state) => !state.isLoading);

typedef UntilCondition<K extends Object, V> = bool Function(
  ResourceState<K, V> state,
);

/// Returns a future that finishes when the bloc's state passes the
/// condition check.
FutureOr<void> untilState<K extends Object, V>(
  BaseResourceBloc<K, V> bloc,
  UntilCondition<K, V> condition,
) {
  if (!condition(bloc.state)) {
    return bloc.stream.firstWhere(condition).then((_) {});
  }
}
