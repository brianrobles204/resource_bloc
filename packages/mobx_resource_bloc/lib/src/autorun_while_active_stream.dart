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

    void onListen() {
      subscription = stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );

      updateAutorun();
    }

    void onPause() {
      subscription!.pause();
      updateAutorun();
    }

    void onResume() {
      subscription!.resume();
      updateAutorun();
    }

    Future<void> onCancel() async {
      disposeAutorun?.call();
      disposeAutorun = null;
      if (subscription != null) {
        await subscription!.cancel();
      }
    }

    controller = stream.isBroadcast
        ? StreamController<T>.broadcast(
            sync: true,
            onListen: onListen,
            onCancel: onCancel,
          )
        : StreamController(
            sync: true,
            onListen: onListen,
            onPause: onPause,
            onResume: onResume,
            onCancel: onCancel,
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
