import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mingli_app/presentation/buttons.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/keyboard.dart';
import 'package:mingli_app/presentation/tokens.dart';

import '../application/providers.dart';
import '../data/admin_api.dart';
import '../domain/models.dart';
import 'messages.dart';
import 'widgets/common.dart';
import 'widgets/dashboard.dart';

/// The groups, in the page's order, with their names.
const _groups = [('sessions', '登录'), ('ai', 'AI'), ('limits', '限额'), ('currencies', '货币')];

/// 设置 (tech plan S31; the owner: 「Move all the configurations into separate files, CMS controlling panel is able to
/// read and adjust those values … we can switch the AI modal in the panel as well. turn on or off the Modal mocking.
/// checkbox on different accepted currencies by admin … Admin can choose the main displayed currencies for
/// dashboard」): every setting by group, each with its control, its default and 恢复默认. A change holds on the server
/// from the next request on. In the panel: what answers AI calls now, and the day of the rates 充值 uses.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing = ref.watch(settingsProvider);
    void retry() => ref.invalidate(settingsProvider);
    return DashboardLayout(
      main: [
        const PageHeader('设置', subtitle: 'config/settings.json 和 .env 里的设置。这里改了，服务器从下一个请求起就用新的值；可以恢复默认。'),
        AsyncView(
          listing,
          onRetry: retry,
          data: (l) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (group, name) in _groups)
                if (l.settings.any((s) => s.group == group))
                  AppCard(
                    key: ValueKey<String>('group-$group'),
                    title: name,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, s) in l.settings.where((s) => s.group == group).indexed) ...[
                          if (i > 0) const Divider(height: Space.xl),
                          _SettingRow(s),
                        ],
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
      aside: [AsyncView(listing, onRetry: retry, data: (l) => _Now(l))],
    );
  }
}

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
      first: true,
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

/// A setting's value in words: 2 天, 开, 跟随 .env, CNY、HKD.
String _say(SettingView s, Object? v) => switch (v) {
      null => '跟随 .env',
      bool b => b ? '开' : '关',
      num n => '${_number(n)}${s.unit == null ? '' : ' ${s.unit}'}',
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
      // The dashboard's currency comes with the session (/v1/admin/me).
      if (s.key == 'currencies.dashboard') await ref.read(sessionProvider.notifier).recheck();
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
    // Off the mock: the real model, which spends tokens (CLAUDE.md rule 5: the owner's switch).
    if (s.key == 'ai.mock' && value == false &&
        !await confirmAction(context, '关掉 AI 模拟？', '之后每一步 AI 都用真实模型，会花 token，并按实际用量收积分。')) {
      return;
    }
    if (!mounted) return;
    await _change((api) => api.saveSetting(s.key, value), '已保存「${s.label}」');
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

/// The dropdown's entry for an optional choice left unset.
const _unset = '';

/// A number field's width: a value and its unit.
const _fieldWidth = 160.0;
