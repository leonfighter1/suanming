// The dashboard's tabs take turns with their session (S34): they share it, its refresh token in this browser's storage,
// and the server takes each refresh token once (a second use ends the session). On the web, the Web Locks API;
// elsewhere there is no other tab. As with the prefs, a conditional import keeps package:web out of the VM tests.

export 'session_lock_stub.dart' if (dart.library.js_interop) 'session_lock_web.dart';
