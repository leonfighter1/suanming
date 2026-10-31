import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/providers.dart';
import '../domain/models.dart' show Json;
import '../l10n/gen/app_localizations.dart';
import 'buttons.dart';
import 'design.dart';
import 'layout.dart';
import 'widgets/remedy.dart' show compactButtons;

/// Held content for 内容审核 (reviewers only), newest first.
final reviewsProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(apiClientProvider).listReviews());

String kindLabel(AppLocalizations l10n, String kind) => switch (kind) {
  'remedy' => l10n.kindRemedy,
  'life_report' => l10n.kindLife,
  'followup' => l10n.kindFollowUp,
  _ => l10n.kindReport,
};

/// 内容审核: everything the compliance checks held back.
class ReviewPage extends ConsumerWidget {
  const ReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(reviewsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(reviewsProvider.future),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(padding: pagePadding(context), children: [Text('${l10n.errorTitle}\n$e')]),
          data: (items) => ListView(
            padding: pagePadding(context),
            children: [
              Text(l10n.reviewHint, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: Space.m),
              if (items.isEmpty) EmptyState(icon: Icons.fact_check_outlined, text: l10n.reviewEmpty),
              for (final it in items) _ReviewTile(item: it),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewTile extends ConsumerWidget {
  const _ReviewTile({required this.item});
  final Json item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final blocked = item['status'] == 'blocked';
    final reasons = ((item['reasons'] as List?) ?? const []).cast<String>();
    return AppCard(
      key: Key('review-${item['id']}'),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReviewDetailPage(kind: item['kind'] as String, id: item['id'] as String),
          ),
        );
        ref.invalidate(reviewsProvider);
      },
      child: Row(
        children: [
          Icon(blocked ? Icons.block : Icons.hourglass_top, color: blocked ? scheme.error : scheme.tertiary),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${kindLabel(l10n, item['kind'] as String)} · ${blocked ? l10n.reviewBlocked : l10n.reviewHeld}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: Space.xxs),
                Text(
                  [
                    _date(item['created_at'] as String?),
                    if (item['topic'] != null) item['topic'],
                    if (reasons.isNotEmpty) reasons.first,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

String _date(String? iso) => iso == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(iso).toLocal());

/// One held item: why it was held, the exact content, and the decision.
class ReviewDetailPage extends ConsumerStatefulWidget {
  const ReviewDetailPage({super.key, required this.kind, required this.id});
  final String kind;
  final String id;

  @override
  ConsumerState<ReviewDetailPage> createState() => _ReviewDetailPageState();
}

class _ReviewDetailPageState extends ConsumerState<ReviewDetailPage> {
  late final Future<Json> _load = ref.read(apiClientProvider).getReview(widget.kind, widget.id);
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _decide(bool approve) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).decideReview(widget.kind, widget.id, approve: approve, note: _note.text);
      messenger.showSnackBar(SnackBar(content: Text(approve ? l10n.reviewApproved : l10n.reviewRejected)));
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('${l10n.reviewTitle} · ${kindLabel(l10n, widget.kind)}')),
      body: FutureBuilder<Json>(
        future: _load,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${l10n.errorTitle}\n${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!;
          final blocked = d['status'] == 'blocked';
          final hits = ((d['rule_hits'] as List?) ?? const []).cast<Json>();
          final guard = ((d['guard'] as List?) ?? const []).cast<Json>();
          final flagged = [...hits.map((h) => '${h['match']}'), ...guard.map((g) => '${g['quote']}')].where((s) => s.isNotEmpty).toList();
          final texts = reviewTexts(d['content']);
          return ListView(
            padding: pagePadding(context),
            children: [
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  Pill(
                    blocked ? l10n.reviewBlocked : l10n.reviewHeld,
                    icon: blocked ? Icons.block : Icons.hourglass_top,
                    color: blocked ? scheme.error : scheme.tertiary,
                  ),
                  Pill(_date(d['created_at'] as String?), icon: Icons.schedule),
                  Pill('#${d['owner']}', icon: Icons.person_outline),
                  if (d['topic'] != null) Pill('${d['topic']}', icon: Icons.label_outline),
                  if (d['locale'] != null) Pill('${d['locale']}', icon: Icons.translate),
                ],
              ),
              _Block(
                title: l10n.reviewReasons,
                children: [for (final r in ((d['reasons'] as List?) ?? const []).cast<String>()) Text('• $r')],
              ),
              if (hits.isNotEmpty)
                _Block(
                  title: l10n.reviewRuleHits,
                  children: [
                    for (final h in hits) Text('${h['rule_id']} (${h['action']})：「${h['match']}」', key: Key('hit-${h['rule_id']}')),
                  ],
                ),
              if (guard.isNotEmpty)
                _Block(
                  title: l10n.reviewGuard,
                  children: [
                    for (final g in guard)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.s),
                        child: Text('[${g['category']}] 「${g['quote']}」\n${g['reason']}', key: const Key('guard-finding')),
                      ),
                  ],
                ),
              _Block(
                title: l10n.reviewContent,
                children: texts.isEmpty
                    ? [Text(l10n.reviewNoContent)]
                    : [
                        for (final (label, text) in texts)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: Space.s),
                            padding: const EdgeInsets.all(Space.s),
                            decoration: BoxDecoration(
                              color: flagged.any(text.contains) ? scheme.errorContainer : null,
                              borderRadius: BorderRadius.circular(Radii.chip),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                                Text(text, style: ReadingText.small(context)),
                              ],
                            ),
                          ),
                      ],
              ),
              if (d['decision'] != null)
                _Block(
                  title: l10n.reviewTitle,
                  children: [
                    Text(
                      '${(d['decision'] as Json)['decision']} · ${(d['decision'] as Json)['by']} · ${_date((d['decision'] as Json)['at'] as String?)}',
                    ),
                  ],
                ),
              const SizedBox(height: Space.m),
              TextField(
                key: const Key('review-note'),
                controller: _note,
                maxLength: 500,
                decoration: InputDecoration(labelText: l10n.reviewNote),
              ),
              if (blocked)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.s),
                  child: Text(l10n.reviewBlockedOnly, style: TextStyle(color: scheme.error)),
                ),
              compactButtons(
                context,
                Wrap(
                  spacing: Space.m,
                  runSpacing: Space.s,
                  alignment: WrapAlignment.end,
                  children: [
                    AppOutlinedButton.icon(
                      key: const Key('review-reject'),
                      onPressed: _busy ? null : () => _decide(false),
                      icon: const Icon(Icons.close),
                      label: Text(l10n.reviewReject),
                    ),
                    AppFilledButton.icon(
                      key: const Key('review-approve'),
                      onPressed: _busy || blocked || texts.isEmpty ? null : () => _decide(true),
                      icon: const Icon(Icons.check),
                      label: Text(l10n.reviewApprove),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.l),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: Space.s),
        ...children,
      ],
    ),
  );
}

/// Every AI-written sentence in held content, labelled by where it sits. Engine
/// data (facts, ids, refs, numbers) is left out: the reviewer reads exactly the
/// text that would be released.
List<(String, String)> reviewTexts(Object? content) {
  const skipKeys = {
    'facts',
    'fact_refs',
    'source_level',
    'horizon',
    'id',
    'upper',
    'lower',
    'trigram',
    'wuxing',
    'relation',
    'key',
    'expectation',
    'ganzhi',
  };
  final out = <(String, String)>[];
  void walk(Object? v, String label) {
    if (v is String) {
      if (v.trim().isNotEmpty) out.add((label, v));
    } else if (v is List) {
      for (final (i, x) in v.indexed) {
        walk(x, '$label ${i + 1}');
      }
    } else if (v is Map) {
      final named = v['topic'] ?? v['key'];
      for (final e in v.entries) {
        if (skipKeys.contains(e.key)) continue;
        final here = [
          if (label.isNotEmpty) label,
          if (named != null && e.key != 'topic') '$named',
          if (e.key != 'topic') e.key,
        ].join(' · ');
        if (e.key == 'topic') continue;
        walk(e.value, here);
      }
    }
  }

  if (content is Map && content.containsKey('layers')) {
    walk(content['layers'], '');
  } else {
    walk(content, '');
  }
  return out;
}
