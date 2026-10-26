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
}
