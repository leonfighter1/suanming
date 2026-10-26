import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Mingli Master'**
  String get appTitle;

  /// No description provided for @homeBazi.
  ///
  /// In en, this message translates to:
  /// **'Bazi chart'**
  String get homeBazi;

  /// No description provided for @homeBaziDesc.
  ///
  /// In en, this message translates to:
  /// **'Four Pillars, luck pillars and annual pillars from your birth time'**
  String get homeBaziDesc;

  /// No description provided for @homeTarot.
  ///
  /// In en, this message translates to:
  /// **'Tarot'**
  String get homeTarot;

  /// No description provided for @homeTarotDesc.
  ///
  /// In en, this message translates to:
  /// **'Draw a spread and reflect on it'**
  String get homeTarotDesc;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @region.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get region;

  /// No description provided for @birthTime.
  ///
  /// In en, this message translates to:
  /// **'Birth time (local civil time)'**
  String get birthTime;

  /// No description provided for @pickDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get pickDate;

  /// No description provided for @pickTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get pickTime;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'Birthplace'**
  String get city;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender (for luck pillar direction)'**
  String get gender;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @trueSolarTime.
  ///
  /// In en, this message translates to:
  /// **'True solar time correction'**
  String get trueSolarTime;

  /// No description provided for @compute.
  ///
  /// In en, this message translates to:
  /// **'Compute chart'**
  String get compute;

  /// No description provided for @fourPillars.
  ///
  /// In en, this message translates to:
  /// **'Four Pillars'**
  String get fourPillars;

  /// No description provided for @pillarYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get pillarYear;

  /// No description provided for @pillarMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get pillarMonth;

  /// No description provided for @pillarDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get pillarDay;

  /// No description provided for @pillarHour.
  ///
  /// In en, this message translates to:
  /// **'Hour'**
  String get pillarHour;

  /// No description provided for @rowTenGod.
  ///
  /// In en, this message translates to:
  /// **'Ten God'**
  String get rowTenGod;

  /// No description provided for @rowStem.
  ///
  /// In en, this message translates to:
  /// **'Stem'**
  String get rowStem;

  /// No description provided for @rowBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get rowBranch;

  /// No description provided for @rowHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden stems'**
  String get rowHidden;

  /// No description provided for @rowLifeStage.
  ///
  /// In en, this message translates to:
  /// **'Life stage'**
  String get rowLifeStage;

  /// No description provided for @rowNayin.
  ///
  /// In en, this message translates to:
  /// **'Na Yin'**
  String get rowNayin;

  /// No description provided for @dayMaster.
  ///
  /// In en, this message translates to:
  /// **'Day Master'**
  String get dayMaster;

  /// No description provided for @wuxingWeighted.
  ///
  /// In en, this message translates to:
  /// **'Five Elements (weighted, simplified score)'**
  String get wuxingWeighted;

  /// No description provided for @dayun.
  ///
  /// In en, this message translates to:
  /// **'Luck pillars'**
  String get dayun;

  /// No description provided for @dayunFrom.
  ///
  /// In en, this message translates to:
  /// **'starts {date}'**
  String dayunFrom(String date);

  /// No description provided for @liunian.
  ///
  /// In en, this message translates to:
  /// **'Annual pillars'**
  String get liunian;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'age {age}'**
  String age(int age);

  /// No description provided for @aiReport.
  ///
  /// In en, this message translates to:
  /// **'AI reading'**
  String get aiReport;

  /// No description provided for @chooseTopics.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get chooseTopics;

  /// No description provided for @generate.
  ///
  /// In en, this message translates to:
  /// **'Generate AI reading'**
  String get generate;

  /// No description provided for @generating.
  ///
  /// In en, this message translates to:
  /// **'Generating your reading…'**
  String get generating;

  /// No description provided for @generatingHint.
  ///
  /// In en, this message translates to:
  /// **'This takes a few minutes. You can leave this screen; the reading will be here when you come back.'**
  String get generatingHint;

  /// No description provided for @statusBlocked.
  ///
  /// In en, this message translates to:
  /// **'This reading didn\'t pass our content checks and won\'t be shown. Please try again.'**
  String get statusBlocked;

  /// No description provided for @statusReview.
  ///
  /// In en, this message translates to:
  /// **'This reading is being reviewed by our team before it can be shown.'**
  String get statusReview;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while generating. Please try again.'**
  String get statusFailed;

  /// No description provided for @layerFacts.
  ///
  /// In en, this message translates to:
  /// **'Chart facts · computed, not AI'**
  String get layerFacts;

  /// No description provided for @layerInterpretation.
  ///
  /// In en, this message translates to:
  /// **'Interpretation · AI generated'**
  String get layerInterpretation;

  /// No description provided for @layerActions.
  ///
  /// In en, this message translates to:
  /// **'Suggested actions · AI generated'**
  String get layerActions;

  /// No description provided for @aiBadge.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get aiBadge;

  /// No description provided for @topicWuxing.
  ///
  /// In en, this message translates to:
  /// **'Five Elements'**
  String get topicWuxing;

  /// No description provided for @topicPersonality.
  ///
  /// In en, this message translates to:
  /// **'Personality'**
  String get topicPersonality;

  /// No description provided for @topicCareerWealth.
  ///
  /// In en, this message translates to:
  /// **'Career & wealth'**
  String get topicCareerWealth;

  /// No description provided for @topicRelationships.
  ///
  /// In en, this message translates to:
  /// **'Relationships'**
  String get topicRelationships;

  /// No description provided for @topicDayunLiunian.
  ///
  /// In en, this message translates to:
  /// **'Luck & years'**
  String get topicDayunLiunian;

  /// No description provided for @topicHealth.
  ///
  /// In en, this message translates to:
  /// **'Wellbeing'**
  String get topicHealth;

  /// No description provided for @srcTraditional.
  ///
  /// In en, this message translates to:
  /// **'Classical texts'**
  String get srcTraditional;

  /// No description provided for @srcConsensus.
  ///
  /// In en, this message translates to:
  /// **'Common practice'**
  String get srcConsensus;

  /// No description provided for @srcSimplified.
  ///
  /// In en, this message translates to:
  /// **'Simplified rule'**
  String get srcSimplified;

  /// No description provided for @srcDerived.
  ///
  /// In en, this message translates to:
  /// **'Synthesis'**
  String get srcDerived;

  /// No description provided for @horizonWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get horizonWeek;

  /// No description provided for @horizonMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get horizonMonth;

  /// No description provided for @horizonYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get horizonYear;

  /// No description provided for @horizonOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get horizonOngoing;

  /// No description provided for @spread.
  ///
  /// In en, this message translates to:
  /// **'Spread'**
  String get spread;

  /// No description provided for @spreadSingle.
  ///
  /// In en, this message translates to:
  /// **'Single card'**
  String get spreadSingle;

  /// No description provided for @spreadThree.
  ///
  /// In en, this message translates to:
  /// **'Three cards (past · present · future)'**
  String get spreadThree;

  /// No description provided for @spreadCeltic.
  ///
  /// In en, this message translates to:
  /// **'Celtic Cross (10 cards)'**
  String get spreadCeltic;

  /// No description provided for @draw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get draw;

  /// No description provided for @reversed.
  ///
  /// In en, this message translates to:
  /// **'Reversed'**
  String get reversed;

  /// No description provided for @tapToReveal.
  ///
  /// In en, this message translates to:
  /// **'Tap a card to turn it over'**
  String get tapToReveal;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t complete the request'**
  String get errorTitle;

  /// No description provided for @disclaimerShort.
  ///
  /// In en, this message translates to:
  /// **'Cultural reference for self-reflection, not a prediction.'**
  String get disclaimerShort;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get haveAccount;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get noAccount;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 10 characters'**
  String get passwordHint;

  /// No description provided for @regionAccount.
  ///
  /// In en, this message translates to:
  /// **'Where you live'**
  String get regionAccount;

  /// No description provided for @regionAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Decides which rules and content apply to you. It can\'t be changed later in this version.'**
  String get regionAccountHint;

  /// No description provided for @ageConfirm.
  ///
  /// In en, this message translates to:
  /// **'I confirm I am at least 18 years old'**
  String get ageConfirm;

  /// No description provided for @appleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get appleSignIn;

  /// No description provided for @googleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get googleSignIn;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account and data'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Your account, charts and readings will be deleted from our servers right away. This can\'t be undone.'**
  String get deleteAccountBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get confirmDelete;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account and data have been deleted.'**
  String get accountDeleted;

  /// No description provided for @signInMethods.
  ///
  /// In en, this message translates to:
  /// **'Sign-in methods'**
  String get signInMethods;

  /// No description provided for @captchaRequired.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a few minutes and try again.'**
  String get captchaRequired;

  /// No description provided for @profiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profiles;

  /// No description provided for @profileFor.
  ///
  /// In en, this message translates to:
  /// **'Chart for'**
  String get profileFor;

  /// No description provided for @addProfile.
  ///
  /// In en, this message translates to:
  /// **'Add profile'**
  String get addProfile;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @setDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get setDefault;

  /// No description provided for @isDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get isDefault;

  /// No description provided for @deleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Delete profile'**
  String get deleteProfile;

  /// No description provided for @profileHint.
  ///
  /// In en, this message translates to:
  /// **'Changes below apply to this chart only. Edit the profile to change it everywhere.'**
  String get profileHint;

  /// No description provided for @noProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your birth details'**
  String get noProfileTitle;

  /// No description provided for @noProfileBody.
  ///
  /// In en, this message translates to:
  /// **'Save them once and every chart starts from them. You can add profiles for others too.'**
  String get noProfileBody;

  /// No description provided for @createProfile.
  ///
  /// In en, this message translates to:
  /// **'Create profile'**
  String get createProfile;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @lunarCompare.
  ///
  /// In en, this message translates to:
  /// **'Lunar calendar'**
  String get lunarCompare;

  /// No description provided for @gregorian.
  ///
  /// In en, this message translates to:
  /// **'Gregorian'**
  String get gregorian;

  /// No description provided for @lunarLabel.
  ///
  /// In en, this message translates to:
  /// **'Lunar'**
  String get lunarLabel;

  /// No description provided for @zodiac.
  ///
  /// In en, this message translates to:
  /// **'Zodiac'**
  String get zodiac;

  /// No description provided for @lunarYearNote.
  ///
  /// In en, this message translates to:
  /// **'The lunar year turns at Spring Festival; the year pillar turns at Li Chun.'**
  String get lunarYearNote;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No readings yet. Your readings will appear here.'**
  String get historyEmpty;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @analyzing.
  ///
  /// In en, this message translates to:
  /// **'AI is analysing in depth'**
  String get analyzing;

  /// No description provided for @stageNarrative.
  ///
  /// In en, this message translates to:
  /// **'Reading the chart'**
  String get stageNarrative;

  /// No description provided for @stageAction.
  ///
  /// In en, this message translates to:
  /// **'Drafting suggestions'**
  String get stageAction;

  /// No description provided for @stageGuard.
  ///
  /// In en, this message translates to:
  /// **'Content review'**
  String get stageGuard;

  /// No description provided for @stageWaiting.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get stageWaiting;

  /// No description provided for @elapsed.
  ///
  /// In en, this message translates to:
  /// **'Elapsed {time}'**
  String elapsed(String time);

  /// No description provided for @retrying.
  ///
  /// In en, this message translates to:
  /// **'A draft didn\'t pass our checks; rewriting (attempt {n})'**
  String retrying(int n);

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @copyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get copyAll;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @chartOf.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s chart'**
  String chartOf(String name);

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String greeting(String name);

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Mingli Master AI reading'**
  String get reportTitle;

  /// No description provided for @openChart.
  ///
  /// In en, this message translates to:
  /// **'Open chart'**
  String get openChart;

  /// No description provided for @timeExact.
  ///
  /// In en, this message translates to:
  /// **'Exact time'**
  String get timeExact;

  /// No description provided for @timeShichen.
  ///
  /// In en, this message translates to:
  /// **'Shichen (2-hour period)'**
  String get timeShichen;

  /// No description provided for @lunarYear.
  ///
  /// In en, this message translates to:
  /// **'Lunar year'**
  String get lunarYear;

  /// No description provided for @lunarMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get lunarMonth;

  /// No description provided for @lunarDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get lunarDay;

  /// No description provided for @shichenNote.
  ///
  /// In en, this message translates to:
  /// **'The hour is known to a two-hour period; readings that rely on the hour pillar are approximate.'**
  String get shichenNote;

  /// No description provided for @trendTitle.
  ///
  /// In en, this message translates to:
  /// **'Fortune trend'**
  String get trendTitle;

  /// No description provided for @trendDayun.
  ///
  /// In en, this message translates to:
  /// **'By age (luck pillars)'**
  String get trendDayun;

  /// No description provided for @trendLiunian.
  ///
  /// In en, this message translates to:
  /// **'By year'**
  String get trendLiunian;

  /// No description provided for @trendCombined.
  ///
  /// In en, this message translates to:
  /// **'Combined'**
  String get trendCombined;

  /// No description provided for @trendTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get trendTotal;

  /// No description provided for @trendCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get trendCompare;

  /// No description provided for @trendTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a period on the chart to see its scores and basis.'**
  String get trendTapHint;

  /// No description provided for @trendAge.
  ///
  /// In en, this message translates to:
  /// **'Age {ages}'**
  String trendAge(String ages);

  /// No description provided for @expandAll.
  ///
  /// In en, this message translates to:
  /// **'Expand all'**
  String get expandAll;

  /// No description provided for @collapseAll.
  ///
  /// In en, this message translates to:
  /// **'Collapse all'**
  String get collapseAll;

  /// No description provided for @remedyTitle.
  ///
  /// In en, this message translates to:
  /// **'Fortune remedies'**
  String get remedyTitle;

  /// No description provided for @remedyDesc.
  ///
  /// In en, this message translates to:
  /// **'A targeted plan for one topic: it names the topic and periods it addresses and gives concrete steps. Each topic is unlocked separately.'**
  String get remedyDesc;

  /// No description provided for @remedyFor.
  ///
  /// In en, this message translates to:
  /// **'Remedy: {topic}'**
  String remedyFor(String topic);

  /// No description provided for @remedyUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock · {price}'**
  String remedyUnlock(String price);

  /// No description provided for @remedyView.
  ///
  /// In en, this message translates to:
  /// **'View plan'**
  String get remedyView;

  /// No description provided for @remedyConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock the {topic} remedy'**
  String remedyConfirmTitle(String topic);

  /// No description provided for @remedyConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This plan is charged separately for {topic}: {price}.\nPayments are not connected yet (TODO): confirming charges directly as a demo and nothing is actually billed.'**
  String remedyConfirmBody(String topic, String price);

  /// No description provided for @remedyPay.
  ///
  /// In en, this message translates to:
  /// **'Pay {price}'**
  String remedyPay(String price);

  /// No description provided for @remedyGenerating.
  ///
  /// In en, this message translates to:
  /// **'AI is writing the {topic} plan…'**
  String remedyGenerating(String topic);

  /// No description provided for @remedyTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get remedyTarget;

  /// No description provided for @remedyFocus.
  ///
  /// In en, this message translates to:
  /// **'Focus periods'**
  String get remedyFocus;

  /// No description provided for @remedySteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get remedySteps;

  /// No description provided for @remedyBasis.
  ///
  /// In en, this message translates to:
  /// **'Basis in the chart'**
  String get remedyBasis;

  /// No description provided for @remedySave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get remedySave;

  /// No description provided for @remedySend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get remedySend;

  /// No description provided for @remedyPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get remedyPrint;

  /// No description provided for @remedyHeld.
  ///
  /// In en, this message translates to:
  /// **'This plan is held for review and is not available yet.'**
  String get remedyHeld;

  /// No description provided for @remedyFailed.
  ///
  /// In en, this message translates to:
  /// **'Generation failed. Retry; you won\'t be charged again.'**
  String get remedyFailed;

  /// No description provided for @remedyDemoPaid.
  ///
  /// In en, this message translates to:
  /// **'Demo payment (not billed)'**
  String get remedyDemoPaid;

  /// No description provided for @placePick.
  ///
  /// In en, this message translates to:
  /// **'Choose birthplace'**
  String get placePick;

  /// No description provided for @placeCountry.
  ///
  /// In en, this message translates to:
  /// **'Country or region'**
  String get placeCountry;

  /// No description provided for @placeRegion.
  ///
  /// In en, this message translates to:
  /// **'Province / state'**
  String get placeRegion;

  /// No description provided for @placeCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get placeCity;

  /// No description provided for @placeSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get placeSearch;

  /// No description provided for @placeCommon.
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get placeCommon;

  /// No description provided for @placeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get placeAll;

  /// No description provided for @placeNone.
  ///
  /// In en, this message translates to:
  /// **'No match'**
  String get placeNone;

  /// No description provided for @placeDetail.
  ///
  /// In en, this message translates to:
  /// **'Time zone {tz} · longitude {lon}'**
  String placeDetail(String tz, String lon);

  /// No description provided for @placeSource.
  ///
  /// In en, this message translates to:
  /// **'Place data: GeoNames (CC BY 4.0)'**
  String get placeSource;

  /// No description provided for @serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server at {url}.\nOn a phone, 127.0.0.1 is the phone itself: start `npm run api:lan` on the computer and open http://<computer\'s Wi-Fi address>:5000. From an https page, add ?api=<https server address> to the page URL.'**
  String serverUnreachable(String url);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
