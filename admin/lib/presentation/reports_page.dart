import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mingli_app/presentation/buttons.dart';
import 'package:mingli_app/presentation/design.dart';

import '../application/providers.dart';
import 'messages.dart';
import 'widgets/common.dart';

/// 导出 (管理后台, tech plan S22): the period's report as PDF or Word, the revenue curve's numbers and the accounts as
/// CSV. The server makes each file; the browser downloads it.
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  /// The export being made (its button's key), so only one runs at a time.
  String? _running;

  Future<void> _export(String what, {required String format, String kind = 'series'}) async {
    if (_running != null) return;
    setState(() => _running = what);
    try {
      final f = await ref.read(adminApiProvider).report(days: ref.read(daysProvider), format: format, kind: kind);
      await ref.read(saveFileProvider)(f);
      if (mounted) say(context, '已导出 ${f.name}');
    } catch (e) {
      if (mounted) say(context, problemText(e));
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  Widget _button(String what, String label, IconData icon, {required String format, String kind = 'series'}) =>
      AppFilledButton.tonalIcon(
        key: Key('export-$what'),
        onPressed: _running == null ? () => _export(what, format: format, kind: kind) : null,
        icon: _running == what
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon),
        label: Text(label),
      );

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyMedium;
    return PageBody(
      children: [
        const PageHeader('导出', subtitle: '所选时间段的数字，按北京时间', trailing: PeriodPicker()),
        AppCard(
          title: '经营报表',
          icon: Icons.description_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('经营概况、账户与活跃、AI 用量、积分，按测算和按模型的用量，以及每日明细。', style: body),
              const SizedBox(height: Space.m),
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  _button('pdf', '报表（PDF）', Icons.picture_as_pdf_outlined, format: 'pdf'),
                  _button('docx', '报表（Word）', Icons.article_outlined, format: 'docx'),
                ],
              ),
            ],
          ),
        ),
        AppCard(
          title: '数据',
          icon: Icons.table_view_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('收益曲线是所选时间段每天一行；用户列表是所有账户，全部时间的数字。CSV 可以用 Excel 或 WPS 打开。', style: body),
              const SizedBox(height: Space.m),
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  _button('series', '收益曲线（CSV）', Icons.show_chart, format: 'csv'),
                  _button('users', '用户列表（CSV）', Icons.people_outline, format: 'csv', kind: 'users'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
