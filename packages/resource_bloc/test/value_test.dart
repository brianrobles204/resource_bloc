import 'package:resource_bloc/resource_bloc.dart';
import 'package:test/test.dart';

void main() {
  group('values', () {
    late FreshSource<String, String?> freshSource;
    late ResourceBloc<String, String?> bloc;

    setUp(() {
      freshSource = (value) => Stream.value(value);
      bloc = ResourceBloc.from(
        freshSource: (key) => freshSource(key),
        truthSource: TruthSource.noop(),
      );
    });

    test('can be null', () async {
      freshSource = (value) => Stream.value(null);

      bloc.key = 'test';
      await pumpEventQueue();

      expect(bloc.state.hasValue, isTrue);
      expect(bloc.value, isNull);

      // can handle values after null
      freshSource = (value) => Stream.value('result');

      bloc.key = 'next';
      await pumpEventQueue();

      expect(bloc.state.hasValue, isTrue);
      expect(bloc.value, equals('result'));
    });
  });
}
