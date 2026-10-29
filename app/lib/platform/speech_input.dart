/// Speech to text (S19, v10.0.0; the owner: 对于打字不方便的用户可以增加麦克风输入): what the mic button listens through.
/// On the web, the browser's own speech recognition; elsewhere there is none, and the phone keyboard's voice input
/// does the same job.
abstract class SpeechInput {
  /// Whether this device can listen at all; the mic button is shown only then.
  bool get available;

  /// Listens once in [lang] (a BCP 47 tag: zh-CN, zh-TW). [onText] gets the text heard so far, as it grows. Completes
  /// when listening ends: null when it went well, else the reason (a Web Speech error code such as `not-allowed` or
  /// `no-speech`, or `unavailable`).
  Future<String?> listen({required String lang, required void Function(String text) onText});

  /// Stops listening; what was heard so far stays.
  void stop();
}

/// No speech recognition here.
class NoSpeechInput implements SpeechInput {
  const NoSpeechInput();

  @override
  bool get available => false;

  @override
  Future<String?> listen({required String lang, required void Function(String text) onText}) async =>
      'unavailable';

  @override
  void stop() {}
}
