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
