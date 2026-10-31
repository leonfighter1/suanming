import 'dart:math';

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

/// How many texts the list shows at first, and how many more each 再显示 adds.
const _pageSize = 30;

/// A thumbnail's height in the panel.
const _thumbHeight = 96.0;

/// What staff call the types an image may be.
const _typeNames = {'image/png': 'PNG', 'image/jpeg': 'JPEG', 'image/webp': 'WebP'};

/// 内容 (内容管理, tech plan S29; the owner: 「create a CMS system, that can modify the resources of context for different
/// places of the text, images … extract as much text as possible into the content integration pages」): every text the
/// app shows, found by its words or its key, each opening its editor; in the panel the search, 已修改, and the images the
/// app takes from here, each put in or taken out. The app shows the changes the next time it opens.
class ContentPage extends ConsumerStatefulWidget {
  const ContentPage({super.key});

  @override
  ConsumerState<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends ConsumerState<ContentPage> {
  final _search = TextEditingController();
  bool _changedOnly = false;
  int _shown = _pageSize;

  /// The image being put in or taken out.
  String? _busyImage;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The texts the search finds (in their key or in a wording, the app's or staff's, in any language), 已修改 only
  /// when asked.
  List<ContentText> _matches(ContentListing l) {
    final q = _search.text.trim().toLowerCase();
    bool found(ContentText t) =>
        q.isEmpty ||
        t.key.toLowerCase().contains(q) ||
        [...t.defaults.values, ...t.changed.values].any((w) => w.toLowerCase().contains(q));
    return [for (final t in l.texts) if ((!_changedOnly || t.changed.isNotEmpty) && found(t)) t];
  }

  /// A new search or filter starts from the first texts again.
  void _refind(void Function() change) => setState(() {
        change();
        _shown = _pageSize;
      });

  Future<void> _edit(ContentListing l, ContentText t) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _TextDialog(text: t, locales: l.locales));
    if (!mounted) return;
    // Also after 取消 or Esc: a language may have been saved before another was refused.
    ref.invalidate(contentProvider);
    if (saved == true) say(context, '已保存，应用下次打开时显示');
  }

  /// An image chosen, checked against what the server takes, and put in.
  Future<void> _putImage(ContentListing l, ContentImage image) async {
    final file = await ref.read(pickFileProvider)(l.imageTypes);
    if (file == null || !mounted) return;
    if (!l.imageTypes.contains(file.mime)) {
      say(context, '要 ${_types(l)} 格式的图片');
      return;
    }
    if (file.bytes.length > l.imageMaxBytes) {
      say(context, '图片太大了：最多 ${fileSize(l.imageMaxBytes)}');
      return;
    }
    await _changeImage(image, '已换上「${image.label}」，应用下次打开时显示', (api) => api.putImage(image.key, file));
  }

  /// An image taken out, asked first: the app shows its own again.
  Future<void> _removeImage(ContentImage image) async {
    if (!await confirmAction(context, '移除「${image.label}」？', '应用会改回自带的图片。')) return;
    if (!mounted) return;
    await _changeImage(image, '已移除「${image.label}」', (api) => api.removeImage(image.key));
  }

  Future<void> _changeImage(ContentImage image, String done, Future<void> Function(AdminApi api) change) async {
    setState(() => _busyImage = image.key);
    try {
      await change(ref.read(adminApiProvider));
      ref.invalidate(contentProvider);
      if (mounted) say(context, done);
    } catch (e) {
      if (mounted) say(context, problemText(e));
    } finally {
      if (mounted) setState(() => _busyImage = null);
    }
  }

  static String _types(ContentListing l) => [for (final t in l.imageTypes) _typeNames[t] ?? t].join('、');

  @override
  Widget build(BuildContext context) {
    final listing = ref.watch(contentProvider);
    void retry() => ref.invalidate(contentProvider);
    return DashboardLayout(
      // The texts in the main column; the search, the filter and the images in the panel, before the texts on a
      // narrow screen (as 用户's).
      narrowAt: 1,
      main: [
        const PageHeader('内容', subtitle: '应用里的文字和图片，每种语言一份。改过的存在服务器上，应用下次打开时显示；也可以恢复成应用自带的。'),
        AsyncView(listing, onRetry: retry, data: _texts),
      ],
      aside: [
        PanelSection(
          first: true,
          title: '搜索',
          child: TextField(
            key: const Key('content-search'),
            controller: _search,
            textInputAction: TextInputAction.search,
            onChanged: (_) => _refind(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: '搜索',
              hintText: '文字，或它的键名',
            ),
          ),
        ),
        PanelSection(
          title: '筛选',
          child: SegmentKeys<bool>(
            child: SegmentedButton<bool>(
              key: const Key('content-filter'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('全部')),
                ButtonSegment(value: true, label: Text('已修改')),
              ],
              selected: {_changedOnly},
              onSelectionChanged: (s) => _refind(() => _changedOnly = s.first),
            ),
          ),
        ),
        AsyncView(listing, onRetry: retry, data: _images),
      ],
    );
  }

  Widget _texts(ContentListing l) {
    final theme = Theme.of(context);
    final tk = ThemeTokens.of(context);
    final matches = _matches(l);
    final shown = matches.take(_shown).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          matches.length == l.texts.length
              ? '共 ${count(l.texts.length)} 条'
              : '找到 ${count(matches.length)} 条，共 ${count(l.texts.length)} 条',
          key: const Key('content-count'),
          style: theme.textTheme.bodySmall?.copyWith(color: tk.textSecondary),
        ),
        const SizedBox(height: Space.s),
        if (shown.isEmpty)
          Text('没有符合的文字', style: theme.textTheme.bodyMedium)
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, t) in shown.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  _TextRow(t, locales: l.locales, onTap: () => _edit(l, t)),
                ],
              ],
            ),
          ),
        if (matches.length > shown.length)
          Align(
            alignment: Alignment.centerLeft,
            child: AppOutlinedButton(
              key: const Key('content-more'),
              onPressed: () => setState(() => _shown += _pageSize),
              child: Text('再显示 ${min(_pageSize, matches.length - shown.length)} 条'),
            ),
          ),
      ],
    );
  }

  Widget _images(ContentListing l) {
    final theme = Theme.of(context);
    final tk = ThemeTokens.of(context);
    final base = ref.watch(adminApiProvider).baseUrl;
    return PanelSection(
      title: '图片',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, image) in l.images.indexed) ...[
            if (i > 0) const SizedBox(height: Space.l),
            Text(image.label, style: theme.textTheme.titleSmall),
            const SizedBox(height: Space.xs),
            if (image.url == null)
              Text(
                '用应用自带的',
                key: ValueKey<String>('image-${image.key}-own'),
                style: theme.textTheme.bodySmall?.copyWith(color: tk.textSecondary),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.field),
                child: Image.network(
                  '$base${image.url}',
                  key: ValueKey<String>('image-${image.key}-shown'),
                  height: _thumbHeight,
                  fit: BoxFit.cover,
                  semanticLabel: image.label,
                  errorBuilder: (_, _, _) => Container(
                    height: _thumbHeight,
                    color: tk.inset,
                    alignment: Alignment.center,
                    child: Icon(Icons.broken_image_outlined, color: tk.textMuted),
                  ),
                ),
              ),
            const SizedBox(height: Space.s),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                AppOutlinedButton.icon(
                  key: ValueKey<String>('image-${image.key}-put'),
                  onPressed: _busyImage == null ? () => _putImage(l, image) : null,
                  icon: const Icon(Icons.upload_outlined),
                  label: Text(image.url == null ? '上传' : '换一张'),
                ),
                if (image.url != null)
                  AppTextButton(
                    key: ValueKey<String>('image-${image.key}-remove'),
                    onPressed: _busyImage == null ? () => _removeImage(image) : null,
                    child: const Text('移除'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: Space.m),
          Text(
            '${_types(l)} 格式，最多 ${fileSize(l.imageMaxBytes)}。应用下次打开时显示。',
            key: const Key('image-limits'),
            style: ReadingText.caption(context)?.copyWith(color: tk.textMuted),
          ),
        ],
      ),
    );
  }
}

/// A text in the list: its wording in each language (the first as its title), its key, and 已修改 where staff changed
/// it. Opens its editor (Enter too).
class _TextRow extends StatelessWidget {
  const _TextRow(this.t, {required this.locales, required this.onTap});
  final ContentText t;
  final List<String> locales;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tk = ThemeTokens.of(context);
    final chevron = Icon(Icons.chevron_right, color: tk.textMuted);
    return ListTile(
      key: ValueKey<String>('text-${t.key}'),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.card, vertical: Space.xs),
      title: Text(t.textIn(locales.first)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final l in locales.skip(1)) Text(t.textIn(l)),
          Text(t.key, style: theme.textTheme.bodySmall?.copyWith(color: tk.textMuted)),
        ],
      ),
      trailing: t.changed.isEmpty
          ? chevron
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Pill('已修改', key: ValueKey<String>('text-${t.key}-changed'), color: tk.accent, icon: Icons.edit_outlined),
                const SizedBox(width: Space.s),
                chevron,
              ],
            ),
    );
  }
}

/// A text's editor: its wording in each language, each with the app's own under it and a button that puts it back,
/// and the placeholders it must keep. 保存 (Ctrl+Enter) keeps what changed; a wording back as the app's own is staff's
/// no longer. Esc or a tap outside asks first while something is unsaved.
class _TextDialog extends ConsumerStatefulWidget {
  const _TextDialog({required this.text, required this.locales});
  final ContentText text;
  final List<String> locales;

  @override
  ConsumerState<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends ConsumerState<_TextDialog> {
  /// What the server has in each language: staff's wording, else the app's own; kept up to date by saves.
  late final Map<String, String> _stored = {for (final l in widget.locales) l: t.textIn(l)};
  late final Map<String, TextEditingController> _fields = {
    for (final l in widget.locales) l: TextEditingController(text: _stored[l]),
  };

  /// What the server refused in a language, until its field changes.
  final _refused = <String, String>{};
  bool _busy = false;

  ContentText get t => widget.text;

  String _want(String l) => _fields[l]!.text.trim();
  bool _edited(String l) => _want(l) != _stored[l];
  bool get _dirty => widget.locales.any(_edited);
  bool get _canSave => !_busy && _dirty && _refused.isEmpty && widget.locales.every((l) => _want(l).isNotEmpty);

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _busy = true);
    final api = ref.read(adminApiProvider);
    try {
      for (final l in widget.locales.where(_edited)) {
        final want = _want(l);
        try {
          // Back as the app's own: staff's wording goes, rather than a copy of it kept.
          if (want == t.defaults[l]) {
            await api.resetText(t.key, l);
          } else {
            await api.saveText(t.key, l, want);
          }
          _stored[l] = want;
        } on AdminApiException catch (e) {
          if (e.code != 'placeholders_mismatch') rethrow;
          _refused[l] = t.placeholders.isEmpty
              ? '这段文字没有 {…} 占位，不能加'
              : '要保留 ${t.placeholders.map((p) => '{$p}').join(' ')}，不能加别的';
        }
      }
      if (mounted && _refused.isEmpty) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) say(context, problemText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tk = ThemeTokens.of(context);
    final caption = theme.textTheme.bodySmall;
    return LeaveGuard(
      active: _dirty,
      kind: LeaveKind.edits,
      message: '这次的修改还没有保存，关掉后不会保留。',
      child: SubmitShortcut(
        onSubmit: _canSave ? _save : null,
        child: AlertDialog(
          title: const Text('修改文字'),
          content: SizedBox(
            width: dialogWidth,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(t.key, key: const Key('text-key'), style: caption?.copyWith(color: tk.textMuted)),
                  if (t.placeholders.isNotEmpty) ...[
                    const SizedBox(height: Space.xs),
                    Text(
                      '要保留：${t.placeholders.map((p) => '{$p}').join(' ')}（应用会换成真实的值）',
                      key: const Key('text-placeholders'),
                      style: caption?.copyWith(color: tk.textSecondary),
                    ),
                  ],
                  for (final l in widget.locales) ...[const SizedBox(height: Space.l), _field(l)],
                ],
              ),
            ),
          ),
          actions: [
            AppTextButton(key: const Key('text-cancel'), onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            AppFilledButton(key: const Key('text-save'), onPressed: _canSave ? _save : null, child: const Text('保存')),
          ],
        ),
      ),
    );
  }

  /// A language's field: Enter moves on (saves in the last), or starts a new line where the app's own has lines.
  Widget _field(String l) {
    final own = t.defaults[l] ?? '';
    final c = _fields[l]!;
    final asOwn = _want(l) == own;
    final lines = own.contains('\n');
    final last = l == widget.locales.last;
    // A refusal holds until the words change (not the cursor).
    void changed() => setState(() => _refused.remove(l));
    return TextField(
      key: ValueKey<String>('text-$l'),
      controller: c,
      onChanged: (_) => changed(),
      autofocus: l == widget.locales.first,
      minLines: 1,
      maxLines: 6,
      keyboardType: lines ? TextInputType.multiline : TextInputType.text,
      textInputAction: lines ? TextInputAction.newline : (last ? TextInputAction.done : TextInputAction.next),
      onSubmitted: last && !lines ? (_) => _save() : null,
      decoration: InputDecoration(
        labelText: localeName(l),
        helperText: asOwn ? '应用自带的' : '应用自带：$own',
        helperMaxLines: 4,
        errorText: _want(l).isEmpty ? '不能为空' : _refused[l],
        errorMaxLines: 3,
        suffixIcon: asOwn
            ? null
            : AppIconButton(
                key: ValueKey<String>('text-$l-own'),
                tooltip: '恢复成应用自带的',
                onPressed: () {
                  c.text = own;
                  changed();
                },
                icon: const Icon(Icons.restore),
              ),
      ),
    );
  }
}
