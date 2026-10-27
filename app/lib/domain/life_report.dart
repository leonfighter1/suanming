import 'models.dart' show Json;

List<T> _list<T>(Object? v, T Function(Json) f) => ((v as List?) ?? const []).cast<Json>().map(f).toList();
List<String> _strs(Object? v) => ((v as List?) ?? const []).cast<String>();

/// A hexagram as the engine computed it (lines bottom first, '1' = yang).
class Hexagram {
  const Hexagram(this.id, this.upper, this.lower, this.name, this.fullName, this.guaCi, this.daXiang);
  factory Hexagram.fromJson(Json j) => Hexagram(
    j['id'] as String,
    j['upper'] as String,
    j['lower'] as String,
    j['name'] as String,
    j['full_name'] as String,
    j['gua_ci'] as String,
    j['da_xiang'] as String,
  );
  final String id;
  final String upper;
  final String lower;
  final String name;
  final String fullName;
  final String guaCi;
  final String daXiang;

  bool yang(int line) => id[line - 1] == '1';
}

class HexLine {
  const HexLine(this.line, this.yang, this.moving, this.ageFrom, this.ageTo, this.text);
  factory HexLine.fromJson(Json j) =>
      HexLine(j['line'] as int, j['yang'] as bool, j['moving'] as bool, j['age_from'] as int, j['age_to'] as int?, j['text'] as String);
  final int line;
  final bool yang;
  final bool moving;
  final int ageFrom;
  final int? ageTo;

  /// 爻辞, e.g. 「六二：不耕获，不菑畬，则利有攸往。」
  final String text;

  /// 「初九」 from the 爻辞 prefix.
  String get position => text.split(RegExp('[：:]')).first;
  String get ages => ageTo == null ? '$ageFrom+' : '$ageFrom–$ageTo';
}

class TrigramInfo {
  const TrigramInfo(this.name, this.image, this.wuxing);
  final String name;
  final String image;
  final String wuxing;
}

class MeihuaPart {
  const MeihuaPart(this.trigram, this.wuxing, this.relation);
  factory MeihuaPart.fromJson(Json j) => MeihuaPart(j['trigram'] as String, j['wuxing'] as String, j['relation'] as String?);
  final String trigram;
  final String wuxing;

  /// 比和 | 生体 | 体生 | 体克 | 克体 (null for 体 itself)
  final String? relation;
}

class BazhaiDirection {
  const BazhaiDirection(this.star, this.luck, this.trigram, this.direction);
  factory BazhaiDirection.fromJson(Json j) =>
      BazhaiDirection(j['star'] as String, j['luck'] as String, j['trigram'] as String, j['direction'] as String);
  final String star;
  final String luck;
  final String trigram;
  final String direction;
  bool get good => luck.contains('吉');
}

/// Engine output of a 一生运势报告 (not AI).
class LifeFacts {
  LifeFacts.fromJson(Json j)
    : pillarClock = (j['birth'] as Json)['pillar_clock'] as String,
      trueSolar = (j['birth'] as Json)['true_solar_time_applied'] as bool,
      steps = (j['benming'] as Json)['steps'] as Json,
      hexagram = Hexagram.fromJson((j['benming'] as Json)['hexagram'] as Json),
      changed = Hexagram.fromJson((j['benming'] as Json)['changed'] as Json),
      nuclear = Hexagram.fromJson((j['benming'] as Json)['nuclear'] as Json),
      movingLine = (j['benming'] as Json)['moving_line'] as int,
      lines = _list((j['benming'] as Json)['lines'], HexLine.fromJson),
      ti = MeihuaPart.fromJson((j['meihua'] as Json)['ti'] as Json),
      yong = MeihuaPart.fromJson((j['meihua'] as Json)['yong'] as Json),
      hu = _list(((j['meihua'] as Json)['hu'] as Json)['trigrams'], MeihuaPart.fromJson),
      bian = MeihuaPart.fromJson((j['meihua'] as Json)['bian'] as Json),
      season = (j['meihua'] as Json)['season'] as Json,
      kua = (j['bazhai'] as Json)['kua'] as int,
      kuaTrigram = (j['bazhai'] as Json)['trigram'] as String,
      kuaGroup = (j['bazhai'] as Json)['group'] as String,
      kuaWuxing = (j['bazhai'] as Json)['wuxing'] as String,
      directions = _list((j['bazhai'] as Json)['directions'], BazhaiDirection.fromJson),
      trigrams = (j['trigrams'] as Json).map(
        (k, v) => MapEntry(k, TrigramInfo((v as Json)['name'] as String, v['image'] as String, v['wuxing'] as String)),
      );

  /// Wall clock the 时柱 was read from (真太阳时 when applied).
  final String pillarClock;
  final bool trueSolar;
  final Json steps;
  final Hexagram hexagram;
  final Hexagram changed;
  final Hexagram nuclear;
  final int movingLine;
  final List<HexLine> lines;
  final MeihuaPart ti;
  final MeihuaPart yong;
  final List<MeihuaPart> hu;
  final MeihuaPart bian;
  final Json season;
  final int kua;
  final String kuaTrigram;
  final String kuaGroup;
  final String kuaWuxing;
  final List<BazhaiDirection> directions;
  final Map<String, TrigramInfo> trigrams;

  TrigramInfo trigram(String id) => trigrams[id]!;
}

class LifeTopic {
  const LifeTopic(this.key, this.summary, this.points);
  final String key;
  final String summary;
  final List<(String period, String text)> points;
}

class LifeStage {
  const LifeStage(this.ganzhi, this.startYear, this.startAge, this.endAge, this.label, this.score, this.focus);
  factory LifeStage.fromJson(Json j) => LifeStage(
    j['ganzhi'] as String,
    j['start_year'] as int,
    j['start_age'] as int,
    j['end_age'] as int,
    j['label'] as String,
    (j['score'] as num).toInt(),
    j['focus'] as String,
  );
  final String ganzhi;
  final int startYear;
  final int startAge;
  final int endAge;
  final String label;
  final int score;
  final String focus;
  String get ages => '$startAge–$endAge';
  String get years => '$startYear–${startYear + 9}';
}

/// AI layers of a passed 一生运势报告.
class LifeLayers {
  LifeLayers.fromJson(Json j)
    : yijing = (j['methods'] as Json)['yijing'] as Json,
      meihua = (j['methods'] as Json)['meihua'] as Json,
      wuxing = (j['methods'] as Json)['wuxing'] as Json,
      bazhai = (j['methods'] as Json)['bazhai'] as Json,
      topics = _list(
        j['topics'],
        (t) => LifeTopic(t['key'] as String, t['summary'] as String, [
          for (final p in (t['points'] as List).cast<Json>()) (p['period'] as String, p['text'] as String),
        ]),
      ),
      stages = _list(j['stages'], LifeStage.fromJson),
      verdict = (j['summary'] as Json)['verdict'] as String,
      advice = [for (final a in ((j['summary'] as Json)['advice'] as List).cast<Json>()) (a['area'] as String, a['text'] as String)],
      closing = (j['summary'] as Json)['closing'] as String,
      disclaimer = (j['expectation'] as Json)['text'] as String,
      aiLabel = (j['expectation'] as Json)['ai_label'] as String;

  final Json yijing;
  final Json meihua;
  final Json wuxing;
  final Json bazhai;
  final List<LifeTopic> topics;
  final List<LifeStage> stages;
  final String verdict;
  final List<(String area, String text)> advice;
  final String closing;
  final String disclaimer;
  final String aiLabel;

  String yijingText(String k) => yijing[k] as String;

  /// AI reading for one of the six lines (1–6).
  String stageReading(int line) =>
      ((yijing['stages'] as List).cast<Json>().where((s) => s['line'] == line).firstOrNull?['reading'] as String?) ?? '';
  List<String> favorable() => _strs(wuxing['favorable']);
  List<String> unfavorable() => _strs(wuxing['unfavorable']);
}

class LifeReportView {
  const LifeReportView({
    required this.id,
    required this.chartId,
    required this.status,
    this.facts,
    this.layers,
    this.progressStage,
    this.createdAt,
    this.model,
  });

  factory LifeReportView.fromJson(Json j) => LifeReportView(
    id: j['life_report_id'] as String,
    chartId: j['chart_id'] as String,
    status: j['status'] as String,
    facts: j['facts'] == null ? null : LifeFacts.fromJson(j['facts'] as Json),
    layers: j['layers'] == null ? null : LifeLayers.fromJson(j['layers'] as Json),
    progressStage: (j['progress'] as Json?)?['stage'] as String?,
    createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
    model: (j['ai_disclosure'] as Json?)?['model'] as String?,
  );

  final String id;
  final String chartId;

  /// pending | passed | blocked | manual_review | failed
  final String status;
  final LifeFacts? facts;
  final LifeLayers? layers;

  /// life_methods | life_topics | guard while pending
  final String? progressStage;
  final DateTime? createdAt;
  final String? model;

  bool get isTerminal => status != 'pending';
}
