import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web: the browser downloads [bytes] as [name] through a hidden link, with no share sheet (the share_plus way opens
/// Windows' share sheet in Chrome, as Chrome can share files there).
Future<bool> downloadFile(Uint8List bytes, String name, String mime) async {
  final url = web.URL.createObjectURL(web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime)));
  final link = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = name;
  link.style.display = 'none';
  web.document.body!.append(link);
  link.click();
  link.remove();
  // The download has started; the address can go once the browser has read it.
  Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
  return true;
}
