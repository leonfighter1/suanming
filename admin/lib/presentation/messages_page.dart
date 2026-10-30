import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/layout.dart';
import 'package:mingli_app/presentation/tokens.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import 'format.dart';
import 'message_editor_page.dart';
import 'widgets/common.dart';
import 'widgets/dashboard.dart';

/// 消息 (tech plan S25; the owner: 设计好邮件发送逻辑，让后台用户可以编辑各类发送邮件的前端页面。同时还有SMS等等): every mail and
/// SMS the server sends, by channel, each language marked once an admin's wording replaced its default; a message opens
/// its editor. In the panel: how each channel leaves this server (the dev outbox: no provider yet) and the latest
/// dispatches.
class MessagesPage extends ConsumerWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing = ref.watch(messagesProvider);
    void retry() => ref.invalidate(messagesProvider);
    return DashboardLayout(
      main: [
        const PageHeader('消息', subtitle: '服务器发出的邮件和短信。每种语言一份内容，可以修改，也可以恢复默认。'),
        AsyncView(listing, onRetry: retry, data: (l) => _Channels(l)),
      ],
      aside: [
        AsyncView(listing, onRetry: retry, data: (l) => _Delivery(l)),
        const DispatchLog(),
      ],
    );
  }
}

/// The messages under their channel's name: mail, then SMS.
class _Channels extends StatelessWidget {
  const _Channels(this.listing);
  final MessageListing listing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, (channel, icon)) in const [('mail', Icons.mail_outline), ('sms', Icons.sms_outlined)].indexed) ...[
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : Space.l, bottom: Space.m),
            child: Semantics(header: true, child: Text(channelNames[channel]!, style: theme.textTheme.titleLarge)),
          ),
          _CardRows([
            for (final t in listing.templates.where((t) => t.channel == channel)) _MessageCard(t, icon: icon),
          ]),
        ],
      ],
    );
  }
}

/// [cards] two to a row once the column is a reading column wide (one below), each row as tall as its tallest card.
class _CardRows extends StatelessWidget {
  const _CardRows(this.cards);
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final columns = box.maxWidth >= Grid.reading ? 2 : 1;
          final gutter = WindowClass.ofContext(context).gutter;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i += columns)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var c = 0; c < columns; c++) ...[
                        if (c > 0) SizedBox(width: gutter),
                        Expanded(child: i + c < cards.length ? cards[i + c] : const SizedBox.shrink()),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      );
}

/// A message: its name, when it goes out, and its languages (已修改 where an admin's wording is in use). Opens its
/// editor (Enter too).
class _MessageCard extends StatelessWidget {
  const _MessageCard(this.t, {required this.icon});
  final MessageTemplate t;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ThemeTokens.of(context);
    return AppCard(
      key: ValueKey<String>('message-${t.kind}'),
      title: t.name,
      icon: icon,
      trailing: Icon(Icons.chevron_right, color: tokens.textMuted),
      onTap: () => openMessage(context, t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.about, style: theme.textTheme.bodyMedium?.copyWith(color: tokens.textSecondary)),
          const SizedBox(height: Space.m),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              for (final w in t.locales)
                Pill(
                  w.custom ? '${localeName(w.locale)} · 已修改' : localeName(w.locale),
                  key: ValueKey<String>('message-${t.kind}-${w.locale}'),
                  color: w.custom ? tokens.accent : tokens.textMuted,
                  icon: w.custom ? Icons.edit_outlined : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// How each channel leaves this server.
class _Delivery extends StatelessWidget {
  const _Delivery(this.listing);
  final MessageListing listing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = ThemeTokens.of(context);
    Widget row(String channel, String transport) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(channelNames[channel]!, style: theme.textTheme.titleSmall),
              const SizedBox(height: Space.xxs),
              Text(
                deliveryOf(transport),
                key: ValueKey<String>('delivery-$channel'),
                style: theme.textTheme.bodySmall?.copyWith(color: t.textSecondary),
              ),
            ],
          ),
        );
    return PanelSection(
      first: true,
      title: '发送方式',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row('mail', listing.mail),
          row('sms', listing.sms),
          const SizedBox(height: Space.xs),
          Text('第三方邮件和短信服务以后再接入。', style: ReadingText.caption(context)?.copyWith(color: t.textMuted)),
        ],
      ),
    );
  }
}

/// 最近发送: the latest dispatches, the newest first; who each went to is masked, a code never shown.
class DispatchLog extends ConsumerWidget {
  const DispatchLog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(dispatchLogProvider);
    return PanelSection(
      title: '最近发送',
      trailing: IconButton(
        key: const Key('log-refresh'),
        tooltip: '刷新最近发送',
        visualDensity: VisualDensity.compact,
        onPressed: () => ref.invalidate(dispatchLogProvider),
        icon: const Icon(Icons.refresh),
      ),
      child: AsyncView(
        log,
        onRetry: () => ref.invalidate(dispatchLogProvider),
        data: (items) => items.isEmpty
            ? Text('还没有发送记录', style: Theme.of(context).textTheme.bodyMedium)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final e in items.take(20)) _LogRow(e)],
              ),
      ),
    );
  }
}

class _LogRow extends ConsumerWidget {
  const _LogRow(this.e);
  final DispatchEntry e;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ThemeTokens.of(context);
    final now = ref.watch(clockProvider)();
    final name = ref.watch(messagesProvider).value?.byKind(e.kind)?.name ?? e.kind;
    final (colour, icon) = switch (e.status) {
      'sent' => (t.success, Icons.check_circle_outline),
      'off' => (t.textMuted, Icons.do_not_disturb_on_outlined),
      _ => (t.danger, Icons.error_outline),
    };
    final style = theme.textTheme.bodyMedium;
    final size = IconTheme.of(context).size ?? Space.xl;
    return Padding(
      key: ValueKey<String>('log-${e.id}'),
      padding: const EdgeInsets.symmetric(vertical: Space.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: firstLineInset(style, size)),
            child: Icon(e.channel == 'mail' ? Icons.mail_outline : Icons.sms_outlined, color: t.textSecondary),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('$name${e.test ? '（测试）' : ''}', style: style),
                Text(
                  '${e.to} · ${localeName(e.locale)}${e.custom ? ' · 已修改的内容' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: Space.xxs),
                Wrap(
                  spacing: Space.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Pill(dispatchStatus(e.status), color: colour, icon: icon),
                    Text(ago(e.at, now), style: theme.textTheme.bodySmall?.copyWith(color: t.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
