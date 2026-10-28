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
