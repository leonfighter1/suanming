// Client-side views of the v1 API contract (api/openapi.yaml, ChartFact v0.1).
// Parsing is tolerant of extra fields: the contract is additive-only.

import 'qiuqian.dart';

export 'qiuqian.dart';

typedef Json = Map<String, dynamic>;

List<T> _list<T>(Object? v, T Function(Json) f) =>
    ((v as List?) ?? const []).cast<Json>().map(f).toList();

class Pillar {
  const Pillar({
    required this.gan,
    required this.zhi,
    required this.hiddenGan,
    required this.shishenGan,
    required this.shishenZhi,
    required this.dishi,
    required this.nayin,
  });

  factory Pillar.fromJson(Json j) => Pillar(
        gan: j['gan'] as String,
        zhi: j['zhi'] as String,
        hiddenGan: (j['hidden_gan'] as List).cast<String>(),
        shishenGan: j['shishen_gan'] as String,
        shishenZhi: (j['shishen_zhi'] as List).cast<String>(),
        dishi: j['dishi'] as String,
        nayin: j['nayin'] as String,
      );

  final String gan;
  final String zhi;
  final List<String> hiddenGan;
  final String shishenGan;
  final List<String> shishenZhi;
  final String dishi;
  final String nayin;

  String get ganzhi => gan + zhi;
}

class DayunCycle {
  const DayunCycle(this.index, this.ganzhi, this.startYear, this.startAge, this.xusui);
  factory DayunCycle.fromJson(Json j) => DayunCycle(
        j['index'] as int,
        j['ganzhi'] as String,
        j['start_year'] as int,
        j['start_age'] as int,
        (j['start_age_xu'] ?? j['start_age']) as int,
      );
  final int index;
  final String ganzhi;
  final int startYear;
  final int startAge;

  /// 虚岁 at the start, from the civil birth year (the count 流年 [Liunian.xusui] uses).
  final int xusui;
}

/// One 流月: its 干支, the 节 it begins on and when, and its 十神.
class LiuyueMonth {
  const LiuyueMonth(this.ganzhi, this.jie, this.starts, this.shishenGan, this.shishenZhi);
  factory LiuyueMonth.fromJson(Json j) => LiuyueMonth(
        j['ganzhi'] as String,
        j['jie'] as String,
        j['starts'] as String,
        j['shishen_gan'] as String,
        j['shishen_zhi'] as String,
      );
  final String ganzhi;

  /// The 节 it begins on (engine form, simplified), e.g. 立春.
  final String jie;

  /// When it begins, YYYY-MM-DD HH:mm in UTC+8.
  final String starts;
  final String shishenGan;
  final String shishenZhi;
}

/// 合冲刑害破 among characters: its type, element (for 合 / 会) and members.
class Relation {
  const Relation(this.type, this.element, this.members);
  factory Relation.fromJson(Json j) => Relation(
        j['type'] as String,
        j['element'] as String?,
        [for (final m in (j['members'] as List).cast<Json>()) (m['pillar'] as String, m['char'] as String)],
      );
  final String type;
  final String? element;
  final List<(String pillar, String char)> members;
}

/// 日主旺衰 + 喜用 by the engine's simplified 扶抑法 (charts since v2.0.0).
class StrengthView {
  const StrengthView(this.verdict, this.deLing, this.favorable, this.unfavorable, this.special);
  factory StrengthView.fromJson(Json j) => StrengthView(
        j['verdict'] as String,
        j['de_ling'] as bool,
        (j['favorable'] as List).cast<String>(),
        (j['unfavorable'] as List).cast<String>(),
        j['special'] as String?,
      );

  /// 身强 | 身弱 | 中和 (engine form).
  final String verdict;
  final bool deLing;
  final List<String> favorable;
  final List<String> unfavorable;

  /// 专旺候选 | 从格候选: no 喜用 set; worth a practitioner's closer look.
  final String? special;
}

/// A 神煞 the natal chart holds, and the pillars that hold it.
class ShenshaHit {
  const ShenshaHit(this.name, this.pillars);
  factory ShenshaHit.fromJson(Json j) => ShenshaHit(j['name'] as String, (j['pillars'] as List).cast<String>());
  final String name;
  final List<String> pillars;
}

class BranchRelation {
  const BranchRelation(this.pillar, this.type);
  final String pillar;
  final String type;
}

class Liunian {
  const Liunian({
    required this.year,
    required this.ganzhi,
    required this.age,
    required this.xusui,
    required this.shishenGan,
    required this.shishenZhi,
    required this.dayunIndex,
    required this.relations,
  });

  factory Liunian.fromJson(Json j) => Liunian(
        year: j['year'] as int,
        ganzhi: j['ganzhi'] as String,
        age: j['age'] as int,
        xusui: (j['age_xu'] ?? (j['age'] as int) + 1) as int,
        shishenGan: j['shishen_gan'] as String,
        shishenZhi: j['shishen_zhi'] as String,
        dayunIndex: j['dayun_index'] as int,
        relations: _list(
          j['branch_relations'],
          (r) => BranchRelation(r['pillar'] as String, r['type'] as String),
        ),
      );

  final int year;
  final String ganzhi;
  final int age;

  /// 虚岁 in this year (charts made before v1.3.0: age + 1, the same count).
  final int xusui;
  final String shishenGan;
  final String shishenZhi;
  final int dayunIndex;
  final List<BranchRelation> relations;
}

class LunarDate {
  const LunarDate({
    required this.year,
    required this.yearGanzhi,
    required this.shengxiao,
    required this.month,
    required this.isLeapMonth,
    required this.monthName,
    required this.day,
    required this.dayName,
  });

  factory LunarDate.fromJson(Json j) => LunarDate(
        year: j['year'] as int,
        yearGanzhi: j['year_ganzhi'] as String,
        shengxiao: j['shengxiao'] as String,
        month: j['month'] as int,
        isLeapMonth: j['is_leap_month'] as bool,
        monthName: j['month_name'] as String,
        day: j['day'] as int,
        dayName: j['day_name'] as String,
      );

  /// 農曆 year number (turns at 春節).
  final int year;
  final String yearGanzhi;
  final String shengxiao;
  final int month;
  final bool isLeapMonth;

  /// Engine form (simplified), e.g. 闰二月 — display through the term table.
  final String monthName;
  final int day;
  final String dayName;
}

class BaziChart {
  const BaziChart({
    required this.pillars,
    required this.lunar,
    required this.civilLocal,
    required this.dayMasterGan,
    required this.dayMasterWuxing,
    required this.dayMasterYinYang,
    required this.wuxingWeighted,
    required this.dayunForward,
    required this.dayunStartDate,
    required this.cycles,
    required this.liunian,
    this.relations = const [],
    this.shensha = const [],
    this.kongwang,
    this.kongwangPillars = const [],
    this.taiyuan,
    this.strength,
    this.dayunYears = const [],
    this.liuyueYear,
    this.liuyue = const [],
  });

  factory BaziChart.fromFacts(Json f) {
    final p = f['pillars'] as Json;
    final dm = f['day_master'] as Json;
    final dy = f['dayun'] as Json;
    final kw = f['kongwang'] as Json?;
    return BaziChart(
      pillars: {
        for (final k in pillarOrder) k: Pillar.fromJson(p[k] as Json),
      },
      lunar: LunarDate.fromJson(f['lunar'] as Json),
      civilLocal: (f['time_basis'] as Json)['civil_local'] as String,
      dayMasterGan: dm['gan'] as String,
      dayMasterWuxing: dm['wuxing'] as String,
      dayMasterYinYang: dm['yin_yang'] as String,
      wuxingWeighted: ((f['wuxing_weighted'] as Json)['scores'] as Json)
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      dayunForward: dy['direction'] == 'forward',
      dayunStartDate: dy['start_date'] as String,
      cycles: _list(dy['cycles'], DayunCycle.fromJson),
      liunian: _list(f['liunian'], Liunian.fromJson),
      // Charts since v1.3.0 (older ones: empty).
      relations: _list(f['relations'], Relation.fromJson),
      shensha: _list(f['shensha'], ShenshaHit.fromJson),
      kongwang: kw?['by_day'] as String?,
      kongwangPillars: ((kw?['pillars'] as List?) ?? const []).cast<String>(),
      taiyuan: f['taiyuan'] as String?,
      strength: f['strength'] == null ? null : StrengthView.fromJson(f['strength'] as Json),
      // Charts since v3.3.0 (older ones: empty), and 流月 since v1.3.0.
      dayunYears: _list(f['dayun_years'], Liunian.fromJson),
      liuyueYear: (f['liuyue'] as Json?)?['year'] as int?,
      liuyue: _list((f['liuyue'] as Json?)?['months'], LiuyueMonth.fromJson),
    );
  }

  static const pillarOrder = ['year', 'month', 'day', 'hour'];

  final Map<String, Pillar> pillars;
  final LunarDate lunar;

  /// Birth wall-clock time as entered (YYYY-MM-DDTHH:mm:ss).
  final String civilLocal;
  final String dayMasterGan;
  final String dayMasterWuxing;
  final String dayMasterYinYang;
  final Map<String, double> wuxingWeighted;
  final bool dayunForward;
  final String dayunStartDate;
  final List<DayunCycle> cycles;
  final List<Liunian> liunian;

  /// 合冲刑害破 among the natal pillars.
  final List<Relation> relations;
  final List<ShenshaHit> shensha;

  /// 空亡 by the day pillar (two branches), and the natal pillars that fall in it.
  final String? kongwang;
  final List<String> kongwangPillars;

  /// 胎元 干支.
  final String? taiyuan;

  /// 日主旺衰 + 喜用 (charts since v2.0.0).
  final StrengthView? strength;

  /// The ten years of every 大运, in order (charts since v3.3.0; empty before).
  final List<Liunian> dayunYears;

  /// The year the 流月 are for, and its twelve months from 立春.
  final int? liuyueYear;
  final List<LiuyueMonth> liuyue;

  String get fourPillars => pillarOrder.map((k) => pillars[k]!.ganzhi).join(' ');

  /// The year the chart is read in: its first 流年 (the engine starts them this year).
  int? get thisYear => liunian.isEmpty ? null : liunian.first.year;

  /// The 大运 running in [thisYear] (null before the first one starts).
  int? get currentDayun => liunian.isEmpty || liunian.first.dayunIndex == 0 ? null : liunian.first.dayunIndex;

  /// One 大运's ten years.
  List<Liunian> yearsOf(int dayunIndex) => [
        for (final y in dayunYears)
          if (y.dayunIndex == dayunIndex) y,
      ];
}

class TarotCardFact {
  const TarotCardFact(this.position, this.positionKey, this.cardId, this.reversed);
  final int position;
  final String positionKey;
  final String cardId;
  final bool reversed;
}

class TarotChart {
  const TarotChart(this.spreadId, this.cards, this.drawId);

  factory TarotChart.fromFacts(Json f) => TarotChart(
        f['spread_id'] as String,
        _list(
          f['cards'],
          (c) => TarotCardFact(
            c['position'] as int,
            c['position_key'] as String,
            c['card_id'] as String,
            c['reversed'] as bool,
          ),
        ),
        (f['audit'] as Json)['draw_id'] as String,
      );

  final String spreadId;
  final List<TarotCardFact> cards;
  final String drawId;
}

class ChartResult {
  const ChartResult({required this.chartId, required this.system, required this.facts});

  factory ChartResult.fromJson(Json j) {
    final fact = j['chart_fact'] as Json;
    return ChartResult(
      chartId: j['chart_id'] as String,
      system: fact['system'] as String,
      facts: fact['facts'] as Json,
    );
  }

  final String chartId;
  final String system;
  final Json facts;

  BaziChart get bazi => BaziChart.fromFacts(facts);
  TarotChart get tarot => TarotChart.fromFacts(facts);
  QiuqianChart get qiuqian => QiuqianChart.fromFacts(facts);
}

class Paragraph {
  const Paragraph(this.text, this.sourceLevel, this.factRefs);
  final String text;
  final String sourceLevel;
  final List<String> factRefs;
}

class Section {
  const Section(this.topic, this.paragraphs, [this.summary]);
  final String topic;
  final List<Paragraph> paragraphs;

  /// The topic's main point in one plain sentence (narrative@4+).
  final String? summary;
}

class ActionItem {
  const ActionItem(this.topic, this.text, this.horizon);
  final String topic;
  final String text;
  final String horizon;
}

class Expectation {
  const Expectation(this.text, this.aiLabel, this.labelRequired);
  final String text;
  final String aiLabel;
  final bool labelRequired;
}

/// One scored period of the trend chart: a 大運 (age range) or a 流年 (year).
class TrendPoint {
  const TrendPoint({
    required this.label,
    required this.ganzhi,
    required this.scores,
    required this.overall,
    required this.note,
    this.startAge,
    this.endAge,
    this.year,
    this.startYear,
  });

  factory TrendPoint.fromJson(Json j) => TrendPoint(
        label: j['year'] != null ? '${j['year']}' : '${j['start_age']}–${j['end_age']}',
        ganzhi: j['ganzhi'] as String,
        scores: (j['scores'] as Json).map((k, v) => MapEntry(k, (v as num).toInt())),
        overall: (j['overall'] as num).toInt(),
        note: j['note'] as String,
        startAge: j['start_age'] as int?,
        endAge: j['end_age'] as int?,
        year: j['year'] as int?,
        startYear: j['start_year'] as int?,
      );

  /// X-axis label: "28–37" (ages) or "2026" (year).
  final String label;
  final String ganzhi;
  final Map<String, int> scores;
  final int overall;
  final String note;
  final int? startAge;
  final int? endAge;
  final int? year;

  /// 大運 only: first calendar year of the period.
  final int? startYear;

  /// Whether this period contains [y] (a 大運 spans 10 years).
  bool covers(int y) => year != null ? year == y : (startYear != null && y >= startYear! && y < startYear! + 10);
}

/// 八字 trend scores (0–100). `overall` and `total` are computed by the server.
class TrendLayer {
  const TrendLayer(this.topics, this.dayun, this.liunian, this.total, this.methodNote);

  factory TrendLayer.fromJson(Json j) => TrendLayer(
        ((j['topics'] as List?) ?? const []).cast<String>(),
        _list(j['dayun'], TrendPoint.fromJson),
        _list(j['liunian'], TrendPoint.fromJson),
        (j['total'] as num).toInt(),
        j['method_note'] as String,
      );

  final List<String> topics;
  final List<TrendPoint> dayun;
  final List<TrendPoint> liunian;
  final int total;
  final String methodNote;
}

class ReportLayers {
  const ReportLayers(this.facts, this.interpretation, this.actions, this.expectation, [this.trend]);

  factory ReportLayers.fromJson(Json j) {
    final e = j['expectation'] as Json;
    return ReportLayers(
      (j['facts'] as List).cast<String>(),
      _list(
        j['interpretation'],
        (s) => Section(
          s['topic'] as String,
          _list(
            s['paragraphs'],
            (p) => Paragraph(
              p['text'] as String,
              p['source_level'] as String,
              (p['fact_refs'] as List).cast<String>(),
            ),
          ),
          s['summary'] as String?,
        ),
      ),
      _list(
        j['actions'],
        (a) => ActionItem(a['topic'] as String, a['text'] as String, a['horizon'] as String),
      ),
      Expectation(e['text'] as String, e['ai_label'] as String, e['label_required'] as bool),
      j['trend'] == null ? null : TrendLayer.fromJson(j['trend'] as Json),
    );
  }

  final List<String> facts;
  final List<Section> interpretation;
  final List<ActionItem> actions;
  final Expectation expectation;

  /// 八字 only; null when absent.
  final TrendLayer? trend;
}

class RemedyStep {
  const RemedyStep(this.title, this.text, this.horizon);
  final String title;
  final String text;
  final String horizon;
}

/// A bought 破除運勢 plan for one topic (POST /v1/reports/{id}/remedies).
class RemedyView {
  const RemedyView({
    required this.id,
    required this.topic,
    required this.status,
    this.target,
    this.summary,
    this.focusPeriods = const [],
    this.steps = const [],
    this.basis,
    this.closing,
    this.message,
    this.paymentStatus,
    this.locked = false,
  });

  factory RemedyView.fromJson(Json j) {
    final c = j['content'] as Json?;
    return RemedyView(
      id: j['remedy_id'] as String,
      topic: j['topic'] as String,
      status: j['status'] as String,
      target: c?['target'] as String?,
      summary: c?['summary'] as String?,
      focusPeriods: ((c?['focus_periods'] as List?) ?? const []).cast<String>(),
      steps: _list(
        c?['steps'],
        (s) => RemedyStep(s['title'] as String, s['text'] as String, s['horizon'] as String),
      ),
      basis: c?['basis'] as String?,
      closing: c?['closing'] as String?,
      message: j['message'] as String?,
      paymentStatus: (j['payment'] as Json?)?['status'] as String?,
      locked: j['locked'] as bool? ?? false,
    );
  }

  final String id;
  final String topic;

  /// pending | passed | blocked | manual_review | failed
  final String status;
  final String? target;
  final String? summary;
  final List<String> focusPeriods;
  final List<RemedyStep> steps;
  final String? basis;
  final String? closing;
  final String? message;

  /// "placeholder" until Phase 4 payments.
  final String? paymentStatus;

  /// Preloaded but not bought: content withheld until purchase.
  final bool locked;

  /// Preloaded and ready: buying opens it at once.
  bool get ready => locked && status == 'passed';

  bool get isTerminal => status != 'pending';
  bool get hasContent => status == 'passed' && target != null;
}

/// GET /v1/reports/{id}/remedies: the price and the plans already bought.
class RemedyList {
  const RemedyList(this.amount, this.currency, this.items);
  factory RemedyList.fromJson(Json j) {
    final p = j['price'] as Json;
    return RemedyList((p['amount'] as num).toDouble(), p['currency'] as String, _list(j['items'], RemedyView.fromJson));
  }
  final double amount;
  final String currency;
  final List<RemedyView> items;

  String get priceLabel => '$currency ${amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2)}';
}

class ReportView {
  const ReportView({
    required this.id,
    this.chartId,
    required this.status,
    required this.topics,
    this.message,
    this.layers,
    this.model,
    this.progressStage,
    this.progressAttempt = 1,
    this.createdAt,
  });

  factory ReportView.fromJson(Json j) => ReportView(
        id: j['report_id'] as String,
        chartId: j['chart_id'] as String?,
        status: j['status'] as String,
        topics: ((j['topics'] as List?) ?? const []).cast<String>(),
        message: j['message'] as String?,
        layers: j['layers'] == null ? null : ReportLayers.fromJson(j['layers'] as Json),
        model: (j['ai_disclosure'] as Json?)?['model'] as String?,
        progressStage: (j['progress'] as Json?)?['stage'] as String?,
        progressAttempt: ((j['progress'] as Json?)?['attempt'] as int?) ?? 1,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
      );

  final String id;

  /// The reading's chart (since v2.4.0), e.g. to show a tarot spread.
  final String? chartId;

  /// pending | passed | blocked | manual_review | failed
  final String status;
  final List<String> topics;
  final String? message;
  final ReportLayers? layers;
  final String? model;

  /// While pending: narrative | action | guard (null until the first stage starts).
  final String? progressStage;
  final int progressAttempt;
  final DateTime? createdAt;

  bool get isTerminal => status != 'pending';
}

/// One 時辰 of a day with its 干支 (GET /v1/calendar/lunar → shichen).
class ShichenOption {
  const ShichenOption({required this.key, required this.zhi, required this.ganzhi, required this.start, required this.end, required this.mid});

  factory ShichenOption.fromJson(Json j) => ShichenOption(
        key: j['key'] as String,
        zhi: j['zhi'] as String,
        ganzhi: j['ganzhi'] as String,
        start: j['start'] as String,
        end: j['end'] as String,
        mid: j['mid'] as String,
      );

  /// zi_early | 丑 … 亥 | zi_late
  final String key;
  final String zhi;
  final String ganzhi;
  final String start;
  final String end;

  /// HH:mm the pick resolves to.
  final String mid;

  int get midHour => int.parse(mid.substring(0, 2));
  int get midMinute => int.parse(mid.substring(3, 5));
}

class CalendarDay {
  const CalendarDay(this.lunar, this.shichen);
  factory CalendarDay.fromJson(Json j) => CalendarDay(
        LunarDate.fromJson(j['lunar'] as Json),
        _list(j['shichen'], ShichenOption.fromJson),
      );
  final LunarDate lunar;
  final List<ShichenOption> shichen;
}

class LunarMonthInfo {
  const LunarMonthInfo({required this.month, required this.isLeap, required this.days, required this.name});
  factory LunarMonthInfo.fromJson(Json j) => LunarMonthInfo(
        month: j['month'] as int,
        isLeap: j['is_leap'] as bool,
        days: j['days'] as int,
        name: j['name'] as String,
      );
  final int month;
  final bool isLeap;
  final int days;

  /// Engine form, e.g. 闰二月 — display through the term table.
  final String name;
}

/// One row of GET /v1/reports (history).
class HistoryItem {
  const HistoryItem({
    required this.reportId,
    required this.chartId,
    required this.status,
    required this.createdAt,
    required this.system,
    this.fourPillars,
    this.cardIds = const [],
    this.cardsReversed = const [],
    this.lotNumber,
    this.lotGanzhi,
  });

  factory HistoryItem.fromJson(Json j) {
    final chart = (j['chart'] as Json?) ?? const {};
    return HistoryItem(
      reportId: j['report_id'] as String,
      chartId: j['chart_id'] as String,
      status: j['status'] as String,
      createdAt: DateTime.parse(j['created_at'] as String),
      system: chart['system'] as String? ?? 'bazi',
      fourPillars: chart['four_pillars'] as String?,
      cardIds: _list(chart['cards'], (c) => c['card_id'] as String),
      cardsReversed: _list(chart['cards'], (c) => c['reversed'] as bool? ?? false),
      lotNumber: chart['lot'] as int?,
      lotGanzhi: chart['ganzhi'] as String?,
    );
  }

  final String reportId;
  final String chartId;
  final String status;
  final DateTime createdAt;
  final String system;
  final String? fourPillars;
  final List<String> cardIds;

  /// Per card in [cardIds]: drawn reversed.
  final List<bool> cardsReversed;

  /// 求籤 (v4.3.0): the lot drawn and its label.
  final int? lotNumber;
  final String? lotGanzhi;
}
