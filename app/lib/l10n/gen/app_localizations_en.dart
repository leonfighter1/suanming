// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mingli Master';

  @override
  String get homeBazi => 'Bazi chart';

  @override
  String get homeBaziDesc =>
      'Four Pillars, luck pillars and annual pillars from your birth time';

  @override
  String get homeTarot => 'Tarot';

  @override
  String get homeTarotDesc => 'Draw a spread and reflect on it';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get region => 'Region';

  @override
  String get birthTime => 'Birth time (local civil time)';

  @override
  String get pickDate => 'Date';

  @override
  String get pickTime => 'Time';

  @override
  String get city => 'Birthplace';

  @override
  String get gender => 'Gender (for luck pillar direction)';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get trueSolarTime => 'True solar time correction';

  @override
  String get compute => 'Compute chart';

  @override
  String get fourPillars => 'Four Pillars';

  @override
  String get pillarYear => 'Year';

  @override
  String get pillarMonth => 'Month';

  @override
  String get pillarDay => 'Day';

  @override
  String get pillarHour => 'Hour';

  @override
  String get rowTenGod => 'Ten God';

  @override
  String get rowStem => 'Stem';

  @override
  String get rowBranch => 'Branch';

  @override
  String get rowHidden => 'Hidden stems';

  @override
  String get rowLifeStage => 'Life stage';

  @override
  String get rowNayin => 'Na Yin';

  @override
  String get dayMaster => 'Day Master';

  @override
  String get wuxingWeighted => 'Five Elements (weighted, simplified score)';

  @override
  String get dayun => 'Luck pillars';

  @override
  String dayunFrom(String date) {
    return 'starts $date';
  }

  @override
  String get liunian => 'Annual pillars';

  @override
  String age(int age) {
    return 'age $age';
  }

  @override
  String get aiReport => 'AI reading';

  @override
  String get chooseTopics => 'Topics';

  @override
  String get generate => 'Generate AI reading';

  @override
  String get generating => 'Generating your reading…';

  @override
  String get generatingHint =>
      'This takes a few minutes. You can leave this screen; the reading will be here when you come back.';

  @override
  String get statusBlocked =>
      'This reading didn\'t pass our content checks and won\'t be shown. Please try again.';

  @override
  String get statusReview =>
      'This reading is being reviewed by our team before it can be shown.';

  @override
  String get statusFailed =>
      'Something went wrong while generating. Please try again.';

  @override
  String get layerFacts => 'Chart facts · computed, not AI';

  @override
  String get layerInterpretation => 'Interpretation · AI generated';

  @override
  String get layerActions => 'Suggested actions · AI generated';

  @override
  String get aiBadge => 'AI';

  @override
  String get topicWuxing => 'Five Elements';

  @override
  String get topicPersonality => 'Personality';

  @override
  String get topicCareerWealth => 'Career & wealth';

  @override
  String get topicRelationships => 'Relationships';

  @override
  String get topicDayunLiunian => 'Luck & years';

  @override
  String get topicHealth => 'Wellbeing';

  @override
  String get srcTraditional => 'Classical texts';

  @override
  String get srcConsensus => 'Common practice';

  @override
  String get srcSimplified => 'Simplified rule';

  @override
  String get srcDerived => 'Synthesis';

  @override
  String get horizonWeek => 'This week';

  @override
  String get horizonMonth => 'This month';

  @override
  String get horizonYear => 'This year';

  @override
  String get horizonOngoing => 'Ongoing';

  @override
  String get spread => 'Spread';

  @override
  String get spreadSingle => 'Single card';

  @override
  String get spreadThree => 'Three cards (past · present · future)';

  @override
  String get spreadCeltic => 'Celtic Cross (10 cards)';

  @override
  String get draw => 'Draw';

  @override
  String get reversed => 'Reversed';

  @override
  String get tapToReveal => 'Tap a card to turn it over';

  @override
  String get retry => 'Retry';

  @override
  String get errorTitle => 'Couldn\'t complete the request';

  @override
  String get disclaimerShort =>
      'Cultural reference for self-reflection, not a prediction.';

  @override
  String get signIn => 'Sign in';

  @override
  String get createAccount => 'Create account';

  @override
  String get haveAccount => 'Already have an account? Sign in';

  @override
  String get noAccount => 'New here? Create an account';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'At least 10 characters';

  @override
  String get regionAccount => 'Where you live';

  @override
  String get regionAccountHint =>
      'Decides which rules and content apply to you. It can\'t be changed later in this version.';

  @override
  String get ageConfirm => 'I confirm I am at least 18 years old';

  @override
  String get appleSignIn => 'Sign in with Apple';

  @override
  String get googleSignIn => 'Sign in with Google';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get account => 'Account';

  @override
  String get signOut => 'Sign out';

  @override
  String get deleteAccount => 'Delete account and data';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountBody =>
      'Your account, charts and readings will be deleted from our servers right away. This can\'t be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirmDelete => 'Delete';

  @override
  String get accountDeleted => 'Your account and data have been deleted.';

  @override
  String get signInMethods => 'Sign-in methods';

  @override
  String get captchaRequired =>
      'Too many attempts. Please wait a few minutes and try again.';

  @override
  String get profiles => 'Profiles';

  @override
  String get profileFor => 'Chart for';

  @override
  String get addProfile => 'Add profile';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get name => 'Name';

  @override
  String get setDefault => 'Set as default';

  @override
  String get isDefault => 'Default';

  @override
  String get deleteProfile => 'Delete profile';

  @override
  String get profileHint =>
      'Changes below apply to this chart only. Edit the profile to change it everywhere.';

  @override
  String get noProfileTitle => 'Add your birth details';

  @override
  String get noProfileBody =>
      'Save them once and every chart starts from them. You can add profiles for others too.';

  @override
  String get createProfile => 'Create profile';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get lunarCompare => 'Lunar calendar';

  @override
  String get gregorian => 'Gregorian';

  @override
  String get lunarLabel => 'Lunar';

  @override
  String get zodiac => 'Zodiac';

  @override
  String get lunarYearNote =>
      'The lunar year turns at Spring Festival; the year pillar turns at Li Chun.';

  @override
  String get history => 'History';

  @override
  String get historyEmpty => 'No readings yet. Your readings will appear here.';

  @override
  String get recent => 'Recent';

  @override
  String get viewAll => 'View all';

  @override
  String get analyzing => 'AI is analysing in depth';

  @override
  String get stageNarrative => 'Reading the chart';

  @override
  String get stageAction => 'Drafting suggestions';

  @override
  String get stageGuard => 'Content review';

  @override
  String get stageWaiting => 'Queued';

  @override
  String elapsed(String time) {
    return 'Elapsed $time';
  }

  @override
  String retrying(int n) {
    return 'A draft didn\'t pass our checks; rewriting (attempt $n)';
  }

  @override
  String get download => 'Download';

  @override
  String get copyAll => 'Copy all';

  @override
  String get copied => 'Copied';

  @override
  String get more => 'More';

  @override
  String chartOf(String name) {
    return '$name\'s chart';
  }

  @override
  String greeting(String name) {
    return 'Hello, $name';
  }

  @override
  String get reportTitle => 'Mingli Master AI reading';

  @override
  String get openChart => 'Open chart';

  @override
  String get timeExact => 'Exact time';

  @override
  String get timeShichen => 'Shichen (2-hour period)';

  @override
  String get lunarYear => 'Lunar year';

  @override
  String get lunarMonth => 'Month';

  @override
  String get lunarDay => 'Day';

  @override
  String get shichenNote =>
      'The hour is known to a two-hour period; readings that rely on the hour pillar are approximate.';

  @override
  String get trendTitle => 'Fortune trend';

  @override
  String get trendDayun => 'By age (luck pillars)';

  @override
  String get trendLiunian => 'By year';

  @override
  String get trendCombined => 'Combined';

  @override
  String get trendTotal => 'Total';

  @override
  String get trendCompare => 'Compare';

  @override
  String get trendTapHint =>
      'Tap a period on the chart to see its scores and basis.';

  @override
  String trendAge(String ages) {
    return 'Age $ages';
  }

  @override
  String get expandAll => 'Expand all';

  @override
  String get collapseAll => 'Collapse all';

  @override
  String get remedyTitle => 'Fortune remedies';

  @override
  String get remedyDesc =>
      'A targeted plan for one topic: it names the topic and periods it addresses and gives concrete steps. Each topic is unlocked separately.';

  @override
  String remedyFor(String topic) {
    return 'Remedy: $topic';
  }

  @override
  String remedyUnlock(String price) {
    return 'Unlock · $price';
  }

  @override
  String get remedyView => 'View plan';

  @override
  String remedyConfirmTitle(String topic) {
    return 'Unlock the $topic remedy';
  }

  @override
  String remedyConfirmBody(String topic, String price) {
    return 'This plan is charged separately for $topic: $price.\nPayments are not connected yet (TODO): confirming charges directly as a demo and nothing is actually billed.';
  }

  @override
  String remedyPay(String price) {
    return 'Pay $price';
  }

  @override
  String remedyGenerating(String topic) {
    return 'AI is writing the $topic plan…';
  }

  @override
  String get remedyTarget => 'Target';

  @override
  String get remedyFocus => 'Focus periods';

  @override
  String get remedySteps => 'Steps';

  @override
  String get remedyBasis => 'Basis in the chart';

  @override
  String get remedySave => 'Save';

  @override
  String get remedySend => 'Send';

  @override
  String get remedyPrint => 'Print';

  @override
  String get remedyHeld =>
      'This plan is held for review and is not available yet.';

  @override
  String get remedyFailed =>
      'Generation failed. Retry; you won\'t be charged again.';

  @override
  String get remedyDemoPaid => 'Demo payment (not billed)';
}
