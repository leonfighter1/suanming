import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mingli_app/presentation/buttons.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/keyboard.dart';
import 'package:mingli_app/presentation/layout.dart';
import 'package:mingli_app/presentation/tokens.dart';

import '../../application/providers.dart';
import '../messages.dart';
import 'dashboard.dart' show containerSide;

// The pieces every page of the 管理后台 is made of (tech plan S22).

/// A page's content without a panel: one scrolling column in the dashboard's container ([pageMax], centred on a
/// wider window), the window class's margins inside it (the ui-design skill's grid), so its left edge is every page's.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final side = containerSide(box.maxWidth) + WindowClass.ofContext(context).margin;
          return ListView(padding: EdgeInsets.fromLTRB(side, Space.m, side, Space.xxl), children: children);
        },
      );
}

/// A page's heading: its title, a line under it, and its controls at the end (on a phone, under it).
class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.l),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Space.l,
        runSpacing: Space.m,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineSmall),
              if (subtitle != null)
                Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The period the pages with numbers show: the last 7, 30 or 90 days (←/→ move between them).
class PeriodPicker extends ConsumerWidget {
  const PeriodPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SegmentKeys<int>(
        child: SegmentedButton<int>(
          key: const Key('period'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 7, label: Text('7 天')),
            ButtonSegment(value: 30, label: Text('30 天')),
            ButtonSegment(value: 90, label: Text('90 天')),
          ],
          selected: {ref.watch(daysProvider)},
          onSelectionChanged: (s) => ref.read(daysProvider.notifier).set(s.first),
        ),
      );
}

/// What the server sent, once it is here: a spinner before, the problem and 重试 if it failed. While another period
/// loads, the numbers shown stay, under a thin progress line.
class AsyncView<T> extends StatelessWidget {
  const AsyncView(this.value, {super.key, required this.data, required this.onRetry});
  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final body = value.when(
      skipLoadingOnReload: true,
      data: data,
      loading: () => const Padding(
        padding: EdgeInsets.all(Space.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Problem(problemText(e), onRetry: onRetry),
    );
    if (!(value.isLoading && value.hasValue)) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [const LinearProgressIndicator(minHeight: 2), body],
    );
  }
}

class Problem extends StatelessWidget {
  const Problem(this.text, {super.key, required this.onRetry});
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(Space.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: scheme.error),
          const SizedBox(height: Space.s),
          Text(text, key: const Key('problem'), textAlign: TextAlign.center),
          const SizedBox(height: Space.m),
          AppOutlinedButton.icon(
            key: const Key('retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

/// What is wrong, one line each, with its icon: the error's colour, or with [warning] the warning's, for what may be
/// wrong but doesn't stop a save (内容's colours hard to read, S34).
class ProblemList extends StatelessWidget {
  const ProblemList(this.problems, {super.key, this.warning = false});
  final List<String> problems;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = ThemeTokens.of(context);
    final colour = warning ? t.warning : t.danger;
    final style = theme.textTheme.bodyMedium?.copyWith(color: colour);
    const size = Space.l;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in problems)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xxs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: firstLineInset(style, size)),
                  child: Icon(warning ? Icons.warning_amber_outlined : Icons.error_outline, size: size, color: colour),
                ),
                const SizedBox(width: Space.s),
                Expanded(child: Text(p, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}

/// A table that scrolls sideways when it is wider than the page: Tab reaches it, ←/→ (Home, End) scroll it, and a
/// button inside it brings itself into view as it takes the focus.
class DataGrid extends StatefulWidget {
  const DataGrid({
    super.key,
    required this.columns,
    required this.rows,
    this.label = '表格',
    this.sortColumnIndex,
    this.sortAscending = true,
    this.empty = '没有数据',
  });
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final String label;
  final int? sortColumnIndex;
  final bool sortAscending;

  /// Shown instead of a table without rows.
  final String empty;

  @override
  State<DataGrid> createState() => _DataGridState();
}

class _DataGridState extends State<DataGrid> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _to(double Function(ScrollPosition p) where) {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    _scroll.animateTo(
      where(p).clamp(0, p.maxScrollExtent),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.m),
        child: Text(widget.empty, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );
    }
    return Pressable(
      key: ValueKey<String>('grid-${widget.label}'),
      label: '${widget.label}：左右方向键横向滚动',
      keys: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _to((p) => p.pixels - 160),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _to((p) => p.pixels + 160),
        const SingleActivator(LogicalKeyboardKey.home): () => _to((_) => 0),
        const SingleActivator(LogicalKeyboardKey.end): () => _to((p) => p.maxScrollExtent),
      },
      child: Scrollbar(
        controller: _scroll,
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: widget.columns,
            rows: widget.rows,
            sortColumnIndex: widget.sortColumnIndex,
            sortAscending: widget.sortAscending,
            headingRowHeight: 44,
            dataRowMinHeight: 40,
            dataRowMaxHeight: 56,
            columnSpacing: Space.xl,
            horizontalMargin: Space.s,
            headingTextStyle: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// A number in a table, its figures aligned.
Widget numText(String s, {Color? color}) => Text(
      s,
      style: TextStyle(fontFeatures: const [FontFeature.tabularFigures()], color: color),
    );

/// A label and its value, side by side (an account's facts).
class Fact extends StatelessWidget {
  const Fact(this.label, this.value, {super.key, this.valueKey});
  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, key: valueKey, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// A dialog's width (the ui-design skill: 520 to 640).
const dialogWidth = 520.0;

/// Asks before an action: [title], [body], 取消 and 确定. Enter confirms, Esc cancels; true when confirmed.
Future<bool> confirmAction(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          AppTextButton(key: const Key('confirm-no'), onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          AppFilledButton(
            key: const Key('confirm-yes'),
            autofocus: true,
            onPressed: () => Navigator.pop(c, true),
            child: const Text('确定'),
          ),
        ],
      ),
    ) ??
    false;
