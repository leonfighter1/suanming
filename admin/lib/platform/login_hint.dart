// What the app's ☰ → 管理后台 hands over in the address (`?login=`, tech plan S25, for the sign-in to fill in): read once
// on the web, then taken off the address bar so a copied link doesn't carry it; nothing elsewhere. A conditional
// import, so the VM tests never load package:web.

export 'login_hint_stub.dart' if (dart.library.js_interop) 'login_hint_web.dart';
