/// Speech to text (v10.0.0): the browser's speech recognition on the web, none elsewhere.
library;

export 'speech_input.dart';
export 'speech_stub.dart' if (dart.library.js_interop) 'speech_web.dart';
