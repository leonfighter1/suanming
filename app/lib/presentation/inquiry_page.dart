import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../data/api_client.dart';
import '../domain/inquiry.dart';
import '../generated/contract.g.dart' show inquiryAnswerMax;
import '../l10n/gen/app_localizations.dart';
import 'design.dart';
import 'keyboard.dart';
import 'report_page.dart';
import 'widgets/points.dart';
import 'widgets/remedy.dart' show compactButtons;
import 'widgets/voice_input.dart';

/// What a 深度分析's final reading is asked with: the same as the reading the user would have made without one.
class InquiryReading {
  const InquiryReading({
    required this.chartId,
    required this.system,
    this.topics,
    this.question,
    this.focus,
    this.context,
    this.title,
    this.place,
  });
  final String chartId;
  final String system;
  final List<String>? topics;
  final String? question;
  final String? focus;
  final Map<String, Object?>? context;
  final String? title;
  final String? place;
}

/// 深度分析 (v10.0.0, S19 WP19.2): the master asks about the user's situation, one question at a time, before the
/// reading. The page says 「大师现在有问题要问你」 and that the final reading comes once the questions are answered (the
/// owner: 问完后才能给你最终解答); then 开始最终解答 makes the reading, which reads the whole conversation. Each new
/// question, the master's thinking and the start button come into view by themselves (the owner's standing rule).
class InquiryPage extends ConsumerStatefulWidget {
  const InquiryPage({super.key, required this.inquiryId, required this.reading});
  final String inquiryId;
  final InquiryReading reading;

  @override
  ConsumerState<InquiryPage> createState() => _InquiryPageState();
}

class _InquiryPageState extends ConsumerState<InquiryPage> {
  final _answer = TextEditingController();
  bool _sending = false;
  bool _starting = false;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _show(String text) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _send(InquiryView view) async {
    final text = _answer.text.trim();
    if (text.isEmpty || _sending || view.open == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _sending = true);
    try {
      await ref.read(apiClientProvider).answerInquiry(widget.inquiryId, text);
      _answer.clear();
      ref.invalidate(inquiryProvider(widget.inquiryId));
    } on ApiException catch (e) {
      if (mounted) _show(e.code == 'inquiry_thinking' ? l10n.inquiryBusy : '$e');
    } catch (e) {
      if (mounted) _show('$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// The final reading, which reads the conversation; a question left unanswered stays out of it.
  Future<void> _read() async {
    if (_starting) return;
    final r = widget.reading;
    final navigator = Navigator.of(context);
    setState(() => _starting = true);
    try {
      final report = await ref.read(apiClientProvider).createReport(
            chartId: r.chartId,
            locale: ref.read(settingsProvider).apiLocaleCode,
            topics: r.topics,
            question: r.question,
            focus: r.focus,
            context: r.context,
            inquiryId: widget.inquiryId,
          );
      ref.invalidate(historyProvider);
      ref.invalidate(pointsProvider);
      if (!mounted) return;
      await navigator.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => ReportPage(reportId: report.id, title: r.title, place: r.place)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      // 积分不足 (v11.0.0): the reading after a 深度分析 is paid on its own; after 充值 the button works again.
      if (!await showPointsShort(context, e) && mounted) _show('$e');
    }
  }

  /// 重新开始: a new 深度分析 with the same goal, in this page's place.
  Future<void> _restart(InquiryView view) async {
    final r = widget.reading;
    final navigator = Navigator.of(context);
    try {
      final next = await ref.read(apiClientProvider).startInquiry(
            chartId: r.chartId,
            locale: ref.read(settingsProvider).apiLocaleCode,
            goal: view.goal,
            question: r.question,
            focus: r.focus,
            context: r.context,
          );
      if (!mounted) return;
      await navigator.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => InquiryPage(inquiryId: next.id, reading: r)),
      );
    } catch (e) {
      if (mounted && !await showPointsShort(context, e) && mounted) _show('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(inquiryProvider(widget.inquiryId));
    final view = async.value;
    final open = view?.open;
    final canSend = open != null && !_sending;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.inquiryTitle)),
      body: LeaveGuard(
        // Once the reading is started this page is gone; before, leaving ends the 深度分析.
        active: !_starting,
        message: l10n.inquiryLeaveBody,
        child: SubmitShortcut(
          onSubmit: canSend ? () => _send(view!) : (view?.ready ?? false) && !_starting ? _read : null,
          child: switch (async) {
            AsyncValue(value: final v?) => _body(context, v),
            AsyncValue(error: final e?) => Center(
                child: Padding(
                  padding: Space.page,
                  child: Text('${l10n.errorTitle}\n$e', textAlign: TextAlign.center),
                ),
              ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, InquiryView view) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final open = view.open;
    final asked = view.turns.length;
    return ListView(
      padding: Space.page,
      children: [
        if (!view.ready && !view.failed)
          AppCard(
            key: const Key('inquiry-banner'),
            color: scheme.tertiaryContainer.withValues(alpha: 0.7),
            child: Row(
              children: [
                Icon(Icons.record_voice_over_outlined, color: scheme.onTertiaryContainer, size: 32),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.inquiryAsking,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: scheme.onTertiaryContainer),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(l10n.inquiryAskingNote, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onTertiaryContainer)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.s),
          child: Text(
            l10n.inquiryGoalLine(view.goal),
            key: const Key('inquiry-goal'),
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        for (final (i, t) in view.turns.indexed) ...[
          _MasterBubble(index: i, turn: t),
          if (t.answer != null) _AnswerBubble(index: i, text: t.answer!),
        ],
        // Each its own key: a part that takes another's place in the list must not take over its state, or it never
        // comes into view (MISTAKES rule 65).
        if (view.thinking)
          BringIntoView(
            key: const ValueKey<String>('bring-thinking'),
            trigger: asked,
            child: Padding(
              key: const Key('inquiry-thinking'),
              padding: const EdgeInsets.symmetric(vertical: Space.l),
              child: Row(
                children: [
                  const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: Space.s),
                  Expanded(child: Text(l10n.inquiryThinking)),
                ],
              ),
            ),
          ),
        if (open != null)
          BringIntoView(
            key: const ValueKey<String>('bring-composer'),
            trigger: asked,
            child: Column(
              key: const Key('inquiry-composer'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: Space.m),
                Text(
                  l10n.inquiryProgress(asked, view.planned ?? asked, view.maxQuestions),
                  key: const Key('inquiry-progress'),
                  style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
                ),
                const SizedBox(height: Space.s),
                TextField(
                  key: const Key('inquiry-field'),
                  controller: _answer,
                  enabled: !_sending,
                  maxLength: inquiryAnswerMax,
                  // One line, so Enter answers (a field of several lines would take Enter as a new line).
                  maxLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(view),
                  decoration: InputDecoration(
                    hintText: l10n.inquiryAnswerHint,
                    suffixIcon: VoiceInputButton.suffix(ref, controller: _answer, id: 'inquiry', maxLength: inquiryAnswerMax),
                  ),
                ),
                compactButtons(
                  context,
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: Space.s,
                    runSpacing: Space.s,
                    children: [
                      TextButton(
                        key: const Key('inquiry-skip'),
                        onPressed: _starting ? null : _read,
                        child: Text(l10n.inquirySkip),
                      ),
                      FilledButton.icon(
                        key: const Key('inquiry-send'),
                        onPressed: _sending ? null : () => _send(view),
                        icon: _sending
                            ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send),
                        label: Text(l10n.inquiryAnswerSend),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (view.ready)
          BringIntoView(
            key: const ValueKey<String>('bring-ready'),
            trigger: asked,
            child: AppCard(
              key: const Key('inquiry-ready'),
              title: l10n.inquiryReady,
              icon: Icons.check_circle_outline,
              color: scheme.primaryContainer.withValues(alpha: 0.55),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if ((view.closing ?? '').isNotEmpty) Text(view.closing!, style: theme.textTheme.bodyLarge?.copyWith(height: 1.6)),
                  if ((view.understanding ?? '').isNotEmpty) ...[
                    const SizedBox(height: Space.s),
                    Text(
                      l10n.inquiryUnderstanding(view.understanding!),
                      key: const Key('inquiry-understanding'),
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: Space.l),
                  FilledButton.icon(
                    key: const Key('inquiry-start-reading'),
                    onPressed: _starting ? null : _read,
                    icon: _starting
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome),
                    label: Text(l10n.inquiryStartReading),
                  ),
                ],
              ),
            ),
          ),
        if (view.failed)
          AppCard(
            key: const Key('inquiry-failed'),
            icon: Icons.error_outline,
            title: l10n.inquiryTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.inquiryFailed),
                const SizedBox(height: Space.m),
                FilledButton(key: const Key('inquiry-retry'), onPressed: () => _restart(view), child: Text(l10n.inquiryRetry)),
              ],
            ),
          ),
      ],
    );
  }
}

/// The master's turn: what it says, then its question, on the left.
class _MasterBubble extends StatelessWidget {
  const _MasterBubble({required this.index, required this.turn});
  final int index;
  final InquiryTurnView turn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: ValueKey<String>('inquiry-turn-$index'),
        constraints: const BoxConstraints(maxWidth: 600),
        margin: const EdgeInsets.only(top: Space.m),
        padding: const EdgeInsets.all(Space.m),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Radii.field),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.inquiryMaster, style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary)),
            if (turn.say.isNotEmpty) ...[
              const SizedBox(height: Space.xs),
              Text(turn.say, key: ValueKey<String>('inquiry-say-$index'), style: theme.textTheme.bodyLarge?.copyWith(height: 1.6)),
            ],
            if (turn.question.isNotEmpty) ...[
              const SizedBox(height: Space.xs),
              Text(
                turn.question,
                key: ValueKey<String>('inquiry-question-$index'),
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The user's answer, on the right.
class _AnswerBubble extends StatelessWidget {
  const _AnswerBubble({required this.index, required this.text});
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        key: ValueKey<String>('inquiry-answer-$index'),
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(top: Space.s),
        padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.field),
        ),
        child: Text(text, style: theme.textTheme.bodyLarge),
      ),
    );
  }
}

/// A reading's 深度分析 (v10.0.0), folded on the reading page: the goal, then each question with its answer.
class InquiryRecap extends ConsumerWidget {
  const InquiryRecap({super.key, required this.inquiryId});
  final String inquiryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(inquiryProvider(inquiryId)).value;
    if (view == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final answered = view.answered;
    return AppCard(
      key: const Key('inquiry-recap'),
      child: ExpansionTile(
        key: const Key('inquiry-recap-tile'),
        tilePadding: EdgeInsets.zero,
        leading: const Icon(Icons.record_voice_over_outlined),
        title: Text(l10n.inquiryCardTitle(answered.length), style: theme.textTheme.titleMedium),
        subtitle: Text(l10n.inquiryGoalLine(view.goal)),
        children: [
          for (final (i, t) in answered.indexed) ...[
            _MasterBubble(index: i, turn: t),
            _AnswerBubble(index: i, text: t.answer!),
          ],
          if ((view.understanding ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.m),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.inquiryUnderstanding(view.understanding!), style: theme.textTheme.bodyMedium),
              ),
            ),
          const SizedBox(height: Space.s),
        ],
      ),
    );
  }
}
