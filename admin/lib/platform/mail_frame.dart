// A mail's preview (消息, tech plan S25): its own page in a frame on the web, its text elsewhere (the VM tests). Like
// the downloads, the web part is a conditional import, so the VM never loads package:web.

export 'mail_frame_stub.dart' if (dart.library.js_interop) 'mail_frame_web.dart';
