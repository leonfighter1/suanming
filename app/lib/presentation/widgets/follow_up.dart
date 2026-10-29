import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../data/api_client.dart';
import '../../domain/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../design.dart';
import 'reading_paragraph.dart';
import 'remedy.dart' show compactButtons;
import 'voice_input.dart';

/// Where a reading's 追问 card and its floating button meet (v7.0.0): the card's place on the page, its question field
/// and whether that field is on screen.
class FollowUpTarget {
  final cardKey = GlobalKey();
  final composerKey = GlobalKey();
  final field = FocusNode(debugLabel: 'followup-field');

  /// The field and its 发送 are on screen: the floating button then steps aside, so it never covers them.
  final composerInView = ValueNotifier<bool>(false);

  void dispose() {
    field.dispose();
    composerInView.dispose();
  }

  /// Re-measures [composerInView]. The page calls it whenever it scrolls or its content changes size.
  void measure() {
    final box = composerKey.currentContext?.findRenderObject();
    // A viewport is a render object; as one it can be checked for a box below.
    final viewport = box == null ? null : RenderAbstractViewport.maybeOf(box) as RenderObject?;
    if (box is! RenderBox || !box.attached || !box.hasSize || viewport is! RenderBox || !viewport.hasSize) {
      composerInView.value = false;
      return;
    }
    final top = box.localToGlobal(Offset.zero).dy;
    final viewTop = viewport.localToGlobal(Offset.zero).dy;
    composerInView.value = top + box.size.height > viewTop && top < viewTop + viewport.size.height;
  }

  /// Brings the field and 发送 into view, with the latest answer above them, then puts the cursor in the field. The
  /// focus comes after the scroll: a field taking focus scrolls itself into view, and the two would race.
  Future<void> open() async {
    final composer = composerKey.currentContext;
    if (composer != null) {
      await Scrollable.ensureVisible(
        composer,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.7,
      );
    }
    field.requestFocus();
  }
}

/// Keeps [target]'s measure current as [child], the page's scroll view, scrolls or changes size.
class FollowUpScope extends StatefulWidget {
  const FollowUpScope({super.key, required this.target, required this.child});
  final FollowUpTarget target;
  final Widget child;

  @override
  State<FollowUpScope> createState() => _FollowUpScopeState();
}

class _FollowUpScopeState extends State<FollowUpScope> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.target.measure());
  }

  bool _measure(Notification _) {
    widget.target.measure();
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollMetricsNotification>(
    onNotification: _measure,
    child: NotificationListener<ScrollNotification>(onNotification: _measure, child: widget.child),
  );
}

/// 「继续追问」, floating at the bottom right of a passed reading (the owner: 显眼的位置). It brings the 追问 field into
/// view; while the field is on screen it steps aside, out of the Tab order too.
class FollowUpButton extends StatelessWidget {
  const FollowUpButton({super.key, required this.target});
  final FollowUpTarget target;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: target.composerInView,
    builder: (context, away, button) => IgnorePointer(
      ignoring: away,
      child: ExcludeFocus(
        excluding: away,
        child: AnimatedScale(
          scale: away ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: button,
        ),
      ),
    ),
    child: FloatingActionButton.extended(
      key: const Key('followup-fab'),
      heroTag: null,
      onPressed: target.open,
      icon: const Icon(Icons.forum_outlined),
      label: Text(AppLocalizations.of(context).followUpTitle),
    ),
  );
}

/// 追问 (v7.0.0, S13): the follow-up questions on one reading, each answered from that reading alone; the suggested
/// next questions; and the field to ask. [parent] is the API path the 追问 hang off: `reports/<id>` or
/// `life-reports/<id>`.
class FollowUpCard extends ConsumerStatefulWidget {
  const FollowUpCard({super.key, required this.parent, required this.target, required this.starters});
  final String parent;
  final FollowUpTarget target;

  /// The method's first questions, offered before anything has been asked.
  final List<String> starters;

  @override
  ConsumerState<FollowUpCard> createState() => _FollowUpCardState();
}

class _FollowUpCardState extends ConsumerState<FollowUpCard> {
  final _question = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask(String text) async {
    final q = text.trim();
    if (q.isEmpty || _sending) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await ref.read(apiClientProvider).askFollowUp(widget.parent, q);
      _question.clear();
      ref.invalidate(followUpsProvider(widget.parent));
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch ((e.status, e.code)) {
            (409, 'followup_pending') => l10n.followUpBusy,
            (409, 'followup_limit') => l10n.followUpLimit,
            (429, _) => l10n.followUpQuota,
            _ => '$e',
          }),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final list = ref.watch(followUpsProvider(widget.parent)).value;
    final items = list?.items ?? const <FollowUpView>[];
    final waiting = list?.answering ?? false;
    // Until the list has loaded, nothing is used up.
    final left = list?.left ?? 1;
    final answered = items.where((f) => f.status == 'passed').lastOrNull;
    final suggestions = answered == null ? widget.starters : answered.suggestions;
    final canAsk = list != null && left > 0 && !waiting && !_sending;
    return KeyedSubtree(
      key: widget.target.cardKey,
      child: AppCard(
        key: const Key('followup-card'),
        title: l10n.followUpTitle,
        icon: Icons.forum_outlined,
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.followUpIntro, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
            for (final (i, f) in items.indexed) _Turn(view: f, index: i),
            if (suggestions.isNotEmpty && left > 0 && !waiting) ...[
              const SizedBox(height: Space.m),
              Text(answered == null ? l10n.followUpStart : l10n.followUpNext, style: theme.textTheme.labelLarge),
              const SizedBox(height: Space.s),
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (final (i, s) in suggestions.indexed)
                    ActionChip(
                      key: ValueKey<String>('followup-suggestion-$i'),
                      avatar: const Icon(Icons.subdirectory_arrow_right, size: 16),
                      label: Text(s),
                      onPressed: canAsk ? () => _ask(s) : null,
                    ),
                ],
              ),
            ],
            const SizedBox(height: Space.m),
            Column(
              key: widget.target.composerKey,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('followup-field'),
                  focusNode: widget.target.field,
                  controller: _question,
                  enabled: left > 0,
                  maxLength: 200,
                  // One line, so Enter sends (a field of several lines would take Enter as a new line).
                  maxLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (v) => canAsk ? _ask(v) : null,
                  decoration: InputDecoration(
                    hintText: left > 0 ? l10n.followUpHint : l10n.followUpLimit,
                    helperText: list != null && left > 0 ? l10n.followUpLeft(left) : null,
                    // 麦克风 (v10.0.0): say the question instead of typing it, where the browser can listen.
                    suffixIcon: left > 0 ? VoiceInputButton.suffix(ref, controller: _question, id: 'followup', maxLength: 200) : null,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: compactButtons(
                    context,
                    FilledButton.icon(
                      key: const Key('followup-send'),
                      onPressed: canAsk ? () => _ask(_question.text) : null,
                      icon: _sending
                          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send),
                      label: Text(l10n.followUpSend),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One 追问: the question as asked, then its answer, or where it stands.
class _Turn extends StatelessWidget {
  const _Turn({required this.view, required this.index});
  final FollowUpView view;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Space.l),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            key: ValueKey<String>('followup-question-$index'),
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.field),
            ),
            child: Text(view.question, style: theme.textTheme.bodyLarge),
          ),
        ),
        const SizedBox(height: Space.s),
        switch (view.status) {
          'pending' => Row(
            key: ValueKey<String>('followup-waiting-$index'),
            children: [
              const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: Space.s),
              Expanded(child: Text(l10n.followUpAnswering)),
            ],
          ),
          'passed' => Column(
            key: ValueKey<String>('followup-answer-$index'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!view.inScope) ...[
                Pill(
                  l10n.followUpOutOfScope,
                  key: ValueKey<String>('followup-out-of-scope-$index'),
                  icon: Icons.info_outline,
                ),
                const SizedBox(height: Space.s),
              ],
              for (final (j, p) in view.paragraphs.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.m),
                  child: ReadingParagraph(paragraph: p, id: 'followup-$index-$j', showSource: false),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: Badge(label: Text(l10n.aiBadge)),
              ),
            ],
          ),
          'failed' => Text(
            l10n.followUpFailed,
            key: ValueKey<String>('followup-failed-$index'),
            style: TextStyle(color: scheme.error),
          ),
          _ => Text(l10n.followUpHeld, key: ValueKey<String>('followup-held-$index')),
        },
      ],
    );
  }
}
