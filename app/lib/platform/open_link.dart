// Opening a page of our own server in a new browser tab (☰ → 管理后台, tech plan S25): the browser's on the web; elsewhere
// nothing to open it in (false), so the caller offers the address instead. Like printing, the web part is a conditional
// import, so the VM never loads package:web.

export 'open_link_stub.dart' if (dart.library.js_interop) 'open_link_web.dart';
