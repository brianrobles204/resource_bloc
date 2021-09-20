import 'package:bloc/bloc.dart';
import 'package:mobx/mobx.dart';

mixin ObservableBlocMixin<Event, State> on Bloc<Event, State> {
  @override
  ObservableStream<State> get stream => _stream ??= super.stream.asObservable(
        initialValue: super.state,
        name: 'ObservableBloc<$Event,$State>.stream',
      );
  ObservableStream<State>? _stream;

  @override
  State get state => (_state ??= Computed(() => stream.value as State)).value;
  Computed<State>? _state;
}
