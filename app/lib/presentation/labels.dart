import '../l10n/gen/app_localizations.dart';

/// Localised labels for API enum values.
extension ApiLabels on AppLocalizations {
  String topic(String t) => switch (t) {
        'wuxing' => topicWuxing,
        'personality' => topicPersonality,
        'career_wealth' => topicCareerWealth,
        'relationships' => topicRelationships,
        'dayun_liunian' => topicDayunLiunian,
        'health' => topicHealth,
        'tarot_cards' => topicTarotCards,
        'tarot_synthesis' => topicTarotSynthesis,
        'tarot_advice' => topicTarotAdvice,
        'qiuqian_poem' => topicQiuqianPoem,
        'qiuqian_answer' => topicQiuqianAnswer,
        'qiuqian_advice' => topicQiuqianAdvice,
        'fengshui_layout' => topicFengshuiLayout,
        'fengshui_flow' => topicFengshuiFlow,
        'fengshui_advice' => topicFengshuiAdvice,
        'naming_candidates' => topicNamingCandidates,
        'naming_advice' => topicNamingAdvice,
        'liuyao_hexagram' => topicLiuyaoHexagram,
        'liuyao_answer' => topicLiuyaoAnswer,
        'liuyao_advice' => topicLiuyaoAdvice,
        _ => t,
      };

  /// The area of life a tarot reading looks at (contract `tarotFocus`).
  String tarotFocusLabel(String f) => switch (f) {
        'career_wealth' => focusCareer,
        'relationships' => focusLove,
        'health' => focusHealth,
        'personality' => focusSelf,
        _ => f,
      };

  String sourceLevel(String s) => switch (s) {
        'traditional_text' => srcTraditional,
        'common_consensus' => srcConsensus,
        'simplified_rule' => srcSimplified,
        'derived' => srcDerived,
        _ => s,
      };

  String horizon(String h) => switch (h) {
        'this_week' => horizonWeek,
        'this_month' => horizonMonth,
        'this_year' => horizonYear,
        'ongoing' => horizonOngoing,
        _ => h,
      };

  /// A method's name, as the home page names it; `life` is the 一生运势报告 (v8.0.0).
  String methodLabel(String system) => switch (system) {
        'bazi' => homeBazi,
        'tarot' => homeTarot,
        'qiuqian' => homeQiuqian,
        'liuyao' => homeLiuyao,
        'fengshui' => homeFengshui,
        'naming' => homeNaming,
        'life' => kindLife,
        _ => system,
      };

  /// 追问's first questions per method (v7.0.0), offered before anything is asked; `life` is the 一生运势报告.
  List<String> followUpStarters(String? system) => switch (system) {
        'bazi' => [followUpStartBazi1, followUpStartBazi2],
        'tarot' => [followUpStartTarot1, followUpStartTarot2],
        'qiuqian' => [followUpStartQiuqian1, followUpStartQiuqian2],
        'liuyao' => [followUpStartLiuyao1, followUpStartLiuyao2],
        'fengshui' => [followUpStartFengshui1, followUpStartFengshui2],
        'naming' => [followUpStartNaming1, followUpStartNaming2],
        'life' => [followUpStartLife1, followUpStartLife2],
        _ => const [],
      };

  String pillar(String p) => switch (p) {
        'year' => pillarYear,
        'month' => pillarMonth,
        'day' => pillarDay,
        'hour' => pillarHour,
        'dayun' => dayun,
        'liunian' => liunian,
        _ => p,
      };
}
