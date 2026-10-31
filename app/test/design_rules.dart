// The ui-design skill's rules as checks over source files (tech plan S24 WP24.2). Not a test by itself:
// app/test/design_rules_test.dart runs it over the app's lib/presentation, admin/test/design_rules_test.dart over the
// 管理后台's lib.
import 'dart:io';

/// One rule: what it forbids, a pattern for one line, and the files allowed to break it (drawn objects, the tokens).
class DesignRule {
  const DesignRule(this.name, this.pattern, {this.allowed = const {}, this.why = ''});
  final String name;
  final RegExp pattern;

  /// File names (not paths) that may break the rule: things drawn as objects, and where the values are defined.
  final Set<String> allowed;
  final String why;
}

/// Files that draw objects (coins, the 签 and its tube, tarot backs, the title's mark): their colours, sizes and corners
/// are the object's own, not the interface's.
const drawings = {'copper_coin.dart', 'qiuqian_stage.dart', 'tarot_spread.dart', 'app_title.dart', 'lot_card.dart'};

final designRules = [
  DesignRule(
    'raw colour',
    RegExp(r'Color\(0x'),
    allowed: {'tokens.dart', 'design.dart', ...drawings},
    why: 'take colours from ThemeTokens or the colour scheme',
  ),
  DesignRule(
    'named colour',
    RegExp(r'Colors\.(?!transparent\b)[a-zA-Z]+'),
    allowed: {...drawings},
    why: 'take colours from ThemeTokens (success, danger …), never Colors.green and the like',
  ),
  DesignRule(
    'brightness check',
    RegExp(r'brightness\s*==|==\s*Brightness\.'),
    allowed: {'theme.dart', 'tokens.dart'},
    why: 'a colour that differs by theme comes from the tokens or ThemeTokens.pick, so it fades with the theme',
  ),
  DesignRule(
    'font size',
    RegExp(r'fontSize:'),
    allowed: {'theme.dart', 'copper_coin.dart', 'qiuqian_stage.dart', 'tarot_spread.dart'},
    why: 'use a role of the type ramp (textTheme)',
  ),
  DesignRule(
    'number in EdgeInsets',
    RegExp(r'EdgeInsets\.\w+\([^)]*(?<![\w.])(?!0(?:\.0)?\b)\d+(?:\.\d+)?\b'),
    allowed: {'copper_coin.dart', 'tarot_spread.dart'},
    why: 'use the Space scale or a named constant',
  ),
  DesignRule(
    'number as a gap',
    RegExp(r'SizedBox\(\s*(?:width|height):\s*\d+(?:\.\d+)?\s*\)'),
    why: 'a gap is a step of the Space scale',
  ),
  DesignRule(
    'Space plus a number',
    RegExp(r'Space\.\w+\s*[-+*/]\s*\d'),
    why: 'off the scale: use a step or a named use (Space.card, Space.field …)',
  ),
  DesignRule(
    'number as a corner',
    RegExp(r'Radius\.circular\(\s*\d'),
    allowed: {...drawings},
    why: 'use the Radii scale',
  ),
  DesignRule(
    'Radii plus a number',
    RegExp(r'Radii\.\w+\s*[-+*/]\s*\d'),
    why: 'off the scale: use a step of Radii',
  ),
  DesignRule(
    'role off the type ramp',
    RegExp(r'\b(displayLarge|displayMedium|headlineLarge)\b'),
    why: 'the ramp has displaySmall (48) at its top',
  ),
  DesignRule(
    'line height off the ramp',
    RegExp(r'\bheight:\s*1\.\d'),
    allowed: {...drawings},
    why: "the ramp's line heights, or ReadingText for long text",
  ),
  DesignRule(
    'fixed page padding',
    RegExp(r'Space\.page\b'),
    why: "use pagePadding(context): the window class's margins and a centred column",
  ),
  DesignRule(
    "Material's own button",
    RegExp(r'\b(FilledButton|OutlinedButton|TextButton|IconButton|ElevatedButton)(\.(icon|tonal|tonalIcon))?\(|'
        r'\bFloatingActionButton(\.extended)?\('),
    allowed: {'buttons.dart'},
    why: "use the app's buttons (AppFilledButton …, buttons.dart): every button bounces when pressed (S30)",
  ),
  DesignRule(
    "Material's own switch",
    RegExp(r'\b(SwitchListTile|Switch)(\.adaptive)?\('),
    allowed: {'elastic_switch.dart'},
    why: "use AppSwitchTile (widgets/elastic_switch.dart): the switch's thumb stretches as it travels (S30)",
  ),
];

/// Every rule broken in the Dart files under [dir], as `file:line: rule: the line`; comments are skipped.
List<String> designViolations(String dir) {
  final found = <String>[];
  final files = Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final lines = file.readAsLinesSync();
    for (final (i, raw) in lines.indexed) {
      final line = raw.trimLeft();
      if (line.startsWith('//')) continue;
      final code = line.split(' // ').first;
      for (final rule in designRules) {
        if (rule.allowed.contains(name)) continue;
        if (rule.pattern.hasMatch(code)) found.add('${file.path}:${i + 1}: ${rule.name} (${rule.why}): $line');
      }
    }
  }
  return found;
}
