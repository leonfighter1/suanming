import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models.dart';
import '../format.dart';
import 'common.dart';
import 'line_chart.dart';

// The charts and tables more than one page shows (管理后台, tech plan S22).

final _axisYuan = NumberFormat('#,##0');

/// 充值, AI 成本 and 毛利 per day; [cumulative] adds them up from the period's first day.
class RevenueChart extends StatelessWidget {
  const RevenueChart(this.days, {super.key, this.cumulative = false, this.repaintKey});
  final List<DayRow> days;
  final bool cumulative;
  final GlobalKey? repaintKey;

  @override
  Widget build(BuildContext context) {
    final colors = seriesColors(context);
    List<double> line(double Function(DayRow d) of) {
      var sum = 0.0;
      return [for (final d in days) cumulative ? sum += of(d) : of(d)];
    }

    return LineChart(
      labels: [for (final d in days) d.day],
      series: [
        ChartSeries('充值', colors[0], line((d) => d.money.topup)),
        ChartSeries('AI 成本', colors[1], line((d) => d.money.cost)),
        ChartSeries('毛利', colors[2], line((d) => d.money.profit)),
      ],
      format: (v) => v < 0 ? '-¥${_axisYuan.format(-v)}' : '¥${_axisYuan.format(v)}',
      readout: yuan,
      repaintKey: repaintKey,
    );
  }
}

/// What each kind of AI job cost and earned: 八字 AI 解读, 塔罗 追问, 一生运势报告 …
class MethodTable extends StatelessWidget {
  const MethodTable(this.rows, {super.key});
  final List<MethodRow> rows;

  @override
  Widget build(BuildContext context) => DataGrid(
        label: '各项目',
        empty: '这段时间没有 AI 请求',
        columns: const [
          DataColumn(label: Text('项目')),
          DataColumn(label: Text('AI 次数'), numeric: true),
          DataColumn(label: Text('Tokens'), numeric: true),
          DataColumn(label: Text('AI 成本'), numeric: true),
          DataColumn(label: Text('消耗积分'), numeric: true),
        ],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                DataCell(Text(whatOf(r.kind, r.system))),
                DataCell(numText(count(r.jobs))),
                DataCell(numText(compact(r.tokens))),
                DataCell(numText(yuan(r.cost))),
                DataCell(numText(count(r.pointsUsed))),
              ],
            ),
        ],
      );
}
