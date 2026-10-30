import 'models.dart' show Json;

/// What an AI request costs in 积分 (v11.0.0, S20): its estimate, and what it holds while it runs (the most it is
/// charged; once done it is charged what it really cost).
class Quote {
  const Quote(this.points, this.hold);
  factory Quote.fromJson(Json j) => Quote((j['points'] as num).toInt(), (j['hold'] as num).toInt());
  static Quote? maybe(Object? j) => j is Json ? Quote.fromJson(j) : null;
  final int points;
  final int hold;
}

/// What each AI request on a chart costs now (GET /v1/charts/{id}/quote): the reading, and the 深度分析's 统一收费 and
/// the 一生运势报告 where the chart has them.
class ChartQuote {
  const ChartQuote({required this.report, this.inquiry, this.lifeReport});
  factory ChartQuote.fromJson(Json j) => ChartQuote(
        report: Quote.fromJson(j['report'] as Json),
        inquiry: Quote.maybe(j['inquiry']),
        lifeReport: Quote.maybe(j['life_report']),
      );
  final Quote report;
  final Quote? inquiry;
  final Quote? lifeReport;
}

/// A 充值 pack: what is paid, the 积分 it brings, and its bonus over 100 积分 a 元.
class PointsPack {
  const PointsPack({required this.yuan, required this.points, required this.bonusPercent});
  factory PointsPack.fromJson(Json j) => PointsPack(
        yuan: (j['yuan'] as num).toInt(),
        points: (j['points'] as num).toInt(),
        bonusPercent: (j['bonus_percent'] as num?)?.toInt() ?? 0,
      );
  final int yuan;
  final int points;
  final int bonusPercent;
}

/// One change to the balance: a grant, a top-up or a charge, and what it left.
class PointsEntryView {
  const PointsEntryView({
    required this.id,
    required this.kind,
    required this.points,
    required this.balance,
    required this.createdAt,
    this.forKind,
    this.system,
    this.basis,
    this.usd,
    this.packYuan,
    this.reason,
  });
  factory PointsEntryView.fromJson(Json j) {
    final f = j['for'] as Json?;
    final pack = j['pack'] as Json?;
    return PointsEntryView(
      id: j['id'] as String,
      kind: j['kind'] as String,
      points: (j['points'] as num).toInt(),
      balance: (j['balance'] as num).toInt(),
      createdAt: DateTime.parse(j['created_at'] as String),
      forKind: f?['kind'] as String?,
      system: f?['system'] as String?,
      basis: j['basis'] as String?,
      usd: (j['usd'] as num?)?.toDouble(),
      packYuan: (pack?['yuan'] as num?)?.toInt(),
      reason: j['reason'] as String?,
    );
  }
  final String id;

  /// grant, topup or charge.
  final String kind;

  /// Signed: more for a grant or a top-up, less for a charge.
  final int points;
  final int balance;
  final DateTime createdAt;

  /// What a charge paid for (report, life_report, followup, inquiry, remedy) and the method of its chart.
  final String? forKind;
  final String? system;

  /// How a charge was priced: measured (its real AI use), estimate (the demo answered) or flat (the 深度分析's fee).
  final String? basis;

  /// A measured charge's cost in US dollars, shown while 充值 is simulated.
  final double? usd;
  final int? packYuan;
  final String? reason;
}

/// The account's 积分 (GET /v1/points): the balance, what running requests hold, the 充值 packs and the latest
/// changes. [enabled] is false when the server has 积分 off: then nothing costs anything and nothing is shown.
class PointsView {
  const PointsView({
    required this.enabled,
    this.balance = 0,
    this.held = 0,
    this.available = 0,
    this.topUp = 'unavailable',
    this.packs = const [],
    this.entries = const [],
  });
  factory PointsView.fromJson(Json j) => j['enabled'] != true
      ? off
      : PointsView(
          enabled: true,
          balance: (j['balance'] as num).toInt(),
          held: (j['held'] as num).toInt(),
          available: (j['available'] as num).toInt(),
          topUp: j['top_up'] as String? ?? 'unavailable',
          packs: [for (final p in (j['packs'] as List? ?? const [])) PointsPack.fromJson(p as Json)],
          entries: [for (final e in (j['entries'] as List? ?? const [])) PointsEntryView.fromJson(e as Json)],
        );

  static const off = PointsView(enabled: false);

  final bool enabled;
  final int balance;
  final int held;
  final int available;

  /// simulated (development: a pack's 积分 arrive without payment) or unavailable (real payments come later).
  final String topUp;
  bool get simulated => topUp == 'simulated';
  final List<PointsPack> packs;
  final List<PointsEntryView> entries;
}
