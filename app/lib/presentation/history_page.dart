import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/providers.dart';
import '../data/api_client.dart';
import '../domain/archive.dart';
import '../domain/document.dart';
import '../domain/life_report.dart';
import '../domain/models.dart';
import '../domain/profile.dart';
import '../l10n/gen/app_localizations.dart';
import 'archive_actions.dart';
import 'design.dart';
import 'keyboard.dart' show SegmentKeys;
import 'layout.dart';
import 'life_report_page.dart';
import 'report_page.dart';
import 'settings_page.dart';
import 'theme.dart';
import 'widgets/tarot_spread.dart';

/// 以往记录 (v8.0.0, the owner): every reading and 一生运势报告, by year and month (newest first) or by person. Each can be
/// downloaded as PDF or Word, sent, filed under a person or deleted; 选择 does the same for several at once. Pull down
/// to refresh.
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

enum _Act { pdf, docx, send, email, file, delete }

class _HistoryPageState extends ConsumerState<HistoryPage> {
  bool _byPerson = false;
  bool _selecting = false;
  final _selected = <String>{};
  bool _busy = false;

  List<ArchiveRecord> _records() => [
        for (final it in ref.watch(historyProvider).value ?? const <HistoryItem>[]) ArchiveRecord.reading(it),
        for (final r in ref.watch(lifeReportsProvider).value ?? const <LifeReportView>[]) ArchiveRecord.life(r),
      ];

  void _refresh() {
    ref.invalidate(historyProvider);
    ref.invalidate(lifeReportsProvider);
  }

  void _toggle(ArchiveRecord r) => setState(() {
        if (!_selected.remove(r.key)) _selected.add(r.key);
      });

  void _stopSelecting() => setState(() {
        _selecting = false;
        _selected.clear();
      });

  /// Runs [work] with the page busy, and says what went wrong if it fails.
  Future<void> _busyWith(Future<void> Function() work) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await work();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.archiveDocFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 下载 and 发送: the records' documents in [format] (asked for when null), shared.
  Future<void> _share(List<ArchiveRecord> records, {DocFormat? format}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ready = records.where((r) => r.passed).toList();
    if (ready.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.archiveNotReady)));
      return;
    }
    final as = format ?? await chooseFormat(context);
    if (as == null || !mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.archiveWorking), duration: const Duration(seconds: 2)));
    await _busyWith(() async {
      final docs = [for (final r in ready) await recordDocument(ref, l10n, r)];
      await shareDocuments(ref, docs, as, subject: l10n.history);
    });
  }

  /// 发到邮箱 (v9.0.0): the records' documents, PDF or Word as asked, in one mail to the account's verified email.
  Future<void> _email(List<ArchiveRecord> records) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final user = ref.read(authProvider).value;
    if (user == null || user.email == null || !user.emailVerified) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.emailFirst),
          action: SnackBarAction(
            label: l10n.settings,
            onPressed: () => navigator.push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
          ),
        ),
      );
      return;
    }
    final ready = records.where((r) => r.passed).toList();
    if (ready.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.archiveNotReady)));
      return;
    }
    final as = await chooseFormat(context);
    if (as == null || !mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.archiveWorking), duration: const Duration(seconds: 2)));
    setState(() => _busy = true);
    try {
      final docs = [for (final r in ready) await recordDocument(ref, l10n, r)];
      final locale = ref.read(settingsProvider).apiLocaleCode;
      final sent = await ref.read(apiClientProvider).emailDocuments(docs, as, locale: locale);
      // The result takes the place of 正在生成.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(sent.outbox ? l10n.emailedOutbox(sent.sentTo) : l10n.emailedTo(sent.sentTo))));
      if (_selecting) _stopSelecting();
    } catch (e) {
      final text = switch (e) {
        ApiException(code: 'email_unverified') => l10n.emailFirst,
        ApiException(status: 429) => l10n.emailTooMany,
        _ => l10n.emailFailed,
      };
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(List<ArchiveRecord> records) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (records.isEmpty || !await confirmDelete(context, records.length) || !mounted) return;
    await _busyWith(() async {
      final api = ref.read(apiClientProvider);
      for (final r in records) {
        r.isLife ? await api.deleteLifeReport(r.id) : await api.deleteReport(r.id);
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.archiveDeleted(records.length))));
    });
    if (!mounted) return;
    _stopSelecting();
    _refresh();
  }

  /// 归类到…: files the record's chart under a person, on the server and on this device.
  Future<void> _file(ArchiveRecord r) async {
    final book = ref.read(profilesProvider).value;
    final current = personName(r, book?.chartLabels ?? const {});
    final names = <String>{
      for (final p in book?.profiles ?? const <BirthProfile>[])
        if (p.name.trim().isNotEmpty) p.name.trim(),
    }.toList();
    final name = await chooseFiling(context, names: names, current: current);
    if (name == null || !mounted) return;
    await _busyWith(() async {
      await ref.read(apiClientProvider).setChartPerson(r.chartId, name);
      await ref.read(profilesProvider.notifier).relabelChart(r.chartId, name);
    });
    if (mounted) _refresh();
  }

  void _act(_Act a, ArchiveRecord r) => switch (a) {
        _Act.pdf => _share([r], format: DocFormat.pdf),
        _Act.docx => _share([r], format: DocFormat.docx),
        _Act.send => _share([r]),
        _Act.email => _email([r]),
        _Act.file => _file(r),
        _Act.delete => _delete([r]),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final history = ref.watch(historyProvider);
    final records = _records();
    final labels = ref.watch(profilesProvider).value?.chartLabels ?? const <String, String>{};
    final chosen = records.where((r) => _selected.contains(r.key)).toList();

    Widget tile(ArchiveRecord r) {
      final picked = _selected.contains(r.key);
      final trailing = _selecting
          ? Checkbox(key: ValueKey<String>('pick-${r.key}'), value: picked, onChanged: (_) => _toggle(r))
          : PopupMenuButton<_Act>(
              key: ValueKey<String>('record-menu-${r.key}'),
              tooltip: l10n.more,
              enabled: !_busy,
              onSelected: (a) => _act(a, r),
              itemBuilder: (_) => [
                PopupMenuItem(value: _Act.pdf, child: Text(l10n.archiveDownloadPdf)),
                PopupMenuItem(value: _Act.docx, child: Text(l10n.archiveDownloadWord)),
                PopupMenuItem(value: _Act.send, child: Text(l10n.archiveSend)),
                PopupMenuItem(value: _Act.email, child: Text(l10n.archiveEmail)),
                PopupMenuItem(value: _Act.file, child: Text(l10n.archiveFile)),
                PopupMenuItem(value: _Act.delete, child: Text(l10n.archiveDelete, style: TextStyle(color: scheme.error))),
              ],
            );
      final onTap = _selecting ? () => _toggle(r) : null;
      void onLongPress() => setState(() {
            _selecting = true;
            _selected.add(r.key);
          });
      return r.isLife
          ? _LifeTile(record: r, trailing: trailing, onTap: onTap, onLongPress: onLongPress)
          : HistoryTile(item: r.reading!, trailing: trailing, onTap: onTap, onLongPress: onLongPress);
    }

    Widget header(String text, {required Key key, int? count, bool big = false}) => Padding(
          key: key,
          padding: EdgeInsets.fromLTRB(Space.xs, big ? Space.l : Space.s, Space.xs, Space.s),
          child: Row(
            children: [
              Text(
                text,
                style: (big ? theme.textTheme.titleLarge : theme.textTheme.titleSmall)?.copyWith(
                  color: big ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: Space.s),
                Text(l10n.archiveCount(count), style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ],
          ),
        );

    final children = <Widget>[];
    if (_byPerson) {
      for (final g in byPerson(records, (r) => personName(r, labels))) {
        children.add(
          header(
            g.name ?? l10n.archiveUnfiled,
            key: ValueKey<String>('archive-person-${g.name ?? '-'}'),
            count: g.records.length,
            big: true,
          ),
        );
        children.addAll(g.records.map(tile));
      }
    } else {
      int? year;
      for (final m in byMonth(records)) {
        if (m.year != year) {
          year = m.year;
          children.add(header(l10n.archiveYear(m.year), key: ValueKey<String>('archive-year-${m.year}'), big: true));
        }
        children.add(
          header(
            l10n.archiveMonth(m.month),
            key: ValueKey<String>('archive-month-${m.year}-${m.month}'),
            count: m.records.length,
          ),
        );
        children.addAll(m.records.map(tile));
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: _selecting
            ? IconButton(key: const Key('archive-select-done'), tooltip: l10n.close, icon: const Icon(Icons.close), onPressed: _stopSelecting)
            : null,
        title: Text(_selecting ? l10n.archiveSelected(chosen.length) : l10n.history),
        actions: [
          if (_selecting)
            TextButton(
              key: const Key('archive-select-all'),
              onPressed: () => setState(() => _selected
                ..clear()
                ..addAll(records.map((r) => r.key))),
              child: Text(l10n.archiveSelectAll),
            )
          else if (records.isNotEmpty)
            IconButton(
              key: const Key('archive-select'),
              tooltip: l10n.archiveSelect,
              icon: const Icon(Icons.checklist_rtl),
              onPressed: () => setState(() => _selecting = true),
            ),
        ],
      ),
      bottomNavigationBar: _selecting
          ? Material(
              elevation: 8,
              color: scheme.surfaceContainer,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.xs),
                  // Four actions since 发邮箱 (v9.0.0): four equal slots, each an icon over its label, so they fit a
                  // 360-wide phone (side by side they overflowed it).
                  child: Row(
                    children: [
                      _BarAction(
                        key: const Key('archive-download'),
                        icon: Icons.download_outlined,
                        label: l10n.download,
                        onPressed: chosen.isEmpty || _busy ? null : () => _share(chosen),
                      ),
                      _BarAction(
                        key: const Key('archive-send'),
                        icon: Icons.send_outlined,
                        label: l10n.archiveSend,
                        onPressed: chosen.isEmpty || _busy ? null : () => _share(chosen),
                      ),
                      _BarAction(
                        key: const Key('archive-email'),
                        icon: Icons.mail_outline,
                        label: l10n.archiveEmailShort,
                        onPressed: chosen.isEmpty || _busy ? null : () => _email(chosen),
                      ),
                      _BarAction(
                        key: const Key('archive-delete'),
                        icon: Icons.delete_outline,
                        label: l10n.archiveDelete,
                        color: chosen.isEmpty ? null : scheme.error,
                        onPressed: chosen.isEmpty || _busy ? null : () => _delete(chosen),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(lifeReportsProvider);
          return ref.refresh(historyProvider.future);
        },
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(padding: pagePadding(context), children: [Text('$e')]),
          data: (_) => records.isEmpty
              ? ListView(
                  padding: pagePadding(context),
                  children: [EmptyState(icon: Icons.history_toggle_off, text: l10n.historyEmpty)],
                )
              : ListView(
                  padding: pagePadding(context),
                  children: [
                    SegmentKeys(
                      child: SegmentedButton<bool>(
                        key: const Key('archive-view'),
                        segments: [
                          ButtonSegment(value: false, icon: const Icon(Icons.calendar_month_outlined), label: Text(l10n.archiveByTime)),
                          ButtonSegment(value: true, icon: const Icon(Icons.people_outline), label: Text(l10n.archiveByPerson)),
                        ],
                        selected: {_byPerson},
                        onSelectionChanged: (s) => setState(() => _byPerson = s.first),
                      ),
                    ),
                    if (_busy) const Padding(padding: EdgeInsets.only(top: Space.s), child: LinearProgressIndicator()),
                    ...children,
                  ],
                ),
        ),
      ),
    );
  }
}

/// A 一生运势报告 in the archive.
/// One action of the 选择 bar: an icon over its label, a quarter of the bar wide. A TextButton, so Tab reaches it
/// and Enter presses it.
class _BarAction extends StatelessWidget {
  const _BarAction({super.key, required this.icon, required this.label, this.onPressed, this.color});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.xs),
            foregroundColor: color,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon),
              const SizedBox(height: Space.xxs),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}

class _LifeTile extends ConsumerWidget {
  const _LifeTile({required this.record, required this.trailing, this.onTap, this.onLongPress});
  final ArchiveRecord record;
  final Widget trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final labels = ref.watch(profilesProvider).value?.chartLabels ?? const <String, String>{};
    final name = personName(record, labels);
    return AppCard(
      key: Key('history-life-${record.id}'),
      padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.xs, Space.s),
      onTap: onTap ??
          () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LifeReportPage(reportId: record.id))),
      onLongPress: onLongPress,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.auto_stories),
        title: Text(name == null ? l10n.lifeEntry : l10n.lifeReportOf(name)),
        subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(record.createdAt)),
        trailing: trailing,
      ),
    );
  }
}

/// The latest three readings on the home screen.
class RecentHistory extends ConsumerWidget {
  const RecentHistory({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(historyProvider).value ?? const [];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: items.isEmpty
          ? const SizedBox.shrink()
          : Column(
              key: ValueKey(items.length),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.xs, Space.l, Space.xs, Space.s),
                  child: Row(
                    children: [
                      Expanded(child: Text(l10n.recent, style: Theme.of(context).textTheme.titleMedium)),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HistoryPage())),
                        child: Text(l10n.viewAll),
                      ),
                    ],
                  ),
                ),
                for (final it in items.take(3)) HistoryTile(item: it),
              ],
            ),
    );
  }
}

class HistoryTile extends ConsumerWidget {
  const HistoryTile({super.key, required this.item, this.trailing, this.onTap, this.onLongPress});
  final HistoryItem item;

  /// After the status (v8.0.0): the record's menu, or its checkbox while selecting.
  final Widget? trailing;

  /// In place of opening the reading (v8.0.0: selecting).
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final terms = ref.watch(termsProvider).value;
    final record = ArchiveRecord.reading(item);
    // Whose chart: kept with the chart on the server (v6.2.0; 归类到… changes it, v8.0.0), else this device's label.
    final book = ref.watch(profilesProvider).value;
    final label = personName(record, book?.chartLabels ?? const {});
    final place = item.person?.birthplace ?? book?.chartPlaces[item.chartId];
    final scheme = Theme.of(context).colorScheme;
    final (statusText, statusColor) = switch (item.status) {
      'passed' => (l10n.aiReport, scheme.primary),
      'pending' => (l10n.analyzing, scheme.tertiary),
      'failed' => (l10n.statusFailed, scheme.error),
      _ => (l10n.statusReview, scheme.outline),
    };
    final title = recordTitle(l10n, record, person: label, terms: terms, locale: locale);
    final lot = item.lotNumber == null ? null : terms?.lots?.lot(item.lotNumber!);
    return AppCard(
      padding: EdgeInsets.fromLTRB(Space.l, Space.l, trailing == null ? Space.l : Space.xs, Space.l),
      onTap: onTap ??
          () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => ReportPage(reportId: item.reportId, title: title, place: place)),
              ),
      onLongPress: onLongPress,
      child: Row(
        children: [
          Icon(
            switch (item.system) {
              'bazi' => Icons.grid_view_rounded,
              'qiuqian' => Icons.temple_buddhist_outlined,
              'fengshui' => Icons.explore_outlined,
              'naming' => Icons.badge_outlined,
              'liuyao' => Icons.toll_outlined,
              _ => Icons.style_rounded,
            },
            color: scheme.primary,
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: Space.xs),
                if (item.fourPillars != null)
                  GanZhiText(item.fourPillars!, size: 15)
                else if (lot != null)
                  // 求籤: the lot's title and label, and the poem's first line.
                  Text(
                    '${lot.title(locale)} · ${lot.ganzhi} · ${lot.poem(locale).first}',
                    key: const Key('history-lot'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (item.cardIds.isNotEmpty) ...[
                  // The cards' art, small (v2.4.0); a reversed card upside down, as it was drawn.
                  Row(
                    key: const Key('history-art'),
                    children: [
                      for (final (i, id) in item.cardIds.take(5).indexed)
                        Padding(
                          padding: const EdgeInsets.only(right: Space.xs),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(Radii.xxs),
                            child: RotatedBox(
                              quarterTurns: i < item.cardsReversed.length && item.cardsReversed[i] ? 2 : 0,
                              child: Image.asset(
                                tarotArt(id),
                                width: 22,
                                height: 38,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const SizedBox(width: 22, height: 38),
                              ),
                            ),
                          ),
                        ),
                      if (item.cardIds.length > 5)
                        Text('+${item.cardIds.length - 5}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    item.cardIds.map((c) => terms?.card(c, locale) ?? c).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: Space.xs),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Pill(statusText, color: statusColor),
          ?trailing,
        ],
      ),
    );
  }
}
