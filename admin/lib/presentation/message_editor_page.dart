import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mingli_app/presentation/buttons.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/keyboard.dart';
import 'package:mingli_app/presentation/layout.dart';
import 'package:mingli_app/presentation/tokens.dart';

import '../application/providers.dart';
import '../data/admin_api.dart';
import '../domain/models.dart';
import '../platform/mail_frame.dart';
import 'format.dart';
import 'messages.dart';
import 'messages_page.dart';
import 'widgets/common.dart';
import 'widgets/dashboard.dart';

/// Opens [t]'s editor.
void openMessage(BuildContext context, MessageTemplate t) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MessageEditorPage(template: t)));

/// How long after the last keystroke the preview is made again.
const previewDelay = Duration(milliseconds: 400);

/// The mail page's height in the preview: about a phone's screen.
const _frameHeight = 640.0;

/// A dialog's width (the ui-design skill: 520 to 640).
const _dialogWidth = 520.0;

/// A draft, as the preview was asked for it: the language, the dashboard's light or dark, the subject and the body.
typedef _Draft = ({String locale, String scheme, String subject, String body});

/// A message's editor (消息, tech plan S25): one language at a time, its subject (a mail's) and its body in the
/// markup, the values as chips that go in where the cursor is; 保存 (Ctrl+Enter), 撤销修改, 恢复默认 and 发送测试.
/// The panel shows what a reader gets, with sample values, made again a moment after each edit, light or dark as the
/// dashboard is (外观): a mail's own page (its text off the web), an SMS's text, length and parts. Unsaved edits are
/// asked about on leaving.
class MessageEditorPage extends ConsumerStatefulWidget {
  const MessageEditorPage({super.key, required this.template});
  final MessageTemplate template;

  @override
  ConsumerState<MessageEditorPage> createState() => _MessageEditorPageState();
}

class _MessageEditorPageState extends ConsumerState<MessageEditorPage> {
  /// Each language's wording as the server has it, kept up to date by saves and resets.
  late final Map<String, TemplateWording> _wordings = {for (final w in widget.template.locales) w.locale: w};
  late String _locale = widget.template.locales.first.locale;

  final _subject = TextEditingController();
  final _body = TextEditingController();
  final _subjectFocus = FocusNode(debugLabel: 'subject');
  final _bodyFocus = FocusNode(debugLabel: 'body');

  /// Where a value's chip puts it: the field that had the focus last (the body until the subject has had it).
  bool _intoSubject = false;
  bool _busy = false;

  /// What the server refused a save for, until the next edit.
  List<String> _refused = const [];

  /// The dashboard's light or dark (from the theme), as the preview is asked for it.
  String _scheme = 'light';

  MessagePreview? _preview;
  Object? _previewError;

  /// The draft [_preview] shows, and the one asked for last: another is on its way while they differ.
  _Draft? _shown;
  _Draft? _asked;
  Timer? _debounce;

  MessageTemplate get t => widget.template;
  TemplateWording get _saved => _wordings[_locale]!;

  _Draft get _draft => (locale: _locale, scheme: _scheme, subject: _subject.text, body: _body.text);

  bool get _dirty => _body.text != _saved.body || (t.mail && _subject.text != (_saved.subject ?? ''));

  /// The latest preview is of what the fields hold now.
  bool get _current => _shown != null && _shown == _draft;

  /// Something to save, nothing known to be wrong with it.
  bool get _canSave => !_busy && _dirty && _refused.isEmpty && !(_current && _preview!.problems.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _fill(_saved);
    _subject.addListener(_edited);
    _body.addListener(_edited);
    _subjectFocus.addListener(() {
      if (_subjectFocus.hasFocus) _intoSubject = true;
    });
    _bodyFocus.addListener(() {
      if (_bodyFocus.hasFocus) _intoSubject = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The first preview; another when 外观 turns the dashboard light or dark (half-way through its fade).
    final scheme = ThemeTokens.of(context).darkness >= 0.5 ? 'dark' : 'light';
    if (scheme != _scheme || _asked == null) {
      _scheme = scheme;
      _schedule(now: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subject.dispose();
    _body.dispose();
    _subjectFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _fill(TemplateWording w) {
    _subject.text = w.subject ?? '';
    _body.text = w.body;
  }

  /// A field changed, or only its cursor: the buttons follow the text at once, the preview a moment later.
  void _edited() {
    if (_draft == _asked) return;
    setState(() => _refused = const []);
    _schedule();
  }

  void _schedule({bool now = false}) {
    _debounce?.cancel();
    if (now) {
      _ask();
    } else {
      _debounce = Timer(previewDelay, _ask);
    }
  }

  Future<void> _ask() async {
    if (!mounted) return;
    final asked = _draft;
    _asked = asked;
    try {
      final p = await ref
          .read(adminApiProvider)
          .preview(t.kind, asked.locale, subject: t.mail ? asked.subject : null, body: asked.body, scheme: asked.scheme);
      // An answer for an older draft is dropped: a newer one is on its way.
      if (!mounted || _asked != asked) return;
      setState(() {
        _preview = p;
        _shown = asked;
        _previewError = null;
      });
    } catch (e) {
      if (!mounted || _asked != asked) return;
      setState(() => _previewError = e);
    }
  }

  /// [v] where the cursor is (or for the whole selection) in the field focused last, and the cursor after it; a part
  /// ({{report}}) on a line of its own, in the body.
  void _insert(TemplateVariable v) {
    final intoSubject = _intoSubject && t.mail && !v.part;
    final c = intoSubject ? _subject : _body;
    final text = c.text;
    final sel = c.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    var token = '{{${v.name}}}';
    if (v.part) {
      if (start > 0 && text[start - 1] != '\n') token = '\n$token';
      if (end >= text.length || text[end] != '\n') token = '$token\n';
    }
    c.value = TextEditingValue(
      text: text.replaceRange(start, end, token),
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    (intoSubject ? _subjectFocus : _bodyFocus).requestFocus();
  }

  Future<void> _switchTo(String locale) async {
    if (locale == _locale || _busy) return;
    if (_dirty &&
        !await confirmLeave(
          context,
          kind: LeaveKind.edits,
          message: '换到${localeName(locale)}后，${localeName(_locale)}这次的修改不会保存。',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _locale = locale;
      _refused = const [];
      _preview = null;
      _shown = null;
    });
    _fill(_saved);
    _schedule(now: true);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final locale = _locale;
    setState(() => _busy = true);
    try {
      final w = await ref
          .read(adminApiProvider)
          .saveTemplate(t.kind, locale, subject: t.mail ? _subject.text : null, body: _body.text);
      if (!mounted) return;
      setState(() => _wordings[locale] = w);
      ref.invalidate(messagesProvider);
      say(context, '已保存${localeName(locale)}的内容');
    } on AdminApiException catch (e) {
      if (!mounted) return;
      setState(() => _refused = e.problems);
      say(context, problemText(e));
    } catch (e) {
      if (mounted) say(context, problemText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The fields back to what is saved.
  void _revert() {
    _fill(_saved);
    _schedule(now: true);
  }

  /// The language back to its default wording, asked first.
  Future<void> _reset() async {
    if (_busy || !_saved.custom) return;
    final locale = _locale;
    if (!await confirmAction(context, '恢复${localeName(locale)}的默认内容？', '改过的内容会删掉，以后发出的${channelNames[t.channel]}用默认内容。')) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final w = await ref.read(adminApiProvider).resetTemplate(t.kind, locale);
      if (!mounted) return;
      setState(() => _wordings[locale] = w);
      if (_locale == locale) _revert();
      ref.invalidate(messagesProvider);
      say(context, '已恢复${localeName(locale)}的默认内容');
    } catch (e) {
      if (mounted) say(context, problemText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A test send with the sample values: the draft when there is one, else the saved wording.
  Future<void> _test() async {
    if (_busy) return;
    final draft = _dirty;
    final to = await showDialog<String>(context: context, builder: (_) => _TestDialog(mail: t.mail, draft: draft));
    if (to == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final e = await ref.read(adminApiProvider).testSend(
            t.kind,
            _locale,
            to,
            subject: draft && t.mail ? _subject.text : null,
            body: draft ? _body.text : null,
          );
      ref.invalidate(dispatchLogProvider);
      if (mounted) {
        final where = e.transport == 'outbox' ? '（写进了服务器的发件箱）' : '';
        say(context, '测试${channelNames[t.channel]}已发到 ${e.to}$where');
      }
    } catch (e) {
      if (mounted) say(context, problemText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LeaveGuard(
        active: _dirty,
        kind: LeaveKind.edits,
        message: '${localeName(_locale)}这次的修改还没有保存，返回后不会保留。',
        child: SubmitShortcut(
          onSubmit: _canSave ? _save : null,
          child: Scaffold(
            appBar: AppBar(title: Text(t.name)),
            body: DashboardLayout(
              panelWidth: t.mail ? asideWide : asideWidth,
              main: [_editor()],
              aside: [_previewPanel(), const DispatchLog()],
            ),
          ),
        ),
      );

  Widget _editor() {
    final theme = Theme.of(context);
    final tk = ThemeTokens.of(context);
    final problems = _refused.isNotEmpty ? _refused : (_preview?.problems ?? const <String>[]);
    final saved = _saved;
    final phone = WindowClass.ofContext(context) == WindowClass.compact;
    final save = AppFilledButton(
      key: const Key('template-save'),
      onPressed: _canSave ? _save : null,
      child: const Text('保存'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.about, style: theme.textTheme.bodyMedium?.copyWith(color: tk.textSecondary)),
        const SizedBox(height: Space.l),
        if (t.locales.length > 1) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentKeys<String>(
              child: SegmentedButton<String>(
                key: const Key('locale'),
                showSelectedIcon: false,
                segments: [
                  for (final w in t.locales) ButtonSegment(value: w.locale, label: Text(localeName(w.locale))),
                ],
                selected: {_locale},
                onSelectionChanged: (s) => _switchTo(s.first),
              ),
            ),
          ),
          const SizedBox(height: Space.s),
        ],
        Text(
          saved.custom
              ? '${localeName(_locale)}：已修改${saved.updatedAt == null ? '' : '（${localTime(saved.updatedAt!)}）'}'
              : '${localeName(_locale)}：默认内容',
          key: const Key('wording-state'),
          style: theme.textTheme.bodySmall?.copyWith(color: saved.custom ? tk.accent : tk.textMuted),
        ),
        const SizedBox(height: Space.l),
        if (t.mail) ...[
          TextField(
            key: const Key('template-subject'),
            controller: _subject,
            focusNode: _subjectFocus,
            // The cursor stays where it was when the focus comes back (a value's chip), rather than all selected.
            selectAllOnFocus: false,
            maxLength: 200,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _bodyFocus.requestFocus(),
            decoration: const InputDecoration(labelText: '标题'),
          ),
          const SizedBox(height: Space.s),
        ],
        Text('可用的值（点一下放到光标处）', style: theme.textTheme.labelLarge?.copyWith(color: tk.textSecondary)),
        const SizedBox(height: Space.s),
        // With the fields: a click on a chip leaves the field focused, its cursor where it was.
        TextFieldTapRegion(
          child: Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            for (final v in t.variables)
              ActionChip(
                key: ValueKey<String>('var-${v.name}'),
                avatar: v.part ? const Icon(Icons.segment) : null,
                label: Text('{{${v.name}}}'),
                tooltip: '${v.about}${v.part ? '（单独一行，只能放在正文里）' : ''}'
                    '${t.required.contains(v.name) ? '；必须用到' : ''}',
                onPressed: () => _insert(v),
              ),
          ],
          ),
        ),
        const SizedBox(height: Space.l),
        TextField(
          key: const Key('template-body'),
          controller: _body,
          focusNode: _bodyFocus,
          minLines: t.mail ? 12 : 4,
          maxLines: null,
          maxLength: t.mail ? 10000 : 500,
          keyboardType: TextInputType.multiline,
          style: ReadingText.small(context),
          decoration: InputDecoration(labelText: '正文', alignLabelWithHint: true, helperText: t.mail ? '写法见下面' : null),
        ),
        if (problems.isNotEmpty) ...[
          const SizedBox(height: Space.s),
          _Problems(problems),
        ],
        const SizedBox(height: Space.l),
        // The main button last; on a phone it spans the column under the others (the ui-design skill's alignment).
        Wrap(
          alignment: WrapAlignment.end,
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            AppTextButton(
              key: const Key('template-revert'),
              onPressed: _busy || !_dirty ? null : _revert,
              child: const Text('撤销修改'),
            ),
            AppOutlinedButton(
              key: const Key('template-reset'),
              onPressed: _busy || !saved.custom ? null : _reset,
              child: const Text('恢复默认'),
            ),
            AppOutlinedButton.icon(
              key: const Key('template-test'),
              onPressed: _busy ? null : _test,
              icon: const Icon(Icons.send_outlined),
              label: const Text('发送测试'),
            ),
            if (!phone) save,
          ],
        ),
        if (phone) ...[const SizedBox(height: Space.m), SizedBox(width: double.infinity, child: save)],
        if (t.mail) ...[const SizedBox(height: Space.xl), const _MarkupHelp()],
      ],
    );
  }

  Widget _previewPanel() {
    final theme = Theme.of(context);
    final tk = ThemeTokens.of(context);
    final p = _preview;
    final Widget body;
    if (p == null) {
      body = _previewError != null
          ? Problem(problemText(_previewError!), onRetry: () => _schedule(now: true))
          : const Padding(
              padding: EdgeInsets.all(Space.xl),
              child: Center(child: CircularProgressIndicator()),
            );
    } else if (t.mail) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('标题', style: theme.textTheme.labelMedium?.copyWith(color: tk.textMuted)),
          const SizedBox(height: Space.xxs),
          Text(p.subject ?? '', key: const Key('preview-subject'), style: theme.textTheme.titleSmall),
          const SizedBox(height: Space.m),
          MailFrame(html: p.html ?? '', text: p.text, height: _frameHeight),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(Space.l),
            decoration: BoxDecoration(
              color: tk.inset,
              borderRadius: BorderRadius.circular(Radii.field),
              border: Border.all(color: tk.border),
            ),
            child: SelectableText(p.text, key: const Key('preview-sms'), style: ReadingText.small(context)),
          ),
          const SizedBox(height: Space.s),
          Text(
            '${p.length ?? 0} 个字 · ${p.segments ?? 0} 条短信',
            key: const Key('preview-segments'),
            style: theme.textTheme.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: Space.xxs),
          Text('含中文时一条 70 个字，超出后每条 67 个字。', style: ReadingText.caption(context)?.copyWith(color: tk.textMuted)),
        ],
      );
    }
    return PanelSection(
      first: true,
      title: '预览',
      trailing: _current || p == null
          ? null
          : SizedBox.square(
              key: const Key('preview-busy'),
              dimension: Space.l,
              child: CircularProgressIndicator(strokeWidth: 2, color: tk.textMuted),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          body,
          const SizedBox(height: Space.s),
          Text(
            t.mail ? '用示例数据。预览跟随管理后台的外观（浅色或深色）；发出的邮件跟随收件人的系统。' : '用示例数据。',
            style: ReadingText.caption(context)?.copyWith(color: tk.textMuted),
          ),
        ],
      ),
    );
  }
}

/// What is wrong with the wording, one line each, the error's colour with its icon.
class _Problems extends StatelessWidget {
  const _Problems(this.problems);
  final List<String> problems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = ThemeTokens.of(context).danger;
    final style = theme.textTheme.bodyMedium?.copyWith(color: colour);
    const size = Space.l;
    return Column(
      key: const Key('template-problems'),
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
                  child: Icon(Icons.error_outline, size: size, color: colour),
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

/// The body's markup, in a list that opens.
class _MarkupHelp extends StatelessWidget {
  const _MarkupHelp();

  static const _rows = [
    ('# 文字', '大标题（一封邮件一个）'),
    ('## 文字', '小标题'),
    ('空一行', '分段'),
    ('> 文字', '浅色底的说明'),
    ('!! 文字', '醒目的一行，比如验证码'),
    ('- 文字', '列表的一项'),
    ('---', '分隔线'),
    ('{{名字}}', '发送时换成真实的值'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tk = ThemeTokens.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        key: const Key('markup-help'),
        title: Text('正文的写法', style: theme.textTheme.titleSmall),
        childrenPadding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.l),
        shape: const Border(),
        collapsedShape: const Border(),
        children: [
          for (final (mark, what) in _rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _markWidth,
                    child: Text(mark, style: theme.textTheme.labelLarge?.copyWith(color: tk.accent)),
                  ),
                  Expanded(child: Text(what, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The width of the markup column in the help.
const _markWidth = 96.0;

/// Where a test goes: an address or a number. Enter sends, Esc cancels.
class _TestDialog extends StatefulWidget {
  const _TestDialog({required this.mail, required this.draft});
  final bool mail;
  final bool draft;

  @override
  State<_TestDialog> createState() => _TestDialogState();
}

class _TestDialogState extends State<_TestDialog> {
  final _to = TextEditingController();

  @override
  void dispose() {
    _to.dispose();
    super.dispose();
  }

  void _send() {
    final to = _to.text.trim();
    if (to.isNotEmpty) Navigator.pop(context, to);
  }

  @override
  Widget build(BuildContext context) => SubmitShortcut(
        onSubmit: _send,
        child: AlertDialog(
          title: Text(widget.mail ? '发送测试邮件' : '发送测试短信'),
          content: SizedBox(
            width: _dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '用示例数据发送${widget.draft ? '这份还没保存的内容' : '保存的内容'}。'
                  '现在不经第三方服务：消息写进服务器的发件箱。',
                ),
                const SizedBox(height: Space.l),
                TextField(
                  key: const Key('test-to'),
                  controller: _to,
                  autofocus: true,
                  keyboardType: widget.mail ? TextInputType.emailAddress : TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    labelText: widget.mail ? '邮箱' : '手机号',
                    hintText: widget.mail ? 'name@example.com' : '+86 138 0013 8000',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            AppTextButton(key: const Key('test-cancel'), onPressed: () => Navigator.pop(context), child: const Text('取消')),
            AppFilledButton(key: const Key('test-send'), onPressed: _send, child: const Text('发送')),
          ],
        ),
      );
}
