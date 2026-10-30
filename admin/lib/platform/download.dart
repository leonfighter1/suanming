// Saving an export as a download: the browser's own on the web, nothing elsewhere (the dashboard is a web app).
// Like the app's printer and speech, the web part is a conditional import, so the VM tests never load package:web.

export 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';
