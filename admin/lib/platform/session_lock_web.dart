import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Web: [body] under the browser's lock called [name], one of the dashboard's tabs at a time. A browser without locks
/// (an old one, a page not served over https or from this computer), or one that won't give the lock: [body] all the
/// same.
Future<T> oneAtATime<T>(String name, Future<T> Function() body) {
  final navigator = web.window.navigator;
  if (!navigator.has('locks')) return body();
  final done = Completer<T>();
  var started = false;
  Future<void> run() async {
    started = true;
    try {
      done.complete(await body());
    } catch (e, s) {
      done.completeError(e, s);
    }
  }

  JSPromise<JSAny?> granted(web.Lock? _) => run().toJS;
  navigator.locks.request(name, granted.toJS).toDart.then((_) {}, onError: (Object _) {
    if (!started) run();
  });
  return done.future;
}
