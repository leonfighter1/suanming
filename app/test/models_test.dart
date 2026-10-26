import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/domain/models.dart';

import 'support.dart';

void main() {
  test('parses a real bazi ChartFact', () {
    final chart = ChartResult.fromJson(fixture('chart_bazi'));
    expect(chart.system, 'bazi');
    final b = chart.bazi;
    expect(b.fourPillars, '庚午 己卯 己卯 辛未');
    expect(b.dayMasterGan, '己');
    expect(b.wuxingWeighted['土'], 2.9);
    expect(b.dayunForward, isTrue);
    expect(b.liunian.first.year, 2026);
    expect(b.liunian.first.ganzhi, '丙午');
    expect(b.liunian.first.relations.single.type, '六合');
  });

  test('parses a real tarot ChartFact', () {
    final t = ChartResult.fromJson(fixture('chart_tarot')).tarot;
    expect(t.spreadId, 'three_card');
    expect(t.cards.map((c) => c.positionKey), ['past', 'present', 'future']);
    expect(t.drawId, '00000000-0000-4000-8000-000000000001');
  });

  test('parses a passed report view with four layers', () {
    final r = ReportView.fromJson(fixture('report_passed'));
    expect(r.status, 'passed');
    expect(r.isTerminal, isTrue);
    expect(r.layers!.facts.first, '四柱：庚午 己卯 己卯 辛未');
    expect(r.layers!.interpretation.map((s) => s.topic), r.topics);
    expect(r.layers!.expectation.labelRequired, isFalse);
  });

  test('pending reports are not terminal', () {
    final r = ReportView.fromJson({...fixture('report_passed'), 'status': 'pending', 'layers': null});
    expect(r.isTerminal, isFalse);
    expect(r.layers, isNull);
  });
}
