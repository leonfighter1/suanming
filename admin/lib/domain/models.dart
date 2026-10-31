// What the admin API returns (管理后台, tech plan S22; api/openapi.yaml, tag admin). Money is in 元.

typedef Json = Map<String, dynamic>;

int _i(Object? v) => (v as num?)?.toInt() ?? 0;
double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
List<T> _list<T>(Object? v, T Function(Json) f) => [for (final e in (v as List? ?? const [])) f(e as Json)];

/// What a staff role may do (tech plan S25; the server's src/admin/roles.ts): see the numbers and the accounts, give
/// roles and permissions, change or take a user's data (增加积分, 在所有设备上退出, the exports), the mail and SMS, and
/// the app's texts and images (内容管理, S29).
abstract final class Can {
  static const view = 'view';
  static const assign = 'assign';
  static const userData = 'user_data';
  static const messages = 'messages';
  static const content = 'content';
  static const settings = 'settings';

  /// What an admin could do on a server from before roles (and before 内容管理).
  static const all = {view, assign, userData, messages};
}

/// The signed-in staff member: their role (admin, manager or integrator), what it may do and the roles it may give.
class AdminMe {
  const AdminMe({
    required this.id,
    required this.login,
    required this.adminByConfig,
    this.role = 'admin',
    this.can = Can.all,
    this.assignableRoles = const [],
    this.currency = MoneyUnit.yuan,
  });
  factory AdminMe.fromJson(Json j) => AdminMe(
        id: j['id'] as String,
        login: j['login'] as String,
        adminByConfig: j['admin_by_config'] == true,
        // A server before roles let admins in only.
        role: j['role'] as String? ?? 'admin',
        can: j['can'] == null ? Can.all : {for (final c in j['can'] as List) c as String},
        assignableRoles: [for (final r in (j['assignable_roles'] as List? ?? const [])) r as String],
        currency: j['currency'] == null ? MoneyUnit.yuan : MoneyUnit.fromJson(j['currency'] as Json),
      );
  final String id;
  final String login;

  /// Named in the server's MINGLI_ADMINS: an admin whatever the dashboard does.
  final bool adminByConfig;
  final String role;

  /// [Can]'s: what the role may do. The server decides; the dashboard only leaves out what it would refuse.
  final Set<String> can;

  /// The roles this staff member may give an account (user, integrator, manager, admin).
  final List<String> assignableRoles;

  /// The currency the dashboard shows money in (设置, S31).
  final MoneyUnit currency;
}

/// The currency the dashboard shows money in (设置's currencies.dashboard, S31): its symbol and decimals, and today's
/// rate from the server's 元 (1 元 = rate of it).
class MoneyUnit {
  const MoneyUnit({required this.code, required this.symbol, required this.decimals, required this.rate, this.ratesDate});
  factory MoneyUnit.fromJson(Json j) => MoneyUnit(
        code: j['code'] as String,
        symbol: j['symbol'] as String,
        decimals: _i(j['decimals']),
        rate: _d(j['rate']),
        ratesDate: j['rates_date'] as String?,
      );
  static const yuan = MoneyUnit(code: 'CNY', symbol: '¥', decimals: 2, rate: 1);
  final String code;
  final String symbol;
  final int decimals;
  final double rate;
  final String? ratesDate;
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
    this.role = 'user',
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
      role: j['role'] as String? ?? 'user',
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

  /// user, integrator, manager or admin (tech plan S25).
  final String role;
  bool get admin => role == 'admin';
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

// ---- 消息 (tech plan S25): the mail and SMS the server sends, their wordings, previews and dispatches ----

/// A value a message's wording may use as `{{name}}`: what it is and the sample a preview fills in. A [part] (a
/// report, a list of records) stands on a line of its own in the body.
class TemplateVariable {
  const TemplateVariable({required this.name, required this.about, required this.sample, this.part = false});
  factory TemplateVariable.fromJson(Json j) => TemplateVariable(
        name: j['name'] as String,
        about: j['about'] as String? ?? '',
        sample: j['sample'] as String? ?? '',
        part: j['part'] == true,
      );
  final String name;
  final String about;
  final String sample;
  final bool part;
}

/// A message's wording in one language: the one in use (an admin's when [custom], else the default) and the default.
class TemplateWording {
  const TemplateWording({
    required this.locale,
    this.subject,
    required this.body,
    required this.custom,
    this.updatedAt,
    this.defaultSubject,
    required this.defaultBody,
  });
  factory TemplateWording.fromJson(Json j) {
    final d = j['default'] as Json? ?? const {};
    return TemplateWording(
      locale: j['locale'] as String,
      subject: j['subject'] as String?,
      body: j['body'] as String? ?? '',
      custom: j['custom'] == true,
      updatedAt: j['updated_at'] == null ? null : DateTime.parse(j['updated_at'] as String),
      defaultSubject: d['subject'] as String?,
      defaultBody: d['body'] as String? ?? '',
    );
  }

  /// zh-Hans, zh-Hant or en.
  final String locale;

  /// A mail's; an SMS has none.
  final String? subject;
  final String body;
  final bool custom;
  final DateTime? updatedAt;
  final String? defaultSubject;
  final String defaultBody;
}

/// A message the server sends (邮箱验证码, 报告邮件, …): its channel, what it is, its values and each language's wording.
class MessageTemplate {
  const MessageTemplate({
    required this.kind,
    required this.channel,
    required this.name,
    required this.about,
    required this.variables,
    required this.required,
    required this.locales,
  });
  factory MessageTemplate.fromJson(Json j) => MessageTemplate(
        kind: j['kind'] as String,
        channel: j['channel'] as String,
        name: j['name'] as String,
        about: j['about'] as String? ?? '',
        variables: _list(j['variables'], TemplateVariable.fromJson),
        required: [for (final r in (j['required'] as List? ?? const [])) r as String],
        locales: _list(j['locales'], TemplateWording.fromJson),
      );

  /// code_mail, code_sms, report_mail, records_mail.
  final String kind;

  /// mail or sms.
  final String channel;
  final String name;

  /// When it goes out.
  final String about;
  final List<TemplateVariable> variables;

  /// The values its wording must use ({{code}}, {{report}}).
  final List<String> required;
  final List<TemplateWording> locales;

  bool get mail => channel == 'mail';

  TemplateWording wording(String locale) => locales.firstWhere((w) => w.locale == locale, orElse: () => locales.first);
}

/// Every message, and what delivers each channel: outbox (the dev outbox, no provider yet), off (nothing on this
/// server), memory (a test's).
class MessageListing {
  const MessageListing({required this.templates, required this.mail, required this.sms});
  factory MessageListing.fromJson(Json j) {
    final d = j['delivery'] as Json? ?? const {};
    return MessageListing(
      templates: _list(j['templates'], MessageTemplate.fromJson),
      mail: d['mail'] as String? ?? 'off',
      sms: d['sms'] as String? ?? 'off',
    );
  }
  final List<MessageTemplate> templates;
  final String mail;
  final String sms;

  MessageTemplate? byKind(String kind) => templates.where((t) => t.kind == kind).firstOrNull;
}

/// A wording with the sample values, as its reader gets it: a mail's subject, page and text; an SMS's text, its
/// length and the messages it takes; and what is wrong with the wording (nothing when it can be kept).
class MessagePreview {
  const MessagePreview({this.subject, this.html, required this.text, this.length, this.segments, this.problems = const []});
  factory MessagePreview.fromJson(Json j) {
    final s = j['sms'] as Json?;
    return MessagePreview(
      subject: j['subject'] as String?,
      html: j['html'] as String?,
      text: j['text'] as String? ?? '',
      length: s == null ? null : _i(s['length']),
      segments: s == null ? null : _i(s['segments']),
      problems: [for (final p in (j['problems'] as List? ?? const [])) p as String],
    );
  }
  final String? subject;
  final String? html;
  final String text;
  final int? length;
  final int? segments;
  final List<String> problems;
}

/// One message as the server's log keeps it: when, which, to whom (masked), and how it went.
class DispatchEntry {
  const DispatchEntry({
    required this.id,
    required this.at,
    required this.kind,
    required this.channel,
    required this.locale,
    required this.to,
    this.subject,
    required this.status,
    required this.transport,
    required this.custom,
    this.test = false,
    this.error,
  });
  factory DispatchEntry.fromJson(Json j) => DispatchEntry(
        id: j['id'] as String,
        at: DateTime.parse(j['at'] as String),
        kind: j['kind'] as String,
        channel: j['channel'] as String,
        locale: j['locale'] as String,
        to: j['to'] as String? ?? '',
        subject: j['subject'] as String?,
        status: j['status'] as String,
        transport: j['transport'] as String? ?? '',
        custom: j['custom'] == true,
        test: j['test'] == true,
        error: j['error'] as String?,
      );
  final String id;
  final DateTime at;
  final String kind;
  final String channel;
  final String locale;
  final String to;
  final String? subject;

  /// sent, off (no way to send it on this server) or failed.
  final String status;
  final String transport;
  final bool custom;
  final bool test;
  final String? error;
}

/// 内容管理 (tech plan S29): a text the app shows, as staff can change it: the placeholders the app fills in ({balance}
/// …), its own wording in each language, and staff's where they changed it.
class ContentText {
  const ContentText({required this.key, required this.placeholders, required this.defaults, this.changed = const {}});
  factory ContentText.fromJson(Json j) => ContentText(
        key: j['key'] as String,
        placeholders: [for (final p in (j['placeholders'] as List? ?? const [])) p as String],
        defaults: {for (final MapEntry(:key, :value) in (j['defaults'] as Json).entries) key: value as String},
        changed: {
          for (final MapEntry(:key, :value) in (j['changed'] as Json? ?? const {}).entries)
            key: (value as Json)['text'] as String,
        },
      );

  /// The app's key for it (homeTarot …).
  final String key;
  final List<String> placeholders;

  /// The app's own wording, by language (zh-Hans, zh-Hant).
  final Map<String, String> defaults;

  /// Staff's wording, by language, where they changed it.
  final Map<String, String> changed;

  /// What the app shows in [locale]: staff's wording, else its own.
  String textIn(String locale) => changed[locale] ?? defaults[locale] ?? '';
}

/// An image the app takes from here (the banners' art, the introduction page's mark), and staff's once one was put in.
class ContentImage {
  const ContentImage({required this.key, required this.label, this.url});
  factory ContentImage.fromJson(Json j) =>
      ContentImage(key: j['key'] as String, label: j['label'] as String? ?? '', url: j['url'] as String?);
  final String key;
  final String label;

  /// Staff's image's address on the server (/v1/content/images/banner?v=…); null while the app shows its own.
  final String? url;
}

/// Everything 内容 lists: the languages, what an image may be, the texts and the images.
class ContentListing {
  const ContentListing({
    required this.locales,
    required this.imageTypes,
    required this.imageMaxBytes,
    required this.texts,
    required this.images,
  });
  factory ContentListing.fromJson(Json j) => ContentListing(
        locales: [for (final l in j['locales'] as List) l as String],
        imageTypes: [for (final t in (j['image_types'] as List? ?? const [])) t as String],
        imageMaxBytes: _i(j['image_max_bytes']),
        texts: _list(j['texts'], ContentText.fromJson),
        images: _list(j['images'], ContentImage.fromJson),
      );
  final List<String> locales;

  /// The types an image may be (image/png …), and its largest size.
  final List<String> imageTypes;
  final int imageMaxBytes;
  final List<ContentText> texts;
  final List<ContentImage> images;
}

/// 设置 (tech plan S31): a setting as the 管理后台 shows it: what it is, its range or choices, its value now, its default
/// (and the env variable it comes from, when set), and when the panel changed it.
class SettingView {
  const SettingView({
    required this.key,
    required this.group,
    required this.type,
    required this.label,
    required this.about,
    this.unit,
    this.min,
    this.max,
    this.integer = false,
    this.optional = false,
    this.options = const [],
    this.env,
    this.value,
    this.defaultValue,
    this.changedAt,
  });
  factory SettingView.fromJson(Json j) => SettingView(
        key: j['key'] as String,
        group: j['group'] as String,
        type: j['type'] as String,
        label: j['label'] as String,
        about: j['about'] as String? ?? '',
        unit: j['unit'] as String?,
        min: (j['min'] as num?)?.toDouble(),
        max: (j['max'] as num?)?.toDouble(),
        integer: j['integer'] == true,
        optional: j['optional'] == true,
        options: [for (final o in (j['options'] as List? ?? const [])) o as String],
        env: j['env'] as String?,
        value: j['value'],
        defaultValue: j['default'],
        changedAt: j['changed'] == null ? null : DateTime.parse((j['changed'] as Json)['updated_at'] as String),
      );

  /// group.name (sessions.idle_days …).
  final String key;

  /// sessions, ai, limits or currencies.
  final String group;

  /// number, boolean, choice or choices.
  final String type;
  final String label;
  final String about;
  final String? unit;
  final double? min;
  final double? max;
  final bool integer;

  /// May be unset (null): the AI switches, which then follow .env.
  final bool optional;
  final List<String> options;
  final String? env;
  final Object? value;
  final Object? defaultValue;
  final DateTime? changedAt;

  bool get changed => changedAt != null;
}

/// Every setting, what answers AI calls now, and which day's rates 充值 uses.
class SettingsListing {
  const SettingsListing({required this.settings, this.serving, this.models, this.ratesDate, this.ratesStale = false});
  factory SettingsListing.fromJson(Json j) {
    final ai = j['ai'] as Json?;
    final rates = j['rates'] as Json?;
    return SettingsListing(
      settings: _list(j['settings'], SettingView.fromJson),
      serving: ai?['serving'] as String?,
      models: ai?['models'] as String?,
      ratesDate: rates?['date'] as String?,
      ratesStale: rates?['stale'] == true,
    );
  }
  final List<SettingView> settings;

  /// A provider's name, or mock.
  final String? serving;
  final String? models;
  final String? ratesDate;
  final bool ratesStale;
}
