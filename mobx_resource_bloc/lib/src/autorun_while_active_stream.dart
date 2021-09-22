import 'dart:async';

import 'package:mobx/mobx.dart';

class AutorunWhileActiveStream<T> extends StreamView<T> {
  AutorunWhileActiveStream(
    void Function(Reaction reaction) autorunCallback,
    Stream<T> stream, {
    void Function(bool isRunning)? onUpdate,
  }) : super(_buildStream(autorunCallback, stream, onUpdate));

  static Stream<T> _buildStream<T>(
    void Function(Reaction reaction) autorunCallback,
    Stream<T> stream,
    void Function(bool isRunning)? onUpdate,
  ) {
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;
    ReactionDisposer? disposeAutorun;
    bool isRunning = false;

    void updateIsRunning(bool newIsRunning) {
      if (newIsRunning != isRunning) {
        isRunning = newIsRunning;
        onUpdate?.call(isRunning);
      }
    }

    void updateAutorun() {
      if (subscription?.isPaused ?? true) {
        disposeAutorun?.call();
        disposeAutorun = null;
        updateIsRunning(false);
      } else {
        disposeAutorun ??= autorun(
          autorunCallback,
          name: 'AutorunWhileActiveStream<$T>',
        );
        updateIsRunning(true);
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
      onCancel: () async {
        disposeAutorun?.call();
        disposeAutorun = null;
        if (subscription != null) {
          await subscription!.cancel();
        }
      },
    );

    return controller.stream;
  }
}

extension AutorunWhileActiveExt<T> on Stream<T> {
  Stream<T> autorunWhileActive(
    void Function(Reaction reaction) autorunCallback, {
    void Function(bool isRunning)? onUpdate,
  }) =>
      AutorunWhileActiveStream(
        autorunCallback,
        this,
        onUpdate: onUpdate,
      );
}
