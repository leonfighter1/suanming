import 'speech_input.dart';

/// Non-web: no speech recognition; the phone keyboard's own voice input types into the field.
SpeechInput createSpeechInput() => const NoSpeechInput();
