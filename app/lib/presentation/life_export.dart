import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../domain/life_report.dart';
import '../l10n/gen/app_localizations.dart';

/// The 项目 / 内容 rows at the top of the report.
class LifeHeader {
  const LifeHeader({
    required this.name,
    required this.gender,
    required this.lunar,
    required this.solar,
    required this.place,
    required this.trueSolar,
    required this.ganzhi,
  });
  final String name;
  final String gender;
  final String lunar;
  final String solar;
  final String place;
  final String trueSolar;
  final String ganzhi;

  List<(String, String)> rows(AppLocalizations l10n) => [
    (l10n.lifeName, '$name（$gender）'),
    (l10n.lifeBirthLunar, lunar),
    (l10n.lifeBirthSolar, solar),
    (l10n.lifeBirthPlace, place),
    (l10n.lifeTrueSolar, trueSolar),
    (l10n.lifeGanzhi, ganzhi),
  ];
}

/// 起卦 steps, from the engine's numbers (never recomputed here).
List<String> qiguaSteps(LifeFacts f, {required bool hant, required String lunarMonth, required String lunarDay}) {
  final s = f.steps;
  final y = s['year_branch'] as Map<String, dynamic>;
  final h = s['hour_branch'] as Map<String, dynamic>;
  String rem(int r, int m) => r == 0 ? '0（作 $m）' : '$r';
  final up = f.trigram(f.hexagram.upper);
  final low = f.trigram(f.hexagram.lower);
  final yu = hant ? '餘' : '余';
  final shi = hant ? '時' : '时';
  final wei = hant ? '為' : '为';
  final bian = hant ? '變' : '变';
  final nums = ['', '初', '二', '三', '四', '五', '上'];
  return [
    '年支${y['zhi']} = ${y['number']}，$lunarMonth = ${s['lunar_month']}，$lunarDay = ${s['lunar_day']}；'
        '${y['number']} + ${s['lunar_month']} + ${s['lunar_day']} = ${s['upper_sum']}，'
        '${s['upper_sum']} ÷ 8 $yu ${rem(s['upper_remainder'] as int, 8)} → 上卦${up.name}（${up.image}）',
    '${h['zhi']}$shi = ${h['number']}；${s['upper_sum']} + ${h['number']} = ${s['lower_sum']}，'
        '${s['lower_sum']} ÷ 8 $yu ${rem(s['lower_remainder'] as int, 8)} → 下卦${low.name}（${low.image}）',
    '${s['lower_sum']} ÷ 6 $yu ${rem(s['moving_remainder'] as int, 6)} → 第${nums[f.movingLine]}爻$wei命爻',
    '得本命卦${f.hexagram.fullName}，${nums[f.movingLine]}爻$bian，之卦${f.changed.fullName}。',
  ];
}

String relationLabel(AppLocalizations l10n, String? r) => switch (r) {
  '比和' => l10n.relBihe,
  '生体' => l10n.relShengti,
  '体生' => l10n.relTisheng,
  '体克' => l10n.relTike,
  '克体' => l10n.relKeti,
  _ => '—',
};

/// 繁體 forms of the engine's fixed 八宅 words (the engine returns 简体).
String hantTerm(String s, bool hant) =>
    !hant ? s : const {'生气': '生氣', '天医': '天醫', '祸害': '禍害', '绝命': '絕命', '东四命': '東四命', '西四命': '西四命'}[s] ?? s;

String topicLabel(AppLocalizations l10n, String key) => switch (key) {
  'personality' => l10n.lifeTopicPersonality,
  'career' => l10n.lifeTopicCareer,
  'wealth' => l10n.lifeTopicWealth,
  'relationships' => l10n.lifeTopicRelationships,
  'children' => l10n.lifeTopicChildren,
  'parents' => l10n.lifeTopicParents,
  'health' => l10n.lifeTopicHealth,
  _ => key,
};

String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _hexHtml(Hexagram h, String caption, {int? moving}) {
  final lines = StringBuffer();
  for (var i = 6; i >= 1; i--) {
    final cls = 'line ${h.yang(i) ? 'yang' : 'yin'}${moving == i ? ' moving' : ''}';
    lines.write('<div class="$cls"><span></span><span></span></div>');
  }
  return '<figure class="hex"><div class="lines">$lines</div><figcaption><b>${_esc(h.fullName)}</b><br>${_esc(caption)}</figcaption></figure>';
}

/// The full report as one styled, printable HTML page (no external assets).
String lifeReportHtml({
  required AppLocalizations l10n,
  required LifeHeader header,
  required LifeReportView report,
  required bool hant,
  required String lunarMonth,
  required String lunarDay,
}) {
  final f = report.facts!;
  final l = report.layers!;
  String t(String s) => _esc(s);
  String p(String s) => '<p>${t(s)}</p>';
  String table(List<String> head, List<List<String>> rows, {String cls = ''}) =>
      '<table class="$cls"><thead><tr>${head.map((h) => '<th>${t(h)}</th>').join()}</tr></thead><tbody>'
      '${rows.map((r) => '<tr>${r.map((c) => '<td>${t(c)}</td>').join()}</tr>').join()}</tbody></table>';
  final ti = f.trigram(f.ti.trigram);
  final b = StringBuffer()
    ..write('<header><h1>${t(l10n.lifeReportOf(header.name))}</h1><div class="sub">${t(l10n.lifeSubtitle)}</div></header>')
    ..write(
      table(
        [l10n.lifeItem, l10n.lifeContent],
        [
          for (final (k, v) in header.rows(l10n)) [k, v],
        ],
        cls: 'info',
      ),
    )
    ..write('<div class="note">${t(l10n.lifeNote)}</div>')
    // 一、易经本命卦
    ..write('<h2>${t(l10n.lifeSec1)}</h2><h3>${t(l10n.lifeQigua)}</h3><ul>')
    ..write(qiguaSteps(f, hant: hant, lunarMonth: lunarMonth, lunarDay: lunarDay).map((s) => '<li>${t(s)}</li>').join())
    ..write('</ul><div class="hexes">')
    ..write(_hexHtml(f.hexagram, l10n.lifeBenGua, moving: f.movingLine))
    ..write(_hexHtml(f.nuclear, l10n.lifeHuGua))
    ..write(_hexHtml(f.changed, l10n.lifeZhiGuaShort))
    ..write('</div>')
    ..write('<h3>${t(l10n.lifeGuaYi)}</h3><blockquote>${t(f.hexagram.guaCi)}</blockquote>${p(l.yijingText('meaning'))}')
    ..write('<h3>${t(l10n.lifeMingYao)}</h3><blockquote>${t(f.lines[f.movingLine - 1].text)}</blockquote>${p(l.yijingText('ming_yao'))}')
    ..write('<h3>${t(l10n.lifeZhiGua)}</h3><blockquote>${t(f.changed.guaCi)}</blockquote>${p(l.yijingText('zhi_gua'))}')
    ..write('<h3>${t(l10n.lifeSixLines)}</h3>')
    ..write(
      table(
        [l10n.lifeLine, l10n.lifeAge, l10n.lifeYaoCi, l10n.lifeForLife],
        [
          for (final x in f.lines)
            [
              x.position + (x.moving ? '（${l10n.lifeMingYao}）' : ''),
              x.ages,
              x.text.split(RegExp('[：:]')).skip(1).join('：'),
              l.stageReading(x.line),
            ],
        ],
      ),
    )
    // 二、梅花易数
    ..write('<h2>${t(l10n.lifeSec2)}</h2>')
    ..write(
      table(
        [l10n.lifeMhGua, l10n.lifeMhName, l10n.lifeWuxing, l10n.lifeMhRel, l10n.lifeMhStage],
        [
          [l10n.lifeTi, '${ti.name}（${ti.image}）', f.ti.wuxing, l10n.lifeSelf, '—'],
          [l10n.lifeYong, f.trigram(f.yong.trigram).name, f.yong.wuxing, relationLabel(l10n, f.yong.relation), l10n.lifeEarly],
          for (final h in f.hu) [l10n.lifeHu, f.trigram(h.trigram).name, h.wuxing, relationLabel(l10n, h.relation), l10n.lifeMiddle],
          [l10n.lifeBian, f.trigram(f.bian.trigram).name, f.bian.wuxing, relationLabel(l10n, f.bian.relation), l10n.lifeLate],
        ],
      ),
    )
    ..write('<p><b>${t(l10n.lifeSeason)}：</b>${t(l.meihua['season'] as String)}</p><ul>')
    ..write('<li><b>${t(l10n.lifeEarly)}：</b>${t(l.meihua['early'] as String)}</li>')
    ..write('<li><b>${t(l10n.lifeMiddle)}：</b>${t(l.meihua['middle'] as String)}</li>')
    ..write('<li><b>${t(l10n.lifeLate)}：</b>${t(l.meihua['late'] as String)}</li></ul>')
    ..write('<p class="key"><b>${t(l10n.lifeMhConclusion)}：</b>${t(l.meihua['conclusion'] as String)}</p>')
    // 三、五行八卦
    ..write('<h2>${t(l10n.lifeSec3)}</h2>${p(l.wuxing['analysis'] as String)}')
    ..write(
      '<p><b>${t(l10n.lifeFavorable)}：</b>${t(l.favorable().join('、'))}　<b>${t(l10n.lifeUnfavorable)}：</b>${t(l.unfavorable().join('、'))}</p>',
    )
    ..write('<p class="small">${t(l.wuxing['note'] as String)}</p>')
    ..write(
      '<h3>${t(l10n.lifeBazhai)}</h3><p>${t(l10n.lifeKua('${f.kua}', f.trigram(f.kuaTrigram).name, hantTerm(f.kuaGroup, hant), f.kuaWuxing))}</p>${p(l.bazhai['summary'] as String)}',
    )
    ..write(
      table(
        [l10n.lifeDirection, l10n.lifeStar, l10n.lifeLuck],
        [
          for (final d in f.directions) ['${d.direction}（${f.trigram(d.trigram).name}）', hantTerm(d.star, hant), d.luck],
        ],
      ),
    )
    ..write('<p><b>${t(l10n.lifeDaily)}：</b>${t(l.bazhai['daily'] as String)}</p>')
    // 四、分项运势
    ..write('<h2>${t(l10n.lifeSec4)}</h2>');
  for (final topic in l.topics) {
    b.write('<h3>${t(topicLabel(l10n, topic.key))}</h3><p class="key">${t(topic.summary)}</p><ul>');
    for (final (period, text) in topic.points) {
      b.write('<li>${period.isEmpty ? '' : '<b>${t(period)}：</b>'}${t(text)}</li>');
    }
    b.write('</ul>');
  }
  final best = l.stages.isEmpty ? null : l.stages.reduce((a, c) => c.score > a.score ? c : a);
  b
    ..write('<h2>${t(l10n.lifeSec5)}</h2>')
    ..write(
      table(
        [l10n.lifeAge, l10n.lifeYears, l10n.lifeFortune, l10n.lifeFocus],
        [
          for (final s in l.stages) [s.ages, '${s.years}（${s.ganzhi}）', '${identical(s, best) ? '★ ' : ''}${s.label}（${s.score}）', s.focus],
        ],
      ),
    )
    ..write('<h2>${t(l10n.lifeSec6)}</h2>${p(l.verdict)}<ul>')
    ..write(l.advice.map((a) => '<li><b>${t(a.$1)}：</b>${t(a.$2)}</li>').join())
    ..write('</ul><p class="key">${t(l.closing)}</p>')
    ..write('<footer>${t(l.disclaimer)}<br>${t(l.aiLabel)}${report.model == null ? '' : ' (${t(report.model!)})'}</footer>');

  return '<!doctype html><html lang="${hant ? 'zh-Hant' : 'zh-CN'}"><head><meta charset="utf-8">'
      '<meta name="viewport" content="width=device-width, initial-scale=1">'
      '<title>${t(l10n.lifeReportOf(header.name))}</title><style>$_css</style></head><body><main>$b</main></body></html>';
}

const _css = '''
:root{--ink:#2b2622;--muted:#6f655c;--accent:#9c2f24;--line:#e6dcd0;--paper:#fffdf8;--soft:#f6efe4}
*{box-sizing:border-box}body{margin:0;background:#efe8dc;color:var(--ink);font:16px/1.85 "Noto Serif SC","Source Han Serif SC","Songti SC","SimSun","Noto Serif TC","PMingLiU",serif}
main{max-width:860px;margin:24px auto;background:var(--paper);padding:48px 56px;border-radius:6px;box-shadow:0 8px 32px rgba(60,40,20,.12)}
header{text-align:center;border-bottom:2px solid var(--accent);padding-bottom:16px;margin-bottom:24px}
h1{font-size:30px;margin:0;letter-spacing:.08em}.sub{color:var(--muted);margin-top:6px;letter-spacing:.2em}
h2{color:var(--accent);font-size:22px;margin:40px 0 12px;padding-bottom:6px;border-bottom:1px solid var(--line)}
h3{font-size:18px;margin:24px 0 8px}p{margin:8px 0;text-align:left}ul{padding-left:1.4em}li{margin:6px 0}
table{width:100%;border-collapse:collapse;margin:12px 0;font-size:15px;page-break-inside:avoid}
th,td{border:1px solid var(--line);padding:8px 10px;text-align:left;vertical-align:top}th{background:var(--soft);font-weight:600}
table.info td:first-child{width:9em;color:var(--muted)}
blockquote{margin:10px 0;padding:10px 16px;background:var(--soft);border-left:4px solid var(--accent);font-weight:600}
.note{background:var(--soft);padding:12px 16px;border-radius:6px;color:var(--muted);font-size:14px}
.key{font-weight:600}.small{color:var(--muted);font-size:14px}
.hexes{display:flex;gap:28px;justify-content:center;flex-wrap:wrap;margin:16px 0}
.hex{margin:0;text-align:center}.lines{display:flex;flex-direction:column;gap:7px;width:110px;margin:0 auto 8px}
.line{display:flex;gap:14px;height:12px}.line span{flex:1;background:var(--ink);border-radius:2px}
.line.yang span:last-child{display:none}.line.moving span{background:var(--accent)}
figcaption{font-size:14px;color:var(--muted)}figcaption b{color:var(--ink);font-size:16px}
footer{margin-top:40px;padding-top:12px;border-top:1px solid var(--line);color:var(--muted);font-size:13px}
@page{size:A4;margin:16mm}@media print{body{background:#fff}main{box-shadow:none;margin:0;padding:0;max-width:none}h2{page-break-after:avoid}}
@media (max-width:600px){main{padding:24px 18px;margin:0;border-radius:0}h1{font-size:24px}}
''';

/// Plain-text copy of the same report.
String lifeReportMarkdown({
  required AppLocalizations l10n,
  required LifeHeader header,
  required LifeReportView report,
  required bool hant,
  required String lunarMonth,
  required String lunarDay,
}) {
  final f = report.facts!;
  final l = report.layers!;
  final b = StringBuffer()
    ..writeln('# ${l10n.lifeReportOf(header.name)}')
    ..writeln()
    ..writeln(l10n.lifeSubtitle)
    ..writeln()
    ..writeln('| ${l10n.lifeItem} | ${l10n.lifeContent} |')
    ..writeln('|---|---|');
  for (final (k, v) in header.rows(l10n)) {
    b.writeln('| $k | $v |');
  }
  b
    ..writeln()
    ..writeln('> ${l10n.lifeNote}')
    ..writeln()
    ..writeln('## ${l10n.lifeSec1}')
    ..writeln()
    ..writeln('### ${l10n.lifeQigua}');
  for (final s in qiguaSteps(f, hant: hant, lunarMonth: lunarMonth, lunarDay: lunarDay)) {
    b.writeln('- $s');
  }
  b
    ..writeln()
    ..writeln('### ${l10n.lifeGuaYi}')
    ..writeln()
    ..writeln('> ${f.hexagram.guaCi}')
    ..writeln()
    ..writeln(l.yijingText('meaning'))
    ..writeln()
    ..writeln('### ${l10n.lifeMingYao}')
    ..writeln()
    ..writeln('> ${f.lines[f.movingLine - 1].text}')
    ..writeln()
    ..writeln(l.yijingText('ming_yao'))
    ..writeln()
    ..writeln('### ${l10n.lifeZhiGua}')
    ..writeln()
    ..writeln(l.yijingText('zhi_gua'))
    ..writeln()
    ..writeln('### ${l10n.lifeSixLines}')
    ..writeln()
    ..writeln('| ${l10n.lifeLine} | ${l10n.lifeAge} | ${l10n.lifeYaoCi} | ${l10n.lifeForLife} |')
    ..writeln('|---|---|---|---|');
  for (final x in f.lines) {
    b.writeln('| ${x.position}${x.moving ? '★' : ''} | ${x.ages} | ${x.text} | ${l.stageReading(x.line)} |');
  }
  b
    ..writeln()
    ..writeln('## ${l10n.lifeSec2}')
    ..writeln()
    ..writeln('- ${l10n.lifeSeason}：${l.meihua['season']}')
    ..writeln('- ${l10n.lifeEarly}（${relationLabel(l10n, f.yong.relation)}）：${l.meihua['early']}')
    ..writeln('- ${l10n.lifeMiddle}：${l.meihua['middle']}')
    ..writeln('- ${l10n.lifeLate}（${relationLabel(l10n, f.bian.relation)}）：${l.meihua['late']}')
    ..writeln()
    ..writeln('**${l10n.lifeMhConclusion}**：${l.meihua['conclusion']}')
    ..writeln()
    ..writeln('## ${l10n.lifeSec3}')
    ..writeln()
    ..writeln(l.wuxing['analysis'])
    ..writeln()
    ..writeln('${l10n.lifeFavorable}：${l.favorable().join('、')}；${l10n.lifeUnfavorable}：${l.unfavorable().join('、')}')
    ..writeln()
    ..writeln('### ${l10n.lifeBazhai}')
    ..writeln()
    ..writeln(l10n.lifeKua('${f.kua}', f.trigram(f.kuaTrigram).name, hantTerm(f.kuaGroup, hant), f.kuaWuxing))
    ..writeln();
  for (final d in f.directions) {
    b.writeln('- ${d.direction}：${hantTerm(d.star, hant)}（${d.luck}）');
  }
  b
    ..writeln()
    ..writeln('${l10n.lifeDaily}：${l.bazhai['daily']}')
    ..writeln()
    ..writeln('## ${l10n.lifeSec4}');
  for (final topic in l.topics) {
    b
      ..writeln()
      ..writeln('### ${topicLabel(l10n, topic.key)}')
      ..writeln()
      ..writeln('**${topic.summary}**');
    for (final (period, text) in topic.points) {
      b.writeln('- ${period.isEmpty ? '' : '$period：'}$text');
    }
  }
  b
    ..writeln()
    ..writeln('## ${l10n.lifeSec5}')
    ..writeln()
    ..writeln('| ${l10n.lifeAge} | ${l10n.lifeYears} | ${l10n.lifeFortune} | ${l10n.lifeFocus} |')
    ..writeln('|---|---|---|---|');
  for (final s in l.stages) {
    b.writeln('| ${s.ages} | ${s.years}（${s.ganzhi}） | ${s.label}（${s.score}） | ${s.focus} |');
  }
  b
    ..writeln()
    ..writeln('## ${l10n.lifeSec6}')
    ..writeln()
    ..writeln(l.verdict)
    ..writeln();
  for (final (area, text) in l.advice) {
    b.writeln('- **$area**：$text');
  }
  b
    ..writeln()
    ..writeln(l.closing)
    ..writeln()
    ..writeln('---')
    ..writeln()
    ..writeln(l.disclaimer)
    ..writeln()
    ..writeln(l.aiLabel);
  return b.toString();
}

/// The download package: the styled HTML (opens anywhere, prints to PDF) and a Markdown copy.
/// Entry names are ASCII so every unzip tool shows them correctly.
Uint8List lifeReportZip({required String html, required String markdown}) {
  final archive = Archive()
    ..addFile(ArchiveFile.bytes('life-report.html', utf8.encode(html)))
    ..addFile(ArchiveFile.bytes('life-report.md', utf8.encode(markdown)))
    ..addFile(
      ArchiveFile.bytes(
        'README.txt',
        utf8.encode('life-report.html: open in a browser; print to save as PDF.\nlife-report.md: plain text.\n'),
      ),
    );
  return ZipEncoder().encodeBytes(archive);
}
