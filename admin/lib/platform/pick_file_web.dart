import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../data/admin_api.dart' show AdminFile;

/// Web: the browser's file chooser, offering files of [types] (image/png, …); null when it closes without one. A
/// browser that doesn't tell when it closes leaves the future waiting, which holds nothing up.
Future<AdminFile?> pickFile(List<String> types) async {
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = types.join(',');
  final chosen = Completer<web.File?>();
  void done(web.File? f) {
    if (!chosen.isCompleted) chosen.complete(f);
  }

  input
    ..addEventListener('change', ((web.Event _) => done(input.files?.item(0))).toJS)
    ..addEventListener('cancel', ((web.Event _) => done(null)).toJS);
  input.click();
  final file = await chosen.future;
  if (file == null) return null;
  final bytes = (await file.arrayBuffer().toDart).toDart.asUint8List();
  return AdminFile(bytes, file.name, file.type);
}
