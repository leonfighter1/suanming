import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mingli_app/presentation/buttons.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/keyboard.dart';
import 'package:mingli_app/presentation/tokens.dart';

import '../application/providers.dart';
import '../data/admin_api.dart';
import '../domain/models.dart';
import 'format.dart';
import 'messages.dart';
import 'widgets/common.dart';
import 'widgets/dashboard.dart';

/// The groups, in the page's order, with their names.
const _groups = [
  // 维护 (S35) first: the switch an admin reaches for in a hurry.
  ('maintenance', '维护'),
  ('sessions', '登录'),
  ('codes', '验证码'),
  ('ai', 'AI'),
  ('limits', '限额'),
  ('content', '修改页面内容'),
  ('currencies', '货币'),
  ('points', '积分'),
];

/// 设置 (tech plan S31; the owner: 「Move all the configurations into separate files, CMS controlling panel is able to
/// read and adjust those values … we can switch the AI modal in the panel as well. turn on or off the Modal mocking.
/// checkbox on different accepted currencies by admin … Admin can choose the main displayed currencies for
/// dashboard」): every setting by group, each with its control, its default and 恢复默认. A change holds on the server
/// from the next request on. In the panel: what answers AI calls now, and the day of the rates 充值 uses.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  /// Where 跳到 takes each group (S36).
  final _targets = {for (final (group, _) in _groups) group: JumpTarget()};

  @override
  void dispose() {
    for (final t in _targets.values) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listing = ref.watch(settingsProvider);
    void retry() => ref.invalidate(settingsProvider);
    List<(String, String)> shown(SettingsListing l) => [for (final g in _groups) if (l.settings.any((s) => s.group == g.$1)) g];
    Widget card(SettingsListing l, (String, String) g) => _targets[g.$1]!.wrap(
          AppCard(
            key: ValueKey<String>('group-${g.$1}'),
            title: g.$2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, s) in l.settings.where((s) => s.group == g.$1).indexed) ...[
                  if (i > 0) const Divider(height: Space.xl),
                  _SettingRow(s),
                ],
              ],
            ),
          ),
        );
    // S36 (the owner: 「大师后台设置页面，在超大屏幕时，该grid 布局，目的：减少下滑试时间去查找。 UI friendly，更精准locate
    // sections」): 跳到 in the panel, which keeps in view as the groups scroll (under the header on a narrow window), and
    // the groups in two columns where there is room.
    return DashboardLayout(
      narrowAt: 1,
      main: [
        const PageHeader('设置', subtitle: 'config/settings.json 和 .env 里的设置。这里改了，服务器从下一个请求起就用新的值；可以恢复默认。'),
        AsyncView(
          listing,
          onRetry: retry,
          data: (l) => LayoutBuilder(
            builder: (context, box) {
              final groups = shown(l);
              if (box.maxWidth < _twoColumnsFrom) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final g in groups) card(l, g)]);
              }
              // Each group, in its order, to the shorter column.
              final columns = [<(String, String)>[], <(String, String)>[]];
              final rows = [0, 0];
              for (final g in groups) {
                final c = rows[0] <= rows[1] ? 0 : 1;
                columns[c].add(g);
                rows[c] += _rowsOf(l, g.$1);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, c) in columns.indexed) ...[
                    if (i > 0) const SizedBox(width: Space.xl),
                    Expanded(
                      key: ValueKey<String>('settings-column-$i'),
                      child: FocusTraversalGroup(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final g in c) card(l, g)]),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
      aside: [
        AsyncView(
          listing,
          onRetry: retry,
          data: (l) => PanelSection(
            first: true,
            title: '跳到',
            child: Wrap(
              key: const Key('settings-jump'),
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final (group, name) in shown(l))
                  ActionChip(key: ValueKey<String>('jump-$group'), label: Text(name), onPressed: () => _targets[group]!.jump()),
              ],
            ),
          ),
        ),
        AsyncView(listing, onRetry: retry, data: (l) => _Now(l)),
      ],
    );
  }
}

/// The main column's width from which 设置's groups sit in two columns (S36; from a window of about 1440): each
/// then at least as wide as a setting's field and its buttons, or the packs' editor (400), need.
const _twoColumnsFrom = 880.0;

/// How tall a group is, near enough to share them out: a setting a row, the packs' editor four.
int _rowsOf(SettingsListing l, String group) =>
    l.settings.where((s) => s.group == group).fold(0, (n, s) => n + (s.type == 'packs' ? 4 : 1));

/// What answers AI calls now, and the day of the rates 充值 uses.
class _Now extends StatelessWidget {
  const _Now(this.l);
  final SettingsListing l;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = ThemeTokens.of(context);
    Widget row(String label, String value, {Key? key, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: theme.textTheme.titleSmall),
              const SizedBox(height: Space.xxs),
              Text(value, key: key, style: theme.textTheme.bodySmall?.copyWith(color: color ?? t.textSecondary)),
            ],
          ),
        );
    final mock = l.serving == null || l.serving == 'mock';
    final date = l.ratesDate;
    return PanelSection(
      title: '现在',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            'AI',
            mock ? '模拟：示范回答，不花 token' : '真实模型：${l.models ?? l.serving}（花 token）',
            key: const Key('now-ai'),
            color: mock ? null : t.warning,
          ),
          row(
            '汇率',
            date == null
                ? '还没有：汇率服务没有回应过，充值只收元'
                : l.ratesStale
                    ? '$date 的（汇率服务连不上，用的是最后一次的）'
                    : '$date 的，每天更新',
            key: const Key('now-rates'),
            color: date == null || l.ratesStale ? t.warning : null,
          ),
        ],
      ),
    );
  }
}

/// A number as a field shows it: 2, 0.5.
String _number(Object? v) => v is num ? (v == v.roundToDouble() ? '${v.toInt()}' : '$v') : '';

/// A setting's value in words: 2 天, 0.5 天, 1,000,000 积分, 开, 跟随 .env, CNY、HKD, 10 元 1,000 积分、20 元 2,200 积分.
String _say(SettingView s, Object? v) => switch (v) {
      // A time (S35, 维护's end): none is the window users are told by default.
      null when s.type == 'time' => '不设（从打开维护时起 3 到 4 小时）',
      String t when s.type == 'time' => localTime(DateTime.parse(t)),
      null => '跟随 .env',
      bool b => b ? '开' : '关',
      num n => '${n == n.roundToDouble() ? count(n) : _number(n)}${s.unit == null ? '' : ' ${s.unit}'}',
      List<Object?> l when s.type == 'packs' => [for (final p in l.cast<Json>()) '${_number(p['yuan'])} 元 ${count(p['points'] as num)} 积分'].join('、'),
      List<Object?> l => l.join('、'),
      _ => '$v',
    };

/// One setting: its label and line, its control, its default, 已修改 and 恢复默认. A change is saved as it is made (a
/// number on Enter or 保存); what the server refuses shows under it.
class _SettingRow extends ConsumerStatefulWidget {
  const _SettingRow(this.s);
  final SettingView s;

  @override
  ConsumerState<_SettingRow> createState() => _SettingRowState();
}

class _SettingRowState extends ConsumerState<_SettingRow> {
  late final _field = TextEditingController(text: _number(widget.s.value));
  bool _busy = false;
  String? _refused;

  SettingView get s => widget.s;

  @override
  void didUpdateWidget(_SettingRow old) {
    super.didUpdateWidget(old);
    if (old.s.value != s.value) _field.text = _number(s.value);
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _change(Future<SettingView> Function(AdminApi api) call, String done) async {
    setState(() {
      _busy = true;
      _refused = null;
    });
    try {
      await call(ref.read(adminApiProvider));
      ref.invalidate(settingsProvider);
      // These come with the session (/v1/admin/me): the dashboard's currency, 增加积分's most.
      if (s.key == 'currencies.dashboard' || s.key == 'limits.grant_max') {
        await ref.read(sessionProvider.notifier).recheck();
      }
      if (mounted) say(context, done);
    } on AdminApiException catch (e) {
      if (mounted) setState(() => _refused = problemText(e));
    } catch (e) {
      if (mounted) say(context, problemText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(Object? value) async {
    // Asked first: off the mock, the real model, which spends tokens (CLAUDE.md rule 5: the owner's switch); 维护 on
    // (S35), everyone but staff waits from that moment.
    final ask = switch ((s.key, value)) {
      ('ai.mock', false) => ('关掉 AI 模拟？', '之后每一步 AI 都用真实模型，会花 token，并按实际用量收积分。'),
      ('maintenance.on', true) => ('打开维护？', '除了后台人员，用户都不能登录、注册或使用应用，直到你关掉；应用会告诉他们大约什么时候可以再登录。'),
      _ => null,
    };
    if (ask != null && !await confirmAction(context, ask.$1, ask.$2)) return;
    if (!mounted) return;
    await _change((api) => api.saveSetting(s.key, value), '已保存「${s.label}」');
  }

  /// A time (S35, 维护's end): the day, then the hour and minute (typed where the keyboard is in use), from the one set
  /// or four hours from now; sent in UTC.
  Future<void> _pickTime() async {
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final set = s.value is String ? DateTime.tryParse(s.value as String)?.toLocal() : null;
    final start = set == null || set.isBefore(today) ? now.add(const Duration(hours: 4)) : set;
    final day = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: today,
      lastDate: today.add(const Duration(days: 60)),
      initialEntryMode: keyboardInUse ? DatePickerEntryMode.input : DatePickerEntryMode.calendar,
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
      initialEntryMode: keyboardInUse ? TimePickerEntryMode.input : TimePickerEntryMode.dial,
    );
    if (time == null || !mounted) return;
    await _save(DateTime(day.year, day.month, day.day, time.hour, time.minute).toUtc().toIso8601String());
  }

  void _saveNumber() {
    final n = num.tryParse(_field.text.trim());
    if (n == null) {
      setState(() => _refused = '要一个数字');
      return;
    }
    _save(n);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = ThemeTokens.of(context);
    final from = s.env == null ? '默认' : '默认（${s.env}）';
    return Column(
      key: ValueKey<String>('setting-${s.key}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: Space.s,
          runSpacing: Space.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(s.label, style: theme.textTheme.titleSmall),
            if (s.changed)
              Pill('已修改', key: ValueKey<String>('setting-${s.key}-changed'), color: t.accent, icon: Icons.edit_outlined),
          ],
        ),
        const SizedBox(height: Space.xxs),
        Text(s.about, style: theme.textTheme.bodySmall?.copyWith(color: t.textSecondary)),
        const SizedBox(height: Space.s),
        _control(),
        if (_refused != null) ...[
          const SizedBox(height: Space.xs),
          Text(_refused!, key: ValueKey<String>('setting-${s.key}-refused'), style: theme.textTheme.bodySmall?.copyWith(color: t.danger)),
        ],
        const SizedBox(height: Space.xs),
        Wrap(
          spacing: Space.s,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('$from：${_say(s, s.defaultValue)}', style: theme.textTheme.bodySmall?.copyWith(color: t.textMuted)),
            if (s.changed)
              AppTextButton(
                key: ValueKey<String>('setting-${s.key}-reset'),
                onPressed: _busy ? null : () => _change((api) => api.resetSetting(s.key), '「${s.label}」已恢复默认'),
                child: const Text('恢复默认'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _control() => switch (s.type) {
        'time' => Align(
            alignment: Alignment.centerLeft,
            child: AppOutlinedButton.icon(
              key: ValueKey<String>('setting-${s.key}-pick'),
              onPressed: _busy ? null : _pickTime,
              icon: const Icon(Icons.schedule),
              label: Text(s.value is String ? _say(s, s.value) : '选时间'),
            ),
          ),
        'packs' => _Packs(
            s,
            busy: _busy,
            onSave: _save,
            onEdit: () => setState(() => _refused = null),
            onWrong: (text) => setState(() => _refused = text),
          ),
        'number' => Row(
            children: [
              SizedBox(
                width: _fieldWidth,
                child: TextField(
                  key: ValueKey<String>('setting-${s.key}-field'),
                  controller: _field,
                  enabled: !_busy,
                  keyboardType: TextInputType.numberWithOptions(decimal: !s.integer),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveNumber(),
                  onChanged: (_) => setState(() => _refused = null),
                  decoration: InputDecoration(suffixText: s.unit, isDense: true),
                ),
              ),
              const SizedBox(width: Space.s),
              AppFilledButton(
                key: ValueKey<String>('setting-${s.key}-save'),
                onPressed: _busy || _field.text.trim() == _number(s.value) ? null : _saveNumber,
                child: const Text('保存'),
              ),
            ],
          ),
        'boolean' => Align(
            alignment: Alignment.centerLeft,
            child: SegmentKeys<String>(
              child: SegmentedButton<String>(
                key: ValueKey<String>('setting-${s.key}-choice'),
                showSelectedIcon: false,
                segments: [
                  if (s.optional) const ButtonSegment(value: 'unset', label: Text('跟随 .env')),
                  const ButtonSegment(value: 'on', label: Text('开')),
                  const ButtonSegment(value: 'off', label: Text('关')),
                ],
                selected: {switch (s.value) { true => 'on', false => 'off', _ => 'unset' }},
                onSelectionChanged: _busy
                    ? null
                    : (v) => v.first == 'unset'
                        ? _change((api) => api.resetSetting(s.key), '「${s.label}」跟随 .env')
                        : _save(v.first == 'on'),
              ),
            ),
          ),
        'choice' => Align(
            alignment: Alignment.centerLeft,
            child: DropdownMenu<String>(
              key: ValueKey<String>('setting-${s.key}-menu'),
              enabled: !_busy,
              requestFocusOnTap: false,
              initialSelection: s.value as String? ?? _unset,
              dropdownMenuEntries: [
                if (s.optional) const DropdownMenuEntry(value: _unset, label: '跟随 .env'),
                for (final o in s.options) DropdownMenuEntry(value: o, label: o),
              ],
              onSelected: (v) => v == null || v == s.value || (v == _unset && s.value == null)
                  ? null
                  : v == _unset
                      ? _change((api) => api.resetSetting(s.key), '「${s.label}」跟随 .env')
                      : _save(v),
            ),
          ),
        _ => Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              for (final o in s.options)
                FilterChip(
                  key: ValueKey<String>('setting-${s.key}-$o'),
                  label: Text(o),
                  selected: (s.value as List? ?? const []).contains(o),
                  onSelected: _busy
                      ? null
                      : (on) {
                          final now = [...(s.value as List? ?? const [])];
                          on ? now.add(o) : now.remove(o);
                          // In the catalog's order, as the listing shows them.
                          _save([for (final x in s.options) if (now.contains(x)) x]);
                        },
                ),
            ],
          ),
      };
}

/// 充值套餐 (S32): each pack's 元 and 积分 on a row, one to take out, one more to add, and 保存, which sends them by
/// price. The server checks them (at least 100 积分 a 元, no two at one price); what it refuses shows under them, as
/// for any setting.
class _Packs extends StatefulWidget {
  const _Packs(this.s, {required this.busy, required this.onSave, required this.onEdit, required this.onWrong});
  final SettingView s;
  final bool busy;
  final Future<void> Function(Object? value) onSave;

  /// A field changed: the row's refusal goes, and 保存 looks again.
  final VoidCallback onEdit;

  /// A row without numbers, said under the packs.
  final ValueChanged<String> onWrong;

  @override
  State<_Packs> createState() => _PacksState();
}

class _PacksState extends State<_Packs> {
  late var _rows = _fromValue();

  String get _key => widget.s.key;
  List<Json> get _value => (widget.s.value as List? ?? const []).cast<Json>();

  List<(TextEditingController, TextEditingController)> _fromValue() => [
        for (final p in _value)
          (TextEditingController(text: _number(p['yuan'])), TextEditingController(text: _number(p['points']))),
      ];

  /// The rows as they are, and as the server has them: 保存 only when they differ.
  String get _now => [for (final (y, p) in _rows) '${y.text.trim()}:${p.text.trim()}'].join(',');
  String get _was => [for (final p in _value) '${_number(p['yuan'])}:${_number(p['points'])}'].join(',');

  @override
  void didUpdateWidget(_Packs old) {
    super.didUpdateWidget(old);
    if (jsonEncode(old.s.value) != jsonEncode(widget.s.value)) {
      _disposeRows();
      _rows = _fromValue();
    }
  }

  @override
  void dispose() {
    _disposeRows();
    super.dispose();
  }

  void _disposeRows() {
    for (final (y, p) in _rows) {
      y.dispose();
      p.dispose();
    }
  }

  void _remove(int i) {
    final (y, p) = _rows[i];
    setState(() => _rows.removeAt(i));
    y.dispose();
    p.dispose();
    widget.onEdit();
  }

  void _save() {
    final packs = <Json>[];
    for (final (y, p) in _rows) {
      final yuan = num.tryParse(y.text.trim());
      final points = int.tryParse(p.text.trim());
      if (yuan == null || points == null) return widget.onWrong('每个套餐都要写元和积分（数字）');
      packs.add({'yuan': yuan, 'points': points});
    }
    packs.sort((a, b) => (a['yuan'] as num).compareTo(b['yuan'] as num));
    widget.onSave(packs);
  }

  Widget _field(TextEditingController c, String name, String unit, {bool decimal = false, bool last = false}) => TextField(
        key: ValueKey<String>('setting-$_key-$name'),
        controller: c,
        enabled: !widget.busy,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        onChanged: (_) => widget.onEdit(),
        onSubmitted: last ? (_) => _now == _was ? null : _save() : null,
        decoration: InputDecoration(suffixText: unit, isDense: true),
      );

  @override
  Widget build(BuildContext context) {
    final most = widget.s.max;
    // The row's column stretches its children: aligned, the rows keep to their width.
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _packsWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, (yuan, points)) in _rows.indexed) ...[
              if (i > 0) const SizedBox(height: Space.s),
              Row(
                children: [
                  Expanded(flex: 2, child: _field(yuan, 'yuan-$i', '元', decimal: true)),
                  const SizedBox(width: Space.s),
                  Expanded(flex: 3, child: _field(points, 'points-$i', '积分', last: i == _rows.length - 1)),
                  const SizedBox(width: Space.xs),
                  AppIconButton(
                    key: ValueKey<String>('setting-$_key-remove-$i'),
                    tooltip: '去掉这个套餐',
                    onPressed: widget.busy || _rows.length == 1 ? null : () => _remove(i),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Space.s),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.xs,
              children: [
                AppTextButton.icon(
                  key: ValueKey<String>('setting-$_key-add'),
                  onPressed: widget.busy || (most != null && _rows.length >= most)
                      ? null
                      : () {
                          setState(() => _rows.add((TextEditingController(), TextEditingController())));
                          widget.onEdit();
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('添加套餐'),
                ),
                AppFilledButton(
                  key: ValueKey<String>('setting-$_key-save'),
                  onPressed: widget.busy || _now == _was ? null : _save,
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The dropdown's entry for an optional choice left unset.
const _unset = '';

/// A number field's width: a value and its unit.
const _fieldWidth = 160.0;

/// The packs' rows at most: a price, its 积分 and the button that takes it out.
const _packsWidth = 400.0;
