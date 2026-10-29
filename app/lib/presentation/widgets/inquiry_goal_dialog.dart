import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/contract.g.dart' show inquiryGoalMin;
import '../../l10n/gen/app_localizations.dart';
import '../design.dart';
import '../keyboard.dart';
import 'remedy.dart' show compactButtons;
import 'voice_input.dart';

/// 深度分析's reminder (v10.0.0; the owner: 如果用户一开始没有给出具体背景，要提醒用户，使用这一功能一定要给出个明确的目标才行): asks for the
/// goal when the reading has none. Pops with the goal, or null when cancelled.
Future<String?> askInquiryGoal(BuildContext context, {String initial = ''}) =>
    showDialog<String>(context: context, builder: (_) => _GoalDialog(initial: initial));

class _GoalDialog extends ConsumerStatefulWidget {
  const _GoalDialog({required this.initial});
  final String initial;

  @override
  ConsumerState<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends ConsumerState<_GoalDialog> {
  late final _goal = TextEditingController(text: widget.initial);
  bool _short = false;

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  void _start() {
    final goal = _goal.text.trim();
    if (goal.characters.length < inquiryGoalMin) {
      setState(() => _short = true);
      return;
    }
    Navigator.of(context).pop(goal);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SubmitShortcut(
      onSubmit: _start,
      child: compactButtons(
        context,
        AlertDialog(
          key: const Key('inquiry-goal-dialog'),
          title: Text(l10n.inquiryGoalTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.inquiryGoalBody),
              const SizedBox(height: Space.m),
              TextField(
                key: const Key('inquiry-goal-field'),
                controller: _goal,
                autofocus: true,
                maxLength: 300,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _start(),
                onChanged: (_) => _short ? setState(() => _short = false) : null,
                decoration: InputDecoration(
                  hintText: l10n.inquiryGoalHint,
                  errorText: _short ? l10n.inquiryGoalShort : null,
                  suffixIcon: VoiceInputButton.suffix(ref, controller: _goal, id: 'goal', maxLength: 300),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
            FilledButton(key: const Key('inquiry-goal-start'), onPressed: _start, child: Text(l10n.inquiryGoalStart)),
          ],
        ),
      ),
    );
  }
}
