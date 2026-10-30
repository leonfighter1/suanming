// The dashboard's own settings in this browser (the theme, v12.1.0): the browser's storage on the web, nothing kept
// elsewhere. A per-device convenience only (rule 52). Like the download, a conditional import keeps package:web out of
// the VM tests.

export 'prefs_stub.dart' if (dart.library.js_interop) 'prefs_web.dart';
