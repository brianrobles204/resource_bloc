import 'dart:async';

class DoStreamTransformer<S> extends StreamTransformerBase<S, S> {
  const DoStreamTransformer({
    this.onCancel,
    this.onData,
    this.onDone,
    this.onError,
    this.onListen,
    this.onPause,
    this.onResume,
  }) : assert(onCancel != null ||
            onData != null ||
            onDone != null ||
            onError != null ||
            onListen != null ||
            onPause != null ||
            onResume != null);

  /// fires when all subscriptions have cancelled.
  final FutureOr<void> Function()? onCancel;

  /// fires when data is emitted
  final void Function(S event)? onData;

  /// fires on close
  final void Function()? onDone;

  /// fires on errors
  final void Function(Object, StackTrace)? onError;

  /// fires when a subscription first starts
  final void Function()? onListen;

  /// fires when the subscription pauses
  final void Function()? onPause;

  /// fires when the subscription resumes
  final void Function()? onResume;

  @override
  Stream<S> bind(Stream<S> stream) {
    late StreamController<S> controller;
    StreamSubscription<S>? subscription;

    void onStreamData(S data) {
      onData?.call(data);
      controller.add(data);
    }

    void onStreamError(Object error, StackTrace stacktrace) {
      onError?.call(error, stacktrace);
      controller.addError(error, stacktrace);
    }

    void onStreamDone() {
      onDone?.call();
      controller.close();
    }

    void onControllerListen() {
      subscription = stream.listen(
        onStreamData,
        onError: onStreamError,
        onDone: onStreamDone,
      );
      onListen?.call();
    }

    Future<void> onControllerCancel() {
      return Future.wait(<FutureOr<void>>[
        if (onCancel != null) onCancel!(),
        if (subscription != null) subscription!.cancel(),
      ].map((futureOr) => Future(() => futureOr)));
    }

    void onStreamPause() {
      onPause?.call();
      subscription?.pause();
    }

    void onStreamResume() {
      onResume?.call();
      subscription?.resume();
    }

    controller = stream.isBroadcast
        ? StreamController<S>.broadcast(
            sync: true,
            onListen: onControllerListen,
            onCancel: onControllerCancel,
          )
        : StreamController<S>(
            sync: true,
            onListen: onControllerListen,
            onPause: onStreamPause,
            onResume: onStreamResume,
            onCancel: onControllerCancel,
          );

    return controller.stream;
  }
}

extension DoStreamExtensions<S> on Stream<S> {
  Stream<S> doOn({
    FutureOr<void> Function()? onCancel,
    void Function(S event)? onData,
    void Function()? onDone,
    void Function(Object, StackTrace)? onError,
    void Function()? onListen,
    void Function()? onPause,
    void Function()? onResume,
  }) =>
      transform(DoStreamTransformer(
        onCancel: onCancel,
        onData: onData,
        onDone: onDone,
        onError: onError,
        onListen: onListen,
        onPause: onPause,
        onResume: onResume,
      ));
}
