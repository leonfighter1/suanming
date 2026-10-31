// Choosing a picture to put in (内容管理, tech plan S29): the browser's file chooser on the web, nothing elsewhere (the
// dashboard is a web app). Like download.dart, a conditional import, so the VM tests never load package:web.

export 'pick_file_stub.dart' if (dart.library.js_interop) 'pick_file_web.dart';
