import 'dart:async';

import 'package:mobx/mobx.dart';

class AutorunWhileActiveStream<T> extends StreamView<T> {
  AutorunWhileActiveStream(
    void Function(Reaction reaction) autorunCallback,
    Stream<T> stream,
  ) : super(_buildStream(autorunCallback, stream));

  static Stream<T> _buildStream<T>(
    void Function(Reaction reaction) autorunCallback,
    Stream<T> stream,
  ) {
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;
    ReactionDisposer? disposeAutorun;

    void updateAutorun() {
      if (subscription?.isPaused ?? true) {
        disposeAutorun?.call();
        disposeAutorun = null;
      } else {
        disposeAutorun ??= autorun(
          autorunCallback,
          name: 'AutorunWhileActiveStream<$T>',
        );
      }
    }

    controller = StreamController<T>(
      sync: true,
      onListen: () {
        subscription = stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );

        updateAutorun();
      },
      onPause: () {
        subscription!.pause();
        updateAutorun();
      },
      onResume: () {
        subscription!.resume();
        updateAutorun();
      },
      onCancel: () {
        disposeAutorun?.call();
        disposeAutorun = null;
      },
    );

    return controller.stream;
  }
}
