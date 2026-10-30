// What the admin API returns (管理后台, tech plan S22; api/openapi.yaml, tag admin). Money is in 元.

typedef Json = Map<String, dynamic>;

int _i(Object? v) => (v as num?)?.toInt() ?? 0;
double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
List<T> _list<T>(Object? v, T Function(Json) f) => [for (final e in (v as List? ?? const [])) f(e as Json)];

class AdminMe {
  const AdminMe({required this.id, required this.login, required this.adminByConfig});
  factory AdminMe.fromJson(Json j) =>
      AdminMe(id: j['id'] as String, login: j['login'] as String, adminByConfig: j['admin_by_config'] == true);
  final String id;
  final String login;

  /// Named in the server's MINGLI_ADMINS: an admin whatever the dashboard does.
  final bool adminByConfig;
}

/// 充值 (what was paid), its net after the payment fee and VAT, the AI cost, gross profit and its margin.
class Money {
  const Money({required this.topup, required this.net, required this.cost, required this.profit, this.margin});
  factory Money.fromJson(Json j) => Money(
        topup: _d(j['topup_cny']),
        net: _d(j['net_cny']),
        cost: _d(j['cost_cny']),
        profit: _d(j['profit_cny']),
        margin: (j['margin'] as num?)?.toDouble(),
      );
  final double topup;
  final double net;
  final double cost;
  final double profit;
  final double? margin;
}

class Overview {
  const Overview({
    required this.days,
    required this.from,
    required this.to,
    required this.accounts,
    required this.newAccounts,
    required this.suspended,
    required this.admins,
    required this.demo,
    required this.activeNow,
    required this.activeDay,
    required this.activeWeek,
    required this.activeMonth,
    required this.jobs,
    required this.deliveredJobs,
    required this.inputTokens,
    required this.outputTokens,
    required this.tokens,
    required this.costUsd,
    required this.money,
    required this.pointsSold,
    required this.pointsGranted,
    required this.pointsUsed,
    required this.pointsOutstanding,
    this.previous,
  });
  factory Overview.fromJson(Json j) {
    final a = j['accounts'] as Json;
    final act = j['active'] as Json;
    final ai = j['ai'] as Json;
    final p = j['points'] as Json;
    return Overview(
      days: _i(j['days']),
      from: j['from'] as String,
      to: j['to'] as String,
      accounts: _i(a['total']),
      newAccounts: _i(a['new']),
      suspended: _i(a['suspended']),
      admins: _i(a['admins']),
      demo: _i(a['demo']),
      activeNow: _i(act['now']),
      activeDay: _i(act['day']),
      activeWeek: _i(act['week']),
      activeMonth: _i(act['month']),
      jobs: _i(ai['jobs']),
      deliveredJobs: _i(ai['delivered_jobs']),
      inputTokens: _i(ai['input_tokens']),
      outputTokens: _i(ai['output_tokens']),
      tokens: _i(ai['tokens']),
      costUsd: _d(ai['cost_usd']),
      money: Money.fromJson(j['money'] as Json),
      pointsSold: _i(p['sold']),
      pointsGranted: _i(p['granted']),
      pointsUsed: _i(p['used']),
      pointsOutstanding: _i(p['outstanding']),
      previous: j['previous'] == null ? null : Previous.fromJson(j['previous'] as Json),
    );
  }
  final int days;
  final String from;
  final String to;
  final int accounts;
  final int newAccounts;
  final int suspended;
  final int admins;
  final int demo;
  final int activeNow;
  final int activeDay;
  final int activeWeek;
  final int activeMonth;
  final int jobs;
  final int deliveredJobs;
  final int inputTokens;
  final int outputTokens;
  final int tokens;
  final double costUsd;
  final Money money;
  final int pointsSold;
  final int pointsGranted;
  final int pointsUsed;
  final int pointsOutstanding;

  /// The period before, summed alike (v12.3.0): what the changes are measured against; null from an older server.
  final Previous? previous;
}

/// The days before the period, as many, with the period's sums (v12.3.0).
class Previous {
  const Previous({
    required this.from,
    required this.to,
    required this.newAccounts,
    required this.jobs,
    required this.tokens,
    required this.costUsd,
    required this.money,
    required this.pointsSold,
    required this.pointsGranted,
    required this.pointsUsed,
  });
  factory Previous.fromJson(Json j) {
    final ai = j['ai'] as Json;
    final p = j['points'] as Json;
    return Previous(
      from: j['from'] as String,
      to: j['to'] as String,
      newAccounts: _i((j['accounts'] as Json)['new']),
      jobs: _i(ai['jobs']),
      tokens: _i(ai['tokens']),
      costUsd: _d(ai['cost_usd']),
      money: Money.fromJson(j['money'] as Json),
      pointsSold: _i(p['sold']),
      pointsGranted: _i(p['granted']),
      pointsUsed: _i(p['used']),
    );
  }
  final String from;
  final String to;
  final int newAccounts;
  final int jobs;
  final int tokens;
  final double costUsd;
  final Money money;
  final int pointsSold;
  final int pointsGranted;
  final int pointsUsed;
}

/// One day of the period (the revenue curve's points).
class DayRow {
  const DayRow({
    required this.day,
    required this.newAccounts,
    required this.activeAccounts,
    required this.jobs,
    required this.inputTokens,
    required this.outputTokens,
    required this.tokens,
    required this.money,
    required this.pointsSold,
    required this.pointsGranted,
    required this.pointsUsed,
  });
  factory DayRow.fromJson(Json j) => DayRow(
        day: j['day'] as String,
        newAccounts: _i(j['new_accounts']),
        activeAccounts: _i(j['active_accounts']),
        jobs: _i(j['jobs']),
        inputTokens: _i(j['input_tokens']),
        outputTokens: _i(j['output_tokens']),
        tokens: _i(j['tokens']),
        money: Money.fromJson(j),
        pointsSold: _i(j['points_sold']),
        pointsGranted: _i(j['points_granted']),
        pointsUsed: _i(j['points_used']),
      );
  final String day;
  final int newAccounts;
  final int activeAccounts;
  final int jobs;
  final int inputTokens;
  final int outputTokens;
  final int tokens;
  final Money money;
  final int pointsSold;
  final int pointsGranted;
  final int pointsUsed;
}

class MethodRow {
  const MethodRow({required this.kind, this.system, required this.jobs, required this.tokens, required this.cost, required this.pointsUsed});
  factory MethodRow.fromJson(Json j) => MethodRow(
        kind: j['kind'] as String,
        system: j['system'] as String?,
        jobs: _i(j['jobs']),
        tokens: _i(j['tokens']),
        cost: _d(j['cost_cny']),
        pointsUsed: _i(j['points_used']),
      );
  final String kind;
  final String? system;
  final int jobs;
  final int tokens;
  final double cost;
  final int pointsUsed;
}

class ModelRow {
  const ModelRow({required this.model, required this.jobs, required this.inputTokens, required this.outputTokens, required this.tokens, required this.cost});
  factory ModelRow.fromJson(Json j) => ModelRow(
        model: j['model'] as String,
        jobs: _i(j['jobs']),
        inputTokens: _i(j['input_tokens']),
        outputTokens: _i(j['output_tokens']),
        tokens: _i(j['tokens']),
        cost: _d(j['cost_cny']),
      );
  final String model;
  final int jobs;
  final int inputTokens;
  final int outputTokens;
  final int tokens;
  final double cost;
}

class Breakdown {
  const Breakdown(this.byMethod, this.byModel);
  factory Breakdown.fromJson(Json j) =>
      Breakdown(_list(j['byMethod'], MethodRow.fromJson), _list(j['byModel'], ModelRow.fromJson));
  final List<MethodRow> byMethod;
  final List<ModelRow> byModel;
}

/// An account as the 用户 table lists it; the sums are all time.
class AdminUser {
  const AdminUser({
    required this.id,
    required this.login,
    required this.country,
    required this.admin,
    required this.adminByConfig,
    required this.suspended,
    required this.ai,
    required this.topUpAllowed,
    required this.demo,
    required this.createdAt,
    this.lastSeenAt,
    required this.balance,
    required this.held,
    required this.topup,
    required this.pointsUsed,
    required this.jobs,
    required this.tokens,
    required this.cost,
  });
  factory AdminUser.fromJson(Json j) {
    final p = j['permissions'] as Json? ?? const {};
    return AdminUser(
      id: j['id'] as String,
      login: j['login'] as String,
      country: j['country'] as String? ?? '',
      admin: j['role'] == 'admin',
      adminByConfig: j['admin_by_config'] == true,
      suspended: j['status'] == 'suspended',
      ai: p['ai'] != false,
      topUpAllowed: p['top_up'] != false,
      demo: j['demo'] == true,
      createdAt: DateTime.parse(j['created_at'] as String),
      lastSeenAt: j['last_seen_at'] == null ? null : DateTime.parse(j['last_seen_at'] as String),
      balance: _i(j['balance']),
      held: _i(j['held']),
      topup: _d(j['topup_cny']),
      pointsUsed: _i(j['points_used']),
      jobs: _i(j['jobs']),
      tokens: _i(j['tokens']),
      cost: _d(j['cost_cny']),
    );
  }
  final String id;
  final String login;
  final String country;
  final bool admin;
  final bool adminByConfig;
  final bool suspended;
  final bool ai;
  final bool topUpAllowed;
  final bool demo;
  final DateTime createdAt;
  final DateTime? lastSeenAt;
  final int balance;
  final int held;
  final double topup;
  final int pointsUsed;
  final int jobs;
  final int tokens;
  final double cost;
}

/// The 用户 table's search, filters, sorting and page.
class UserQuery {
  const UserQuery({this.q = '', this.status, this.role, this.demo = 'include', this.sort = 'created', this.asc = false, this.page = 1, this.perPage = 25});
  final String q;
  final String? status;
  final String? role;
  final String demo;
  final String sort;
  final bool asc;
  final int page;
  final int perPage;

  UserQuery copyWith({String? q, String? Function()? status, String? Function()? role, String? demo, String? sort, bool? asc, int? page}) => UserQuery(
        q: q ?? this.q,
        status: status == null ? this.status : status(),
        role: role == null ? this.role : role(),
        demo: demo ?? this.demo,
        sort: sort ?? this.sort,
        asc: asc ?? this.asc,
        page: page ?? this.page,
        perPage: perPage,
      );

  String get query => Uri(queryParameters: {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        'status': ?status,
        'role': ?role,
        'demo': demo,
        'sort': sort,
        'order': asc ? 'asc' : 'desc',
        'page': '$page',
        'per_page': '$perPage',
      }).query;

  @override
  bool operator ==(Object other) => other is UserQuery && other.query == query;

  @override
  int get hashCode => query.hashCode;
}

class UserPage {
  const UserPage({required this.total, required this.page, required this.pages, required this.items});
  factory UserPage.fromJson(Json j) =>
      UserPage(total: _i(j['total']), page: _i(j['page']), pages: _i(j['pages']), items: _list(j['items'], AdminUser.fromJson));
  final int total;
  final int page;
  final int pages;
  final List<AdminUser> items;
}

/// One 积分 change, as an admin sees it (with its cost and its note).
class LedgerEntry {
  const LedgerEntry({
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
    this.note,
  });
  factory LedgerEntry.fromJson(Json j) {
    final f = j['for'] as Json?;
    return LedgerEntry(
      kind: j['kind'] as String,
      points: _i(j['points']),
      balance: _i(j['balance']),
      createdAt: DateTime.parse(j['created_at'] as String),
      forKind: f?['kind'] as String?,
      system: f?['system'] as String?,
      basis: j['basis'] as String?,
      usd: (j['usd'] as num?)?.toDouble(),
      packYuan: (j['pack'] as Json?)?['yuan'] as int?,
      reason: j['reason'] as String?,
      note: j['note'] as String?,
    );
  }
  final String kind;
  final int points;
  final int balance;
  final DateTime createdAt;
  final String? forKind;
  final String? system;
  final String? basis;
  final double? usd;
  final int? packYuan;
  final String? reason;
  final String? note;
}

class JobRow {
  const JobRow({required this.createdAt, required this.kind, this.system, required this.models, required this.tokens, required this.cost, required this.delivered});
  factory JobRow.fromJson(Json j) => JobRow(
        createdAt: DateTime.parse(j['created_at'] as String),
        kind: j['kind'] as String,
        system: j['system'] as String?,
        models: [for (final m in (j['models'] as List? ?? const [])) m as String],
        tokens: _i(j['tokens']),
        cost: _d(j['cost_cny']),
        delivered: j['delivered'] == true,
      );
  final DateTime createdAt;
  final String kind;
  final String? system;
  final List<String> models;
  final int tokens;
  final double cost;
  final bool delivered;
}

class UserDetail {
  const UserDetail({required this.user, required this.entries, required this.jobs, required this.byMethod});
  factory UserDetail.fromJson(Json j) => UserDetail(
        user: AdminUser.fromJson(j['user'] as Json),
        entries: _list(j['entries'], LedgerEntry.fromJson),
        jobs: _list(j['jobs'], JobRow.fromJson),
        byMethod: _list(j['by_method'], MethodRow.fromJson),
      );
  final AdminUser user;
  final List<LedgerEntry> entries;
  final List<JobRow> jobs;
  final List<MethodRow> byMethod;
}

class Active {
  const Active({required this.now, required this.day, required this.inNow, required this.inDay, required this.inWeek, required this.inMonth});
  factory Active.fromJson(Json j) {
    final c = j['counts'] as Json;
    return Active(
      now: _list(j['now'], AdminUser.fromJson),
      day: _list(j['day'], AdminUser.fromJson),
      inNow: _i(c['now']),
      inDay: _i(c['day']),
      inWeek: _i(c['week']),
      inMonth: _i(c['month']),
    );
  }

  /// Who made a request in the last 15 minutes, and in the last 24 hours, the most recent first.
  final List<AdminUser> now;
  final List<AdminUser> day;
  final int inNow;
  final int inDay;
  final int inWeek;
  final int inMonth;
}
