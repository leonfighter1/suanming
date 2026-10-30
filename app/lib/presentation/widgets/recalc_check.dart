import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers.dart';
import '../../domain/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../labels.dart';
import '../life_report_page.dart';
import '../report_page.dart';
import 'remedy.dart' show compactButtons;

/// 有所求才能去求 (owner, v11.1.0): calls [onAsking] each time [question] starts or stops holding something asked (S28:
/// 塔罗, 求签 and 算卦 each had this listener).
void watchQuestion(TextEditingController question, void Function(bool asking) onAsking) {
  var asking = question.text.trim().isNotEmpty;
  question.addListener(() {
    final now = question.text.trim().isNotEmpty;
    if (now != asking) {
      asking = now;
      onAsking(now);
    }
  });
}

/// A finished 测算 a new one would repeat (v10.0.0): its record, when it was made, and what it was asked.
class EarlierReading {
  const EarlierReading({required this.id, required this.at, this.question, this.life = false});
  final String id;
  final DateTime at;
  final String? question;

  /// A 一生运势报告 (opened on its own page), not a reading.
  final bool life;
}

/// The same question twice, whatever its spacing and punctuation.
String _norm(String? s) => (s ?? '').replaceAll(RegExp(r'[\s\p{P}]', unicode: true), '');

/// 同名重算 (v10.0.0, S19 WP19.4; the owner: 对于已经算完的卦，对于同一人名的人要提问说之前已经算过，是否还要重新再算一次): the person's
/// newest finished reading of [system] in [history] (newest first). A 八字 chart is the person's whatever was asked; a
/// 卦 (塔罗, 求签, 算卦, 风水) answers the question it was cast for, so it counts only for the same question, and a new
/// one without a question repeats nothing.
HistoryItem? earlierReading(List<HistoryItem> history, {required String system, required String? name, String? question}) {
  final who = name?.trim() ?? '';
  if (who.isEmpty) return null;
  final asked = _norm(question);
  if (system != 'bazi' && asked.isEmpty) return null;
  return history
      .where((h) => h.status == 'passed' && h.system == system && (h.person?.name?.trim() ?? '') == who)
      .where((h) => system == 'bazi' || _norm(h.question) == asked)
      .firstOrNull;
}

/// Before a new 测算 (v10.0.0): when [name] has a finished one of [system] (`life` for the 一生运势报告), asks
/// 之前已经算过，是否还要重新再算一次 with 查看之前的 and 重新再算. True: go on and 测算 again. False: the earlier one was opened
/// instead, or the dialog was closed. When the records can't be read, it goes on as before.
Future<bool> confirmRecalc(
  BuildContext context,
  WidgetRef ref, {
  required String system,
  required String? name,
  String? question,
}) async {
  final who = name?.trim() ?? '';
  // Nobody named, or a 卦 without a question: nothing a new one could repeat, so no need to look.
  if (who.isEmpty || (system != 'bazi' && system != 'life' && _norm(question).isEmpty)) return true;
  final api = ref.read(apiClientProvider);
  EarlierReading? earlier;
  try {
    if (system == 'life') {
      final life = (await api.listLifeReports())
          .where((r) => r.status == 'passed' && (r.person?.name?.trim() ?? '') == who)
          .firstOrNull;
      if (life != null) earlier = EarlierReading(id: life.id, at: life.createdAt ?? DateTime.now(), life: true);
    } else {
      final h = earlierReading(await api.listReports(limit: 100), system: system, name: who, question: question);
      if (h != null) earlier = EarlierReading(id: h.reportId, at: h.createdAt, question: h.question);
    }
  } catch (_) {
    return true;
  }
  if (earlier == null || !context.mounted) return true;
  final l10n = AppLocalizations.of(context);
  final date = DateFormat('yyyy-MM-dd').format(earlier.at.toLocal());
  final method = l10n.methodLabel(system);
  final asked = earlier.question?.trim() ?? '';
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => compactButtons(
      ctx,
      AlertDialog(
        key: const Key('recalc-dialog'),
        title: Text(l10n.recalcTitle),
        content: Text(
          system != 'bazi' && system != 'life' && asked.isNotEmpty
              ? l10n.recalcBodyQuestion(who, date, method, asked)
              : l10n.recalcBody(who, date, method),
        ),
        actions: [
          TextButton(key: const Key('recalc-view'), onPressed: () => Navigator.of(ctx).pop('view'), child: Text(l10n.recalcView)),
          FilledButton(key: const Key('recalc-again'), onPressed: () => Navigator.of(ctx).pop('again'), child: Text(l10n.recalcAgain)),
        ],
      ),
    ),
  );
  if (choice == 'again') return true;
  if (choice == 'view' && context.mounted) {
    final id = earlier.id;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => earlier!.life ? LifeReportPage(reportId: id) : ReportPage(reportId: id)),
    );
  }
  return false;
}
