import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../l10n/gen/app_localizations.dart';
import '../buttons.dart';

/// 麦克风 (v10.0.0, S19 WP19.3; the owner: 对于打字不方便的用户可以增加麦克风输入): a mic button for a text field. It types
/// what the user says into [controller], after what is there already, as the browser hears it; a second press stops.
/// Where the device can't listen it isn't there at all ([suffix] is null): the phone keyboard's own voice input does
/// the job there.
class VoiceInputButton extends ConsumerStatefulWidget {
  const VoiceInputButton({super.key, required this.controller, required this.id, this.maxLength});
  final TextEditingController controller;

  /// Names its key: `mic-<id>`.
  final String id;

  /// The field's own limit: what is heard is cut to it.
  final int? maxLength;

  /// The button for a field's `suffixIcon`, or null where nothing can listen (no empty slot beside the field).
  static Widget? suffix(WidgetRef ref, {required TextEditingController controller, required String id, int? maxLength}) =>
      ref.watch(speechInputProvider).available
          ? VoiceInputButton(controller: controller, id: id, maxLength: maxLength)
          : null;

  @override
  ConsumerState<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends ConsumerState<VoiceInputButton> {
  bool _listening = false;

  Future<void> _toggle() async {
    final speech = ref.read(speechInputProvider);
    if (_listening) {
      speech.stop();
      return;
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final lang = ref.read(settingsProvider).apiLocaleCode == 'zh-Hant' ? 'zh-TW' : 'zh-CN';
    final before = widget.controller.text;
    setState(() => _listening = true);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(l10n.micListening), duration: const Duration(seconds: 30)));
    final error = await speech.listen(
      lang: lang,
      onText: (heard) {
        final max = widget.maxLength;
        final all = before + heard;
        final text = max != null && all.characters.length > max ? all.characters.take(max).toString() : all;
        widget.controller.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
      },
    );
    // The listening note goes either way (MISTAKES rule 57: a result never waits behind it).
    messenger.hideCurrentSnackBar();
    if (!mounted) return;
    setState(() => _listening = false);
    final problem = switch (error) {
      null || 'aborted' => null,
      'not-allowed' || 'service-not-allowed' => l10n.micDenied,
      'no-speech' => l10n.micNoMatch,
      _ => l10n.micUnavailable,
    };
    if (problem != null) messenger.showSnackBar(SnackBar(content: Text(problem)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AppIconButton(
      key: ValueKey<String>('mic-${widget.id}'),
      tooltip: _listening ? l10n.micStop : l10n.micStart,
      onPressed: _toggle,
      icon: Icon(_listening ? Icons.mic : Icons.mic_none, color: _listening ? scheme.error : null),
    );
  }
}
