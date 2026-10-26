// Client-side views of the v1 API contract (api/openapi.yaml, ChartFact v0.1).
// Parsing is tolerant of extra fields: the contract is additive-only.

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
  const DayunCycle(this.index, this.ganzhi, this.startYear, this.startAge);
  factory DayunCycle.fromJson(Json j) => DayunCycle(
        j['index'] as int,
        j['ganzhi'] as String,
        j['start_year'] as int,
        j['start_age'] as int,
      );
  final int index;
  final String ganzhi;
  final int startYear;
  final int startAge;
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
    required this.shishenGan,
    required this.shishenZhi,
    required this.dayunIndex,
    required this.relations,
  });

  factory Liunian.fromJson(Json j) => Liunian(
        year: j['year'] as int,
        ganzhi: j['ganzhi'] as String,
        age: j['age'] as int,
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
  final String shishenGan;
  final String shishenZhi;
  final int dayunIndex;
  final List<BranchRelation> relations;
}

class BaziChart {
  const BaziChart({
    required this.pillars,
    required this.dayMasterGan,
    required this.dayMasterWuxing,
    required this.dayMasterYinYang,
    required this.wuxingWeighted,
    required this.dayunForward,
    required this.dayunStartDate,
    required this.cycles,
    required this.liunian,
  });

  factory BaziChart.fromFacts(Json f) {
    final p = f['pillars'] as Json;
    final dm = f['day_master'] as Json;
    final dy = f['dayun'] as Json;
    return BaziChart(
      pillars: {
        for (final k in pillarOrder) k: Pillar.fromJson(p[k] as Json),
      },
      dayMasterGan: dm['gan'] as String,
      dayMasterWuxing: dm['wuxing'] as String,
      dayMasterYinYang: dm['yin_yang'] as String,
      wuxingWeighted: ((f['wuxing_weighted'] as Json)['scores'] as Json)
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      dayunForward: dy['direction'] == 'forward',
      dayunStartDate: dy['start_date'] as String,
      cycles: _list(dy['cycles'], DayunCycle.fromJson),
      liunian: _list(f['liunian'], Liunian.fromJson),
    );
  }

  static const pillarOrder = ['year', 'month', 'day', 'hour'];

  final Map<String, Pillar> pillars;
  final String dayMasterGan;
  final String dayMasterWuxing;
  final String dayMasterYinYang;
  final Map<String, double> wuxingWeighted;
  final bool dayunForward;
  final String dayunStartDate;
  final List<DayunCycle> cycles;
  final List<Liunian> liunian;

  String get fourPillars => pillarOrder.map((k) => pillars[k]!.ganzhi).join(' ');
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
}

class Paragraph {
  const Paragraph(this.text, this.sourceLevel, this.factRefs);
  final String text;
  final String sourceLevel;
  final List<String> factRefs;
}

class Section {
  const Section(this.topic, this.paragraphs);
  final String topic;
  final List<Paragraph> paragraphs;
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

class ReportLayers {
  const ReportLayers(this.facts, this.interpretation, this.actions, this.expectation);

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
        ),
      ),
      _list(
        j['actions'],
        (a) => ActionItem(a['topic'] as String, a['text'] as String, a['horizon'] as String),
      ),
      Expectation(e['text'] as String, e['ai_label'] as String, e['label_required'] as bool),
    );
  }

  final List<String> facts;
  final List<Section> interpretation;
  final List<ActionItem> actions;
  final Expectation expectation;
}

class ReportView {
  const ReportView({
    required this.id,
    required this.status,
    required this.topics,
    this.message,
    this.layers,
    this.model,
  });

  factory ReportView.fromJson(Json j) => ReportView(
        id: j['report_id'] as String,
        status: j['status'] as String,
        topics: ((j['topics'] as List?) ?? const []).cast<String>(),
        message: j['message'] as String?,
        layers: j['layers'] == null ? null : ReportLayers.fromJson(j['layers'] as Json),
        model: (j['ai_disclosure'] as Json?)?['model'] as String?,
      );

  final String id;

  /// pending | passed | blocked | manual_review | failed
  final String status;
  final List<String> topics;
  final String? message;
  final ReportLayers? layers;
  final String? model;

  bool get isTerminal => status != 'pending';
}
