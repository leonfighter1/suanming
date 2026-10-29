import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'speech_input.dart';

/// Web: the browser's speech recognition (the Web Speech API). Chrome still names it webkitSpeechRecognition, and
/// sends the audio to Google, which mainland China can't reach; Edge and Safari recognise it themselves or through
/// their own services. Where neither name exists (Firefox), the mic button isn't shown.
SpeechInput createSpeechInput() => WebSpeechInput();

class WebSpeechInput implements SpeechInput {
  web.SpeechRecognition? _active;

  JSFunction? get _constructor {
    final ctor = globalContext['SpeechRecognition'] ?? globalContext['webkitSpeechRecognition'];
    return ctor.isA<JSFunction>() ? ctor as JSFunction : null;
  }

  @override
  bool get available => _constructor != null;

  @override
  Future<String?> listen({required String lang, required void Function(String text) onText}) {
    final ctor = _constructor;
    if (ctor == null) return Future.value('unavailable');
    final recognition = ctor.callAsConstructor<web.SpeechRecognition>()
      ..lang = lang
      ..interimResults = true
      ..continuous = false;
    final done = Completer<String?>();
    String? error;
    recognition.onresult = ((web.SpeechRecognitionEvent e) {
      final heard = StringBuffer();
      for (var i = 0; i < e.results.length; i++) {
        heard.write(e.results.item(i).item(0).transcript);
      }
      onText(heard.toString());
    }).toJS;
    recognition.onerror = ((web.SpeechRecognitionErrorEvent e) => error = e.error).toJS;
    recognition.onend = ((web.Event _) {
      if (identical(_active, recognition)) _active = null;
      if (!done.isCompleted) done.complete(error);
    }).toJS;
    _active?.abort();
    _active = recognition;
    try {
      recognition.start();
    } catch (_) {
      _active = null;
      return Future.value('unavailable');
    }
    return done.future;
  }

  @override
  void stop() => _active?.stop();
}
