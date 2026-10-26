import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web: print [html] through a hidden iframe (no popup to block).
Future<bool> printHtml(String html) async {
  final frame = web.document.createElement('iframe') as web.HTMLIFrameElement;
  frame.style
    ..position = 'fixed'
    ..width = '0'
    ..height = '0'
    ..border = '0';
  final loaded = Completer<void>();
  frame.onload = ((web.Event _) {
    if (!loaded.isCompleted) loaded.complete();
  }).toJS;
  frame.setAttribute('srcdoc', html);
  web.document.body!.append(frame);
  await loaded.future.timeout(const Duration(seconds: 5), onTimeout: () {});
  frame.contentWindow?.print();
  // Leave the frame while the dialog is open; remove it later.
  Timer(const Duration(minutes: 1), () => frame.remove());
  return true;
}
