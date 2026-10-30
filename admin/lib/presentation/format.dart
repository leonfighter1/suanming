import 'package:intl/intl.dart';

// How the dashboard writes its numbers and names (管理后台, tech plan S22): 简体, money in 元.

final _yuan = NumberFormat('#,##0.00');
final _count = NumberFormat('#,##0');

/// Money in 元: ¥1,234.50, a loss -¥14.97.
String yuan(num v) => v < 0 ? '-¥${_yuan.format(-v)}' : '¥${_yuan.format(v)}';
String count(num v) => _count.format(v);

/// A large count short: 1.2万, 3.4亿.
String compact(num v) => v >= 1e8
    ? '${(v / 1e8).toStringAsFixed(1)}亿'
    : v >= 1e4
        ? '${(v / 1e4).toStringAsFixed(1)}万'
        : count(v);

String percent(double? v) => v == null ? '—' : '${(v * 100).toStringAsFixed(1)}%';
String usd(double v) => '\$${v.toStringAsFixed(2)}';

String localTime(DateTime t) => DateFormat('yyyy-MM-dd HH:mm').format(t.toLocal());
String localDay(DateTime t) => DateFormat('yyyy-MM-dd').format(t.toLocal());

/// How long ago, in a few words: 刚刚, 5 分钟前, 3 小时前, 2 天前.
String ago(DateTime t, DateTime now) {
  final d = now.difference(t);
  if (d.inMinutes < 1) return '刚刚';
  if (d.inHours < 1) return '${d.inMinutes} 分钟前';
  if (d.inDays < 1) return '${d.inHours} 小时前';
  return '${d.inDays} 天前';
}

const methodNames = {
  'bazi': '八字',
  'tarot': '塔罗',
  'qiuqian': '求签',
  'liuyao': '算卦',
  'fengshui': '风水',
  'naming': '起名',
  'astrology': '占星',
};
const kindNames = {
  'report': 'AI 解读',
  'life_report': '一生运势报告',
  'followup': '追问',
  'inquiry': '深度分析',
  'remedy': '破除运势方案',
};

/// What an AI job was: 八字 AI 解读, 塔罗 追问, 一生运势报告.
String whatOf(String kind, String? system) => [
      if (system != null && kind != 'life_report') methodNames[system] ?? system,
      kindNames[kind] ?? kind,
    ].join(' ');

/// What a 积分 change was, as the account's ledger lists it.
String entryOf({required String kind, String? forKind, String? system, int? packYuan, String? reason}) => switch (kind) {
      'topup' => '充值 ${packYuan ?? '?'} 元',
      'grant' => reason == 'dev' ? '开发测试赠送' : (reason ?? '').startsWith('admin') ? '管理员赠送' : '赠送',
      _ => forKind == null ? '消耗' : whatOf(forKind, system),
    };
