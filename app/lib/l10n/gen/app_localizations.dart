import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

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
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'命理大师'**
  String get appTitle;

  /// No description provided for @homeBazi.
  ///
  /// In zh, this message translates to:
  /// **'八字排盘'**
  String get homeBazi;

  /// No description provided for @homeBaziDesc.
  ///
  /// In zh, this message translates to:
  /// **'根据出生时间排出四柱、大运和流年，也可以生成一生运势报告'**
  String get homeBaziDesc;

  /// No description provided for @homeTarot.
  ///
  /// In zh, this message translates to:
  /// **'塔罗'**
  String get homeTarot;

  /// No description provided for @homeTarotDesc.
  ///
  /// In zh, this message translates to:
  /// **'抽一组牌阵，仅供娱乐和玄学学习使用'**
  String get homeTarotDesc;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @appearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @themeTime.
  ///
  /// In zh, this message translates to:
  /// **'跟随时间'**
  String get themeTime;

  /// No description provided for @themeTimeHint.
  ///
  /// In zh, this message translates to:
  /// **'晚上 7 点到早上 6 点为深色，其余为浅色'**
  String get themeTimeHint;

  /// No description provided for @region.
  ///
  /// In zh, this message translates to:
  /// **'地区'**
  String get region;

  /// No description provided for @birthTime.
  ///
  /// In zh, this message translates to:
  /// **'出生时间（当地时间）'**
  String get birthTime;

  /// No description provided for @pickDate.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get pickDate;

  /// No description provided for @pickTime.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get pickTime;

  /// No description provided for @city.
  ///
  /// In zh, this message translates to:
  /// **'出生地'**
  String get city;

  /// No description provided for @gender.
  ///
  /// In zh, this message translates to:
  /// **'性别（决定大运顺逆）'**
  String get gender;

  /// No description provided for @male.
  ///
  /// In zh, this message translates to:
  /// **'男'**
  String get male;

  /// No description provided for @female.
  ///
  /// In zh, this message translates to:
  /// **'女'**
  String get female;

  /// No description provided for @trueSolarTime.
  ///
  /// In zh, this message translates to:
  /// **'真太阳时校正'**
  String get trueSolarTime;

  /// No description provided for @compute.
  ///
  /// In zh, this message translates to:
  /// **'排盘'**
  String get compute;

  /// No description provided for @fourPillars.
  ///
  /// In zh, this message translates to:
  /// **'四柱'**
  String get fourPillars;

  /// No description provided for @pillarYear.
  ///
  /// In zh, this message translates to:
  /// **'年柱'**
  String get pillarYear;

  /// No description provided for @pillarMonth.
  ///
  /// In zh, this message translates to:
  /// **'月柱'**
  String get pillarMonth;

  /// No description provided for @pillarDay.
  ///
  /// In zh, this message translates to:
  /// **'日柱'**
  String get pillarDay;

  /// No description provided for @pillarHour.
  ///
  /// In zh, this message translates to:
  /// **'时柱'**
  String get pillarHour;

  /// No description provided for @rowTenGod.
  ///
  /// In zh, this message translates to:
  /// **'十神'**
  String get rowTenGod;

  /// No description provided for @rowStem.
  ///
  /// In zh, this message translates to:
  /// **'天干'**
  String get rowStem;

  /// No description provided for @rowBranch.
  ///
  /// In zh, this message translates to:
  /// **'地支'**
  String get rowBranch;

  /// No description provided for @rowHidden.
  ///
  /// In zh, this message translates to:
  /// **'藏干'**
  String get rowHidden;

  /// No description provided for @rowLifeStage.
  ///
  /// In zh, this message translates to:
  /// **'十二长生'**
  String get rowLifeStage;

  /// No description provided for @rowNayin.
  ///
  /// In zh, this message translates to:
  /// **'纳音'**
  String get rowNayin;

  /// No description provided for @dayMaster.
  ///
  /// In zh, this message translates to:
  /// **'日主'**
  String get dayMaster;

  /// No description provided for @wuxingWeighted.
  ///
  /// In zh, this message translates to:
  /// **'五行（加权，简化计分）'**
  String get wuxingWeighted;

  /// No description provided for @dayun.
  ///
  /// In zh, this message translates to:
  /// **'大运'**
  String get dayun;

  /// No description provided for @dayunFrom.
  ///
  /// In zh, this message translates to:
  /// **'{date} 起运'**
  String dayunFrom(String date);

  /// No description provided for @liunian.
  ///
  /// In zh, this message translates to:
  /// **'流年'**
  String get liunian;

  /// No description provided for @age.
  ///
  /// In zh, this message translates to:
  /// **'虚岁 {age}'**
  String age(int age);

  /// No description provided for @aiReport.
  ///
  /// In zh, this message translates to:
  /// **'AI 解读'**
  String get aiReport;

  /// No description provided for @chooseTopics.
  ///
  /// In zh, this message translates to:
  /// **'分析方面'**
  String get chooseTopics;

  /// No description provided for @generate.
  ///
  /// In zh, this message translates to:
  /// **'生成 AI 解读'**
  String get generate;

  /// No description provided for @generateBazi.
  ///
  /// In zh, this message translates to:
  /// **'用AI做更精确解读'**
  String get generateBazi;

  /// No description provided for @generating.
  ///
  /// In zh, this message translates to:
  /// **'正在生成解读…'**
  String get generating;

  /// No description provided for @generatingHint.
  ///
  /// In zh, this message translates to:
  /// **'大约需要几分钟。可以先离开这个页面，完成后回来查看。'**
  String get generatingHint;

  /// No description provided for @statusBlocked.
  ///
  /// In zh, this message translates to:
  /// **'这份解读未通过内容审查，不会显示。请重新生成。'**
  String get statusBlocked;

  /// No description provided for @statusReview.
  ///
  /// In zh, this message translates to:
  /// **'这份解读正在由团队审核，通过后才会显示。'**
  String get statusReview;

  /// No description provided for @statusFailed.
  ///
  /// In zh, this message translates to:
  /// **'生成时出现问题，请重试。'**
  String get statusFailed;

  /// No description provided for @layerFacts.
  ///
  /// In zh, this message translates to:
  /// **'命盘事实 · 引擎计算，非 AI'**
  String get layerFacts;

  /// No description provided for @layerInterpretation.
  ///
  /// In zh, this message translates to:
  /// **'解读 · AI 生成'**
  String get layerInterpretation;

  /// No description provided for @layerActions.
  ///
  /// In zh, this message translates to:
  /// **'行动建议 · AI 生成'**
  String get layerActions;

  /// No description provided for @layerConclusion.
  ///
  /// In zh, this message translates to:
  /// **'总结 · AI 生成'**
  String get layerConclusion;

  /// No description provided for @conclusionPortrait.
  ///
  /// In zh, this message translates to:
  /// **'你是怎样的人'**
  String get conclusionPortrait;

  /// No description provided for @conclusionPast.
  ///
  /// In zh, this message translates to:
  /// **'过去'**
  String get conclusionPast;

  /// No description provided for @conclusionPresent.
  ///
  /// In zh, this message translates to:
  /// **'现在'**
  String get conclusionPresent;

  /// No description provided for @conclusionChallenges.
  ///
  /// In zh, this message translates to:
  /// **'可能遇到的问题'**
  String get conclusionChallenges;

  /// No description provided for @conclusionGains.
  ///
  /// In zh, this message translates to:
  /// **'得势与得失'**
  String get conclusionGains;

  /// No description provided for @conclusionFuture.
  ///
  /// In zh, this message translates to:
  /// **'未来运势'**
  String get conclusionFuture;

  /// No description provided for @conclusionCaution.
  ///
  /// In zh, this message translates to:
  /// **'何时开始要注意'**
  String get conclusionCaution;

  /// No description provided for @conclusionMomentum.
  ///
  /// In zh, this message translates to:
  /// **'何时开始要发力'**
  String get conclusionMomentum;

  /// No description provided for @conclusionCoping.
  ///
  /// In zh, this message translates to:
  /// **'遇到问题时怎么办'**
  String get conclusionCoping;

  /// No description provided for @aiBadge.
  ///
  /// In zh, this message translates to:
  /// **'AI'**
  String get aiBadge;

  /// No description provided for @topicWuxing.
  ///
  /// In zh, this message translates to:
  /// **'五行'**
  String get topicWuxing;

  /// No description provided for @topicPersonality.
  ///
  /// In zh, this message translates to:
  /// **'性格'**
  String get topicPersonality;

  /// No description provided for @topicCareerWealth.
  ///
  /// In zh, this message translates to:
  /// **'事业财运'**
  String get topicCareerWealth;

  /// No description provided for @topicRelationships.
  ///
  /// In zh, this message translates to:
  /// **'婚姻感情'**
  String get topicRelationships;

  /// No description provided for @topicDayunLiunian.
  ///
  /// In zh, this message translates to:
  /// **'大运流年'**
  String get topicDayunLiunian;

  /// No description provided for @topicHealth.
  ///
  /// In zh, this message translates to:
  /// **'健康'**
  String get topicHealth;

  /// No description provided for @topicTarotCards.
  ///
  /// In zh, this message translates to:
  /// **'逐张解读'**
  String get topicTarotCards;

  /// No description provided for @topicTarotSynthesis.
  ///
  /// In zh, this message translates to:
  /// **'综合解读'**
  String get topicTarotSynthesis;

  /// No description provided for @topicTarotAdvice.
  ///
  /// In zh, this message translates to:
  /// **'建议'**
  String get topicTarotAdvice;

  /// No description provided for @srcTraditional.
  ///
  /// In zh, this message translates to:
  /// **'典籍'**
  String get srcTraditional;

  /// No description provided for @srcConsensus.
  ///
  /// In zh, this message translates to:
  /// **'通行共识'**
  String get srcConsensus;

  /// No description provided for @srcSimplified.
  ///
  /// In zh, this message translates to:
  /// **'简化规则'**
  String get srcSimplified;

  /// No description provided for @srcDerived.
  ///
  /// In zh, this message translates to:
  /// **'综合推导'**
  String get srcDerived;

  /// No description provided for @horizonWeek.
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get horizonWeek;

  /// No description provided for @horizonMonth.
  ///
  /// In zh, this message translates to:
  /// **'本月'**
  String get horizonMonth;

  /// No description provided for @horizonYear.
  ///
  /// In zh, this message translates to:
  /// **'今年'**
  String get horizonYear;

  /// No description provided for @horizonOngoing.
  ///
  /// In zh, this message translates to:
  /// **'持续'**
  String get horizonOngoing;

  /// No description provided for @spread.
  ///
  /// In zh, this message translates to:
  /// **'牌阵'**
  String get spread;

  /// No description provided for @spreadSingle.
  ///
  /// In zh, this message translates to:
  /// **'单张'**
  String get spreadSingle;

  /// No description provided for @spreadThree.
  ///
  /// In zh, this message translates to:
  /// **'三张（过去・现在・未来）'**
  String get spreadThree;

  /// No description provided for @spreadCeltic.
  ///
  /// In zh, this message translates to:
  /// **'凯尔特十字（10 张）'**
  String get spreadCeltic;

  /// No description provided for @pillarMore.
  ///
  /// In zh, this message translates to:
  /// **'更多：藏干、长生、纳音'**
  String get pillarMore;

  /// No description provided for @pillarLess.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get pillarLess;

  /// No description provided for @ritualTitle.
  ///
  /// In zh, this message translates to:
  /// **'洗牌 · 切牌 · 选牌'**
  String get ritualTitle;

  /// No description provided for @ritualShuffleHint.
  ///
  /// In zh, this message translates to:
  /// **'心里想着你的问题，按“洗牌”把牌洗匀。'**
  String get ritualShuffleHint;

  /// No description provided for @ritualShuffle.
  ///
  /// In zh, this message translates to:
  /// **'洗牌'**
  String get ritualShuffle;

  /// No description provided for @ritualCutHint.
  ///
  /// In zh, this message translates to:
  /// **'切牌：选一叠，放到最上面。'**
  String get ritualCutHint;

  /// No description provided for @ritualPile.
  ///
  /// In zh, this message translates to:
  /// **'第 {n} 叠'**
  String ritualPile(int n);

  /// No description provided for @ritualPickHint.
  ///
  /// In zh, this message translates to:
  /// **'选牌：凭直觉选 {count} 张（已选 {picked} 张）'**
  String ritualPickHint(int count, int picked);

  /// No description provided for @ritualCard.
  ///
  /// In zh, this message translates to:
  /// **'第 {n} 张牌，背面朝上'**
  String ritualCard(int n);

  /// No description provided for @ritualSkip.
  ///
  /// In zh, this message translates to:
  /// **'让牌组替我选'**
  String get ritualSkip;

  /// No description provided for @ritualNote.
  ///
  /// In zh, this message translates to:
  /// **'牌由系统公平洗好，你在背面朝上时选择；每次抽牌事后都可以核对。'**
  String get ritualNote;

  /// No description provided for @tarotGlossary.
  ///
  /// In zh, this message translates to:
  /// **'牌义图鉴'**
  String get tarotGlossary;

  /// No description provided for @glossaryMajor.
  ///
  /// In zh, this message translates to:
  /// **'大阿尔卡那'**
  String get glossaryMajor;

  /// No description provided for @glossaryWands.
  ///
  /// In zh, this message translates to:
  /// **'权杖'**
  String get glossaryWands;

  /// No description provided for @glossaryCups.
  ///
  /// In zh, this message translates to:
  /// **'圣杯'**
  String get glossaryCups;

  /// No description provided for @glossarySwords.
  ///
  /// In zh, this message translates to:
  /// **'宝剑'**
  String get glossarySwords;

  /// No description provided for @glossaryPentacles.
  ///
  /// In zh, this message translates to:
  /// **'星币'**
  String get glossaryPentacles;

  /// No description provided for @glossaryKeywords.
  ///
  /// In zh, this message translates to:
  /// **'牌面关键词'**
  String get glossaryKeywords;

  /// No description provided for @dailyCard.
  ///
  /// In zh, this message translates to:
  /// **'今日一牌'**
  String get dailyCard;

  /// No description provided for @dailyCardHint.
  ///
  /// In zh, this message translates to:
  /// **'每天一张，当天不变。点开看大图，也可以请 AI 解读。'**
  String get dailyCardHint;

  /// No description provided for @dailyLot.
  ///
  /// In zh, this message translates to:
  /// **'今日一签'**
  String get dailyLot;

  /// No description provided for @dailyLotHint.
  ///
  /// In zh, this message translates to:
  /// **'每天一签，当天不变。点开看签诗，也可以请 AI 解读。'**
  String get dailyLotHint;

  /// No description provided for @dailyHexagram.
  ///
  /// In zh, this message translates to:
  /// **'今日一卦'**
  String get dailyHexagram;

  /// No description provided for @dailyHexagramHint.
  ///
  /// In zh, this message translates to:
  /// **'每天一卦，当天不变。点开看卦辞，也可以请 AI 解读。'**
  String get dailyHexagramHint;

  /// No description provided for @spreadSingleShort.
  ///
  /// In zh, this message translates to:
  /// **'单张'**
  String get spreadSingleShort;

  /// No description provided for @spreadThreeShort.
  ///
  /// In zh, this message translates to:
  /// **'三张'**
  String get spreadThreeShort;

  /// No description provided for @spreadCelticShort.
  ///
  /// In zh, this message translates to:
  /// **'凯尔特十字'**
  String get spreadCelticShort;

  /// No description provided for @spreadTwoPathsShort.
  ///
  /// In zh, this message translates to:
  /// **'二选一'**
  String get spreadTwoPathsShort;

  /// No description provided for @spreadRelationshipShort.
  ///
  /// In zh, this message translates to:
  /// **'关系牌阵'**
  String get spreadRelationshipShort;

  /// No description provided for @tarotExample1.
  ///
  /// In zh, this message translates to:
  /// **'这份工作还适合我吗？'**
  String get tarotExample1;

  /// No description provided for @tarotExample2.
  ///
  /// In zh, this message translates to:
  /// **'我们的关系会往哪里走？'**
  String get tarotExample2;

  /// No description provided for @tarotExample3.
  ///
  /// In zh, this message translates to:
  /// **'接下来三个月我该注意什么？'**
  String get tarotExample3;

  /// No description provided for @tarotExample4.
  ///
  /// In zh, this message translates to:
  /// **'这个决定我该怎么做？'**
  String get tarotExample4;

  /// No description provided for @draw.
  ///
  /// In zh, this message translates to:
  /// **'抽牌'**
  String get draw;

  /// No description provided for @reversed.
  ///
  /// In zh, this message translates to:
  /// **'逆位'**
  String get reversed;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @errorTitle.
  ///
  /// In zh, this message translates to:
  /// **'请求失败'**
  String get errorTitle;

  /// No description provided for @disclaimerShort.
  ///
  /// In zh, this message translates to:
  /// **'仅供娱乐和玄学学习使用，不是预测。'**
  String get disclaimerShort;

  /// No description provided for @signIn.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In zh, this message translates to:
  /// **'注册账号'**
  String get createAccount;

  /// No description provided for @haveAccount.
  ///
  /// In zh, this message translates to:
  /// **'已有账号？去登录'**
  String get haveAccount;

  /// No description provided for @noAccount.
  ///
  /// In zh, this message translates to:
  /// **'新用户？立即注册'**
  String get noAccount;

  /// No description provided for @email.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get email;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In zh, this message translates to:
  /// **'至少 10 个字符'**
  String get passwordHint;

  /// No description provided for @regionAccount.
  ///
  /// In zh, this message translates to:
  /// **'居住地区'**
  String get regionAccount;

  /// No description provided for @regionAccountHint.
  ///
  /// In zh, this message translates to:
  /// **'决定适用的规则和内容。当前版本注册后不能修改。'**
  String get regionAccountHint;

  /// No description provided for @ageConfirm.
  ///
  /// In zh, this message translates to:
  /// **'我确认已年满 18 岁'**
  String get ageConfirm;

  /// No description provided for @appleSignIn.
  ///
  /// In zh, this message translates to:
  /// **'通过 Apple 登录'**
  String get appleSignIn;

  /// No description provided for @googleSignIn.
  ///
  /// In zh, this message translates to:
  /// **'通过 Google 登录'**
  String get googleSignIn;

  /// No description provided for @comingSoon.
  ///
  /// In zh, this message translates to:
  /// **'即将推出'**
  String get comingSoon;

  /// No description provided for @account.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get account;

  /// No description provided for @signOut.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get signOut;

  /// No description provided for @deleteAccount.
  ///
  /// In zh, this message translates to:
  /// **'注销账号并删除数据'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In zh, this message translates to:
  /// **'确定注销账号吗？'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In zh, this message translates to:
  /// **'你的账号、命盘和解读会立即从服务器删除，无法恢复。'**
  String get deleteAccountBody;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirmDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get confirmDelete;

  /// No description provided for @accountDeleted.
  ///
  /// In zh, this message translates to:
  /// **'账号和数据已删除。'**
  String get accountDeleted;

  /// No description provided for @signInMethods.
  ///
  /// In zh, this message translates to:
  /// **'登录方式'**
  String get signInMethods;

  /// No description provided for @captchaRequired.
  ///
  /// In zh, this message translates to:
  /// **'尝试次数过多，请稍等几分钟再试。'**
  String get captchaRequired;

  /// No description provided for @profiles.
  ///
  /// In zh, this message translates to:
  /// **'个人资料'**
  String get profiles;

  /// No description provided for @profileFor.
  ///
  /// In zh, this message translates to:
  /// **'为谁排盘'**
  String get profileFor;

  /// No description provided for @addProfile.
  ///
  /// In zh, this message translates to:
  /// **'添加资料'**
  String get addProfile;

  /// No description provided for @editProfile.
  ///
  /// In zh, this message translates to:
  /// **'编辑资料'**
  String get editProfile;

  /// No description provided for @name.
  ///
  /// In zh, this message translates to:
  /// **'姓名'**
  String get name;

  /// No description provided for @setDefault.
  ///
  /// In zh, this message translates to:
  /// **'设为默认'**
  String get setDefault;

  /// No description provided for @isDefault.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get isDefault;

  /// No description provided for @deleteProfile.
  ///
  /// In zh, this message translates to:
  /// **'删除资料'**
  String get deleteProfile;

  /// No description provided for @profileHint.
  ///
  /// In zh, this message translates to:
  /// **'以下修改只用于本次排盘；要永久修改请编辑资料。'**
  String get profileHint;

  /// No description provided for @noProfileTitle.
  ///
  /// In zh, this message translates to:
  /// **'填写你的出生信息'**
  String get noProfileTitle;

  /// No description provided for @noProfileBody.
  ///
  /// In zh, this message translates to:
  /// **'保存一次，以后排盘会自动带入。也可以给家人朋友添加资料。'**
  String get noProfileBody;

  /// No description provided for @createProfile.
  ///
  /// In zh, this message translates to:
  /// **'创建资料'**
  String get createProfile;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get saved;

  /// No description provided for @lunarCompare.
  ///
  /// In zh, this message translates to:
  /// **'农历对照'**
  String get lunarCompare;

  /// No description provided for @gregorian.
  ///
  /// In zh, this message translates to:
  /// **'公历'**
  String get gregorian;

  /// No description provided for @lunarLabel.
  ///
  /// In zh, this message translates to:
  /// **'农历'**
  String get lunarLabel;

  /// No description provided for @zodiac.
  ///
  /// In zh, this message translates to:
  /// **'生肖'**
  String get zodiac;

  /// No description provided for @lunarYearNote.
  ///
  /// In zh, this message translates to:
  /// **'农历年以春节为界，八字年柱以立春为界。'**
  String get lunarYearNote;

  /// No description provided for @history.
  ///
  /// In zh, this message translates to:
  /// **'历史记录'**
  String get history;

  /// No description provided for @historyEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有解读记录，生成后会显示在这里。'**
  String get historyEmpty;

  /// No description provided for @recent.
  ///
  /// In zh, this message translates to:
  /// **'最近记录'**
  String get recent;

  /// No description provided for @viewAll.
  ///
  /// In zh, this message translates to:
  /// **'查看全部'**
  String get viewAll;

  /// No description provided for @analyzing.
  ///
  /// In zh, this message translates to:
  /// **'AI 正在深度分析中'**
  String get analyzing;

  /// No description provided for @stageNarrative.
  ///
  /// In zh, this message translates to:
  /// **'深度解读命盘'**
  String get stageNarrative;

  /// No description provided for @stageAction.
  ///
  /// In zh, this message translates to:
  /// **'整理行动建议'**
  String get stageAction;

  /// No description provided for @stageGuard.
  ///
  /// In zh, this message translates to:
  /// **'内容合规审查'**
  String get stageGuard;

  /// No description provided for @stageWaiting.
  ///
  /// In zh, this message translates to:
  /// **'排队中'**
  String get stageWaiting;

  /// No description provided for @elapsed.
  ///
  /// In zh, this message translates to:
  /// **'已用时 {time}'**
  String elapsed(String time);

  /// No description provided for @retrying.
  ///
  /// In zh, this message translates to:
  /// **'上一稿未通过检查，正在重写（第 {n} 次）'**
  String retrying(int n);

  /// No description provided for @download.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get download;

  /// No description provided for @copyAll.
  ///
  /// In zh, this message translates to:
  /// **'复制全文'**
  String get copyAll;

  /// No description provided for @copied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get copied;

  /// No description provided for @more.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get more;

  /// No description provided for @chartOf.
  ///
  /// In zh, this message translates to:
  /// **'{name} 的命盘'**
  String chartOf(String name);

  /// No description provided for @greeting.
  ///
  /// In zh, this message translates to:
  /// **'你好，{name}'**
  String greeting(String name);

  /// No description provided for @reportTitle.
  ///
  /// In zh, this message translates to:
  /// **'命理大师 AI 解读'**
  String get reportTitle;

  /// No description provided for @openChart.
  ///
  /// In zh, this message translates to:
  /// **'查看命盘'**
  String get openChart;

  /// No description provided for @timeExact.
  ///
  /// In zh, this message translates to:
  /// **'精确时间'**
  String get timeExact;

  /// No description provided for @timeShichen.
  ///
  /// In zh, this message translates to:
  /// **'时辰'**
  String get timeShichen;

  /// No description provided for @lunarYear.
  ///
  /// In zh, this message translates to:
  /// **'农历年'**
  String get lunarYear;

  /// No description provided for @lunarMonth.
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get lunarMonth;

  /// No description provided for @lunarDay.
  ///
  /// In zh, this message translates to:
  /// **'日'**
  String get lunarDay;

  /// No description provided for @shichenNote.
  ///
  /// In zh, this message translates to:
  /// **'只知道时辰：时柱只精确到两小时，相关解读会标明为参考。'**
  String get shichenNote;

  /// No description provided for @trendTitle.
  ///
  /// In zh, this message translates to:
  /// **'运势走势'**
  String get trendTitle;

  /// No description provided for @trendDayun.
  ///
  /// In zh, this message translates to:
  /// **'按年龄（大运）'**
  String get trendDayun;

  /// No description provided for @trendLiunian.
  ///
  /// In zh, this message translates to:
  /// **'按年份（流年）'**
  String get trendLiunian;

  /// No description provided for @trendCombined.
  ///
  /// In zh, this message translates to:
  /// **'综合'**
  String get trendCombined;

  /// No description provided for @trendTotal.
  ///
  /// In zh, this message translates to:
  /// **'总分'**
  String get trendTotal;

  /// No description provided for @trendCompare.
  ///
  /// In zh, this message translates to:
  /// **'叠加对比'**
  String get trendCompare;

  /// No description provided for @trendTapHint.
  ///
  /// In zh, this message translates to:
  /// **'点击图上的时期，查看各项分数和依据。'**
  String get trendTapHint;

  /// No description provided for @trendAge.
  ///
  /// In zh, this message translates to:
  /// **'虚岁 {ages}'**
  String trendAge(String ages);

  /// No description provided for @expandAll.
  ///
  /// In zh, this message translates to:
  /// **'展开全部'**
  String get expandAll;

  /// No description provided for @collapseAll.
  ///
  /// In zh, this message translates to:
  /// **'收起全部'**
  String get collapseAll;

  /// No description provided for @remedyTitle.
  ///
  /// In zh, this message translates to:
  /// **'破除运势'**
  String get remedyTitle;

  /// No description provided for @remedyDesc.
  ///
  /// In zh, this message translates to:
  /// **'针对单个项目的改运方案：写明针对哪一项、哪些时期，并给出具体做法。每个项目单独解锁。'**
  String get remedyDesc;

  /// No description provided for @remedyFor.
  ///
  /// In zh, this message translates to:
  /// **'破除运势：{topic}'**
  String remedyFor(String topic);

  /// No description provided for @remedyUnlock.
  ///
  /// In zh, this message translates to:
  /// **'解锁 · {price}'**
  String remedyUnlock(String price);

  /// No description provided for @remedyView.
  ///
  /// In zh, this message translates to:
  /// **'查看方案'**
  String get remedyView;

  /// No description provided for @remedyConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'解锁“{topic}”破除运势方案'**
  String remedyConfirmTitle(String topic);

  /// No description provided for @remedyConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'这个方案针对“{topic}”单独收费：{price}。\n支付功能尚未接入（TODO）：现在点确认会直接扣款（演示，不会真实收费）。'**
  String remedyConfirmBody(String topic, String price);

  /// No description provided for @remedyPay.
  ///
  /// In zh, this message translates to:
  /// **'确认支付 {price}'**
  String remedyPay(String price);

  /// No description provided for @remedyGenerating.
  ///
  /// In zh, this message translates to:
  /// **'AI 正在为“{topic}”制定方案…'**
  String remedyGenerating(String topic);

  /// No description provided for @remedyTarget.
  ///
  /// In zh, this message translates to:
  /// **'针对项目'**
  String get remedyTarget;

  /// No description provided for @remedyFocus.
  ///
  /// In zh, this message translates to:
  /// **'重点时期'**
  String get remedyFocus;

  /// No description provided for @remedySteps.
  ///
  /// In zh, this message translates to:
  /// **'具体做法'**
  String get remedySteps;

  /// No description provided for @remedyBasis.
  ///
  /// In zh, this message translates to:
  /// **'命理依据'**
  String get remedyBasis;

  /// No description provided for @remedySave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get remedySave;

  /// No description provided for @remedySend.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get remedySend;

  /// No description provided for @remedyPrint.
  ///
  /// In zh, this message translates to:
  /// **'打印'**
  String get remedyPrint;

  /// No description provided for @remedyHeld.
  ///
  /// In zh, this message translates to:
  /// **'方案正在审核中，暂时无法显示。'**
  String get remedyHeld;

  /// No description provided for @remedyFailed.
  ///
  /// In zh, this message translates to:
  /// **'生成失败，请重试（不会重复收费）。'**
  String get remedyFailed;

  /// No description provided for @remedyDemoPaid.
  ///
  /// In zh, this message translates to:
  /// **'演示支付（未真实扣款）'**
  String get remedyDemoPaid;

  /// No description provided for @placePick.
  ///
  /// In zh, this message translates to:
  /// **'选择出生地'**
  String get placePick;

  /// No description provided for @placeCountry.
  ///
  /// In zh, this message translates to:
  /// **'国家和地区'**
  String get placeCountry;

  /// No description provided for @placeRegion.
  ///
  /// In zh, this message translates to:
  /// **'省／州'**
  String get placeRegion;

  /// No description provided for @placeCity.
  ///
  /// In zh, this message translates to:
  /// **'城市'**
  String get placeCity;

  /// No description provided for @placeSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get placeSearch;

  /// No description provided for @placeCommon.
  ///
  /// In zh, this message translates to:
  /// **'常用'**
  String get placeCommon;

  /// No description provided for @placeAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get placeAll;

  /// No description provided for @placeNone.
  ///
  /// In zh, this message translates to:
  /// **'没有符合的结果'**
  String get placeNone;

  /// No description provided for @placeDetail.
  ///
  /// In zh, this message translates to:
  /// **'时区 {tz} · 经度 {lon}'**
  String placeDetail(String tz, String lon);

  /// No description provided for @placeSource.
  ///
  /// In zh, this message translates to:
  /// **'地点数据：GeoNames（CC BY 4.0）'**
  String get placeSource;

  /// No description provided for @serverUnreachable.
  ///
  /// In zh, this message translates to:
  /// **'无法连接服务器 {url}。\n手机上的 127.0.0.1 指的是手机本身：请在电脑上运行 npm run api:lan，再用手机打开 http://电脑的局域网地址:5000。如果页面是 https，请在网址后面加上 ?api=https 服务器地址。'**
  String serverUnreachable(String url);

  /// No description provided for @lifeTitle.
  ///
  /// In zh, this message translates to:
  /// **'个人情况（选填）'**
  String get lifeTitle;

  /// No description provided for @lifeHint.
  ///
  /// In zh, this message translates to:
  /// **'同时同地出生的人命盘相同，填上你的实际情况，解读才会贴近你本人。信息只保存在本机，只在生成解读时和命盘一起发给 AI。'**
  String get lifeHint;

  /// No description provided for @lifeUseName.
  ///
  /// In zh, this message translates to:
  /// **'解读时用名字称呼我'**
  String get lifeUseName;

  /// No description provided for @lifeResidence.
  ///
  /// In zh, this message translates to:
  /// **'现居地'**
  String get lifeResidence;

  /// No description provided for @lifeNotSet.
  ///
  /// In zh, this message translates to:
  /// **'未填写'**
  String get lifeNotSet;

  /// No description provided for @lifeMarital.
  ///
  /// In zh, this message translates to:
  /// **'婚姻状况'**
  String get lifeMarital;

  /// No description provided for @maritalSingle.
  ///
  /// In zh, this message translates to:
  /// **'单身'**
  String get maritalSingle;

  /// No description provided for @maritalDating.
  ///
  /// In zh, this message translates to:
  /// **'恋爱中'**
  String get maritalDating;

  /// No description provided for @maritalMarried.
  ///
  /// In zh, this message translates to:
  /// **'已婚'**
  String get maritalMarried;

  /// No description provided for @maritalSeparated.
  ///
  /// In zh, this message translates to:
  /// **'分居'**
  String get maritalSeparated;

  /// No description provided for @maritalDivorced.
  ///
  /// In zh, this message translates to:
  /// **'离婚'**
  String get maritalDivorced;

  /// No description provided for @maritalWidowed.
  ///
  /// In zh, this message translates to:
  /// **'丧偶'**
  String get maritalWidowed;

  /// No description provided for @lifeChildren.
  ///
  /// In zh, this message translates to:
  /// **'子女'**
  String get lifeChildren;

  /// No description provided for @childrenNone.
  ///
  /// In zh, this message translates to:
  /// **'没有'**
  String get childrenNone;

  /// No description provided for @childrenHas.
  ///
  /// In zh, this message translates to:
  /// **'有'**
  String get childrenHas;

  /// No description provided for @lifeOccupation.
  ///
  /// In zh, this message translates to:
  /// **'职业／行业'**
  String get lifeOccupation;

  /// No description provided for @lifeFamily.
  ///
  /// In zh, this message translates to:
  /// **'家庭情况'**
  String get lifeFamily;

  /// No description provided for @lifeFamilyHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：和父母同住、需要照顾老人'**
  String get lifeFamilyHint;

  /// No description provided for @lifeConcern.
  ///
  /// In zh, this message translates to:
  /// **'想问的事'**
  String get lifeConcern;

  /// No description provided for @lifeConcernHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：明年适合跳槽吗？'**
  String get lifeConcernHint;

  /// No description provided for @sectionSummary.
  ///
  /// In zh, this message translates to:
  /// **'一句话重点'**
  String get sectionSummary;

  /// No description provided for @remedyReady.
  ///
  /// In zh, this message translates to:
  /// **'已备好'**
  String get remedyReady;

  /// No description provided for @lifeEntry.
  ///
  /// In zh, this message translates to:
  /// **'一生运势报告'**
  String get lifeEntry;

  /// No description provided for @lifeEntryDesc.
  ///
  /// In zh, this message translates to:
  /// **'易经本命卦、梅花易数、五行八卦，三法合看一生走势'**
  String get lifeEntryDesc;

  /// No description provided for @lifeGenerate.
  ///
  /// In zh, this message translates to:
  /// **'生成一生运势报告'**
  String get lifeGenerate;

  /// No description provided for @lifeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'易经本命卦　|　梅花易数　|　五行八卦'**
  String get lifeSubtitle;

  /// No description provided for @lifeReportOf.
  ///
  /// In zh, this message translates to:
  /// **'{name} 一生运势报告'**
  String lifeReportOf(String name);

  /// No description provided for @lifeItem.
  ///
  /// In zh, this message translates to:
  /// **'项目'**
  String get lifeItem;

  /// No description provided for @lifeContent.
  ///
  /// In zh, this message translates to:
  /// **'内容'**
  String get lifeContent;

  /// No description provided for @lifeName.
  ///
  /// In zh, this message translates to:
  /// **'姓名'**
  String get lifeName;

  /// No description provided for @lifeBirthLunar.
  ///
  /// In zh, this message translates to:
  /// **'出生（农历）'**
  String get lifeBirthLunar;

  /// No description provided for @lifeBirthSolar.
  ///
  /// In zh, this message translates to:
  /// **'出生（公历）'**
  String get lifeBirthSolar;

  /// No description provided for @lifeBirthPlace.
  ///
  /// In zh, this message translates to:
  /// **'出生地'**
  String get lifeBirthPlace;

  /// No description provided for @lifeTrueSolar.
  ///
  /// In zh, this message translates to:
  /// **'真太阳时'**
  String get lifeTrueSolar;

  /// No description provided for @lifeGanzhi.
  ///
  /// In zh, this message translates to:
  /// **'生辰干支'**
  String get lifeGanzhi;

  /// No description provided for @lifeNote.
  ///
  /// In zh, this message translates to:
  /// **'说明：本报告依传统术数推演，仅供娱乐和玄学学习使用，不是科学预测。三种方法各自独立推演，最后再合看。'**
  String get lifeNote;

  /// No description provided for @lifeSec1.
  ///
  /// In zh, this message translates to:
  /// **'一、易经本命卦'**
  String get lifeSec1;

  /// No description provided for @lifeQigua.
  ///
  /// In zh, this message translates to:
  /// **'起卦'**
  String get lifeQigua;

  /// No description provided for @lifeBenGua.
  ///
  /// In zh, this message translates to:
  /// **'本命卦'**
  String get lifeBenGua;

  /// No description provided for @lifeHuGua.
  ///
  /// In zh, this message translates to:
  /// **'互卦'**
  String get lifeHuGua;

  /// No description provided for @lifeZhiGuaShort.
  ///
  /// In zh, this message translates to:
  /// **'之卦'**
  String get lifeZhiGuaShort;

  /// No description provided for @lifeGuaYi.
  ///
  /// In zh, this message translates to:
  /// **'卦义：一生的底色'**
  String get lifeGuaYi;

  /// No description provided for @lifeMingYao.
  ///
  /// In zh, this message translates to:
  /// **'命爻'**
  String get lifeMingYao;

  /// No description provided for @lifeZhiGua.
  ///
  /// In zh, this message translates to:
  /// **'之卦：人生归宿'**
  String get lifeZhiGua;

  /// No description provided for @lifeSixLines.
  ///
  /// In zh, this message translates to:
  /// **'六爻配人生阶段'**
  String get lifeSixLines;

  /// No description provided for @lifeLine.
  ///
  /// In zh, this message translates to:
  /// **'爻'**
  String get lifeLine;

  /// No description provided for @lifeAge.
  ///
  /// In zh, this message translates to:
  /// **'年龄'**
  String get lifeAge;

  /// No description provided for @lifeYaoCi.
  ///
  /// In zh, this message translates to:
  /// **'爻辞'**
  String get lifeYaoCi;

  /// No description provided for @lifeForLife.
  ///
  /// In zh, this message translates to:
  /// **'对应人生'**
  String get lifeForLife;

  /// No description provided for @lifeSec2.
  ///
  /// In zh, this message translates to:
  /// **'二、梅花易数'**
  String get lifeSec2;

  /// No description provided for @lifeMhGua.
  ///
  /// In zh, this message translates to:
  /// **'卦'**
  String get lifeMhGua;

  /// No description provided for @lifeMhRel.
  ///
  /// In zh, this message translates to:
  /// **'与体卦的关系'**
  String get lifeMhRel;

  /// No description provided for @lifeMhStage.
  ///
  /// In zh, this message translates to:
  /// **'主管'**
  String get lifeMhStage;

  /// No description provided for @lifeTi.
  ///
  /// In zh, this message translates to:
  /// **'体卦'**
  String get lifeTi;

  /// No description provided for @lifeYong.
  ///
  /// In zh, this message translates to:
  /// **'用卦'**
  String get lifeYong;

  /// No description provided for @lifeHu.
  ///
  /// In zh, this message translates to:
  /// **'互卦'**
  String get lifeHu;

  /// No description provided for @lifeBian.
  ///
  /// In zh, this message translates to:
  /// **'变卦'**
  String get lifeBian;

  /// No description provided for @lifeSelf.
  ///
  /// In zh, this message translates to:
  /// **'代表本人'**
  String get lifeSelf;

  /// No description provided for @lifeEarly.
  ///
  /// In zh, this message translates to:
  /// **'早年'**
  String get lifeEarly;

  /// No description provided for @lifeMiddle.
  ///
  /// In zh, this message translates to:
  /// **'中年'**
  String get lifeMiddle;

  /// No description provided for @lifeLate.
  ///
  /// In zh, this message translates to:
  /// **'晚年'**
  String get lifeLate;

  /// No description provided for @lifeSeason.
  ///
  /// In zh, this message translates to:
  /// **'时令'**
  String get lifeSeason;

  /// No description provided for @lifeMhConclusion.
  ///
  /// In zh, this message translates to:
  /// **'梅花结论'**
  String get lifeMhConclusion;

  /// No description provided for @relBihe.
  ///
  /// In zh, this message translates to:
  /// **'比和（同气相助）'**
  String get relBihe;

  /// No description provided for @relShengti.
  ///
  /// In zh, this message translates to:
  /// **'生体（得助）'**
  String get relShengti;

  /// No description provided for @relTisheng.
  ///
  /// In zh, this message translates to:
  /// **'体生（耗泄）'**
  String get relTisheng;

  /// No description provided for @relTike.
  ///
  /// In zh, this message translates to:
  /// **'体克（我克为财，辛苦得）'**
  String get relTike;

  /// No description provided for @relKeti.
  ///
  /// In zh, this message translates to:
  /// **'克体（受压）'**
  String get relKeti;

  /// No description provided for @lifeSec3.
  ///
  /// In zh, this message translates to:
  /// **'三、五行八卦'**
  String get lifeSec3;

  /// No description provided for @lifeWuxingDist.
  ///
  /// In zh, this message translates to:
  /// **'五行分布（加权，简化计分）'**
  String get lifeWuxingDist;

  /// No description provided for @lifeFavorable.
  ///
  /// In zh, this message translates to:
  /// **'喜'**
  String get lifeFavorable;

  /// No description provided for @lifeUnfavorable.
  ///
  /// In zh, this message translates to:
  /// **'忌'**
  String get lifeUnfavorable;

  /// No description provided for @lifeBazhai.
  ///
  /// In zh, this message translates to:
  /// **'八卦命卦（八宅）'**
  String get lifeBazhai;

  /// No description provided for @lifeKua.
  ///
  /// In zh, this message translates to:
  /// **'命卦 {kua} · {name}卦（{group}，五行属{wuxing}）'**
  String lifeKua(String kua, String name, String group, String wuxing);

  /// No description provided for @lifeDaily.
  ///
  /// In zh, this message translates to:
  /// **'日常宜用'**
  String get lifeDaily;

  /// No description provided for @lifeSec4.
  ///
  /// In zh, this message translates to:
  /// **'四、分项运势'**
  String get lifeSec4;

  /// No description provided for @lifeTopicPersonality.
  ///
  /// In zh, this message translates to:
  /// **'性格'**
  String get lifeTopicPersonality;

  /// No description provided for @lifeTopicCareer.
  ///
  /// In zh, this message translates to:
  /// **'事业'**
  String get lifeTopicCareer;

  /// No description provided for @lifeTopicWealth.
  ///
  /// In zh, this message translates to:
  /// **'财运'**
  String get lifeTopicWealth;

  /// No description provided for @lifeTopicRelationships.
  ///
  /// In zh, this message translates to:
  /// **'情感与婚姻'**
  String get lifeTopicRelationships;

  /// No description provided for @lifeTopicChildren.
  ///
  /// In zh, this message translates to:
  /// **'家庭与子女'**
  String get lifeTopicChildren;

  /// No description provided for @lifeTopicParents.
  ///
  /// In zh, this message translates to:
  /// **'父母'**
  String get lifeTopicParents;

  /// No description provided for @lifeTopicHealth.
  ///
  /// In zh, this message translates to:
  /// **'健康'**
  String get lifeTopicHealth;

  /// No description provided for @lifeSec5.
  ///
  /// In zh, this message translates to:
  /// **'五、人生阶段总览'**
  String get lifeSec5;

  /// No description provided for @lifeYears.
  ///
  /// In zh, this message translates to:
  /// **'年份'**
  String get lifeYears;

  /// No description provided for @lifeFortune.
  ///
  /// In zh, this message translates to:
  /// **'运势'**
  String get lifeFortune;

  /// No description provided for @lifeFocus.
  ///
  /// In zh, this message translates to:
  /// **'重点'**
  String get lifeFocus;

  /// No description provided for @lifeSec6.
  ///
  /// In zh, this message translates to:
  /// **'六、总评与建议'**
  String get lifeSec6;

  /// No description provided for @lifeDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载报告包'**
  String get lifeDownload;

  /// No description provided for @lifePrint.
  ///
  /// In zh, this message translates to:
  /// **'打印 / 保存 PDF'**
  String get lifePrint;

  /// No description provided for @lifeGenerating.
  ///
  /// In zh, this message translates to:
  /// **'AI 正在撰写一生运势报告…'**
  String get lifeGenerating;

  /// No description provided for @lifeStageMethods.
  ///
  /// In zh, this message translates to:
  /// **'推演易经、梅花与八宅'**
  String get lifeStageMethods;

  /// No description provided for @lifeStageTopics.
  ///
  /// In zh, this message translates to:
  /// **'撰写分项运势与人生阶段'**
  String get lifeStageTopics;

  /// No description provided for @lifeTook.
  ///
  /// In zh, this message translates to:
  /// **'大约需要 3–5 分钟。可以先离开这个页面，完成后回来查看。'**
  String get lifeTook;

  /// No description provided for @lifeDirection.
  ///
  /// In zh, this message translates to:
  /// **'方位'**
  String get lifeDirection;

  /// No description provided for @lifeStar.
  ///
  /// In zh, this message translates to:
  /// **'星名'**
  String get lifeStar;

  /// No description provided for @lifeLuck.
  ///
  /// In zh, this message translates to:
  /// **'吉凶'**
  String get lifeLuck;

  /// No description provided for @lifeMhName.
  ///
  /// In zh, this message translates to:
  /// **'卦名'**
  String get lifeMhName;

  /// No description provided for @lifeWuxing.
  ///
  /// In zh, this message translates to:
  /// **'五行'**
  String get lifeWuxing;

  /// No description provided for @reviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'内容审核'**
  String get reviewTitle;

  /// No description provided for @reviewEmpty.
  ///
  /// In zh, this message translates to:
  /// **'目前没有待审核的内容。'**
  String get reviewEmpty;

  /// No description provided for @reviewHint.
  ///
  /// In zh, this message translates to:
  /// **'这里是被合规检查拦下的内容。确认没有问题才通过；规则层拦截的只能查看或驳回。'**
  String get reviewHint;

  /// No description provided for @kindReport.
  ///
  /// In zh, this message translates to:
  /// **'AI 解读'**
  String get kindReport;

  /// No description provided for @kindRemedy.
  ///
  /// In zh, this message translates to:
  /// **'破除运势方案'**
  String get kindRemedy;

  /// No description provided for @kindLife.
  ///
  /// In zh, this message translates to:
  /// **'一生运势报告'**
  String get kindLife;

  /// No description provided for @reviewHeld.
  ///
  /// In zh, this message translates to:
  /// **'待审核'**
  String get reviewHeld;

  /// No description provided for @reviewBlocked.
  ///
  /// In zh, this message translates to:
  /// **'规则层拦截'**
  String get reviewBlocked;

  /// No description provided for @reviewReasons.
  ///
  /// In zh, this message translates to:
  /// **'拦截原因'**
  String get reviewReasons;

  /// No description provided for @reviewRuleHits.
  ///
  /// In zh, this message translates to:
  /// **'规则命中'**
  String get reviewRuleHits;

  /// No description provided for @reviewGuard.
  ///
  /// In zh, this message translates to:
  /// **'AI 审核意见'**
  String get reviewGuard;

  /// No description provided for @reviewContent.
  ///
  /// In zh, this message translates to:
  /// **'内容'**
  String get reviewContent;

  /// No description provided for @reviewNote.
  ///
  /// In zh, this message translates to:
  /// **'审核备注（可选）'**
  String get reviewNote;

  /// No description provided for @reviewApprove.
  ///
  /// In zh, this message translates to:
  /// **'通过并发布'**
  String get reviewApprove;

  /// No description provided for @reviewReject.
  ///
  /// In zh, this message translates to:
  /// **'驳回'**
  String get reviewReject;

  /// No description provided for @reviewBlockedOnly.
  ///
  /// In zh, this message translates to:
  /// **'规则层拦截属于硬性违规，只能驳回，不能发布。'**
  String get reviewBlockedOnly;

  /// No description provided for @reviewApproved.
  ///
  /// In zh, this message translates to:
  /// **'已通过并发布给用户'**
  String get reviewApproved;

  /// No description provided for @reviewRejected.
  ///
  /// In zh, this message translates to:
  /// **'已驳回'**
  String get reviewRejected;

  /// No description provided for @reviewNoContent.
  ///
  /// In zh, this message translates to:
  /// **'这条没有保留内容。'**
  String get reviewNoContent;

  /// No description provided for @modeChart.
  ///
  /// In zh, this message translates to:
  /// **'排盘解读'**
  String get modeChart;

  /// No description provided for @addTester.
  ///
  /// In zh, this message translates to:
  /// **'添加新的测试者'**
  String get addTester;

  /// No description provided for @editCurrent.
  ///
  /// In zh, this message translates to:
  /// **'编辑“{name}”的资料'**
  String editCurrent(String name);

  /// No description provided for @leaveReadingTitle.
  ///
  /// In zh, this message translates to:
  /// **'返回将重新开始'**
  String get leaveReadingTitle;

  /// No description provided for @leaveReadingBody.
  ///
  /// In zh, this message translates to:
  /// **'这次测算还没有完成，返回后需要重新开始。'**
  String get leaveReadingBody;

  /// No description provided for @leaveFormBody.
  ///
  /// In zh, this message translates to:
  /// **'本次填写的内容不会保留，返回后需要重新填写。'**
  String get leaveFormBody;

  /// No description provided for @leaveChartBody.
  ///
  /// In zh, this message translates to:
  /// **'返回后要重新排盘才能再看到这个命盘。已生成的解读会保存在历史记录里。'**
  String get leaveChartBody;

  /// No description provided for @leaveTarotBody.
  ///
  /// In zh, this message translates to:
  /// **'这次抽到的牌不会保留，下次要重新抽牌。已生成的解读会保存在历史记录里。'**
  String get leaveTarotBody;

  /// No description provided for @leaveReadingStay.
  ///
  /// In zh, this message translates to:
  /// **'继续测算'**
  String get leaveReadingStay;

  /// No description provided for @leaveReadingGo.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get leaveReadingGo;

  /// No description provided for @leaveEditsTitle.
  ///
  /// In zh, this message translates to:
  /// **'放弃未保存的修改？'**
  String get leaveEditsTitle;

  /// No description provided for @leaveEditsBody.
  ///
  /// In zh, this message translates to:
  /// **'返回后，这次的修改不会保存。'**
  String get leaveEditsBody;

  /// No description provided for @leaveEditsStay.
  ///
  /// In zh, this message translates to:
  /// **'继续编辑'**
  String get leaveEditsStay;

  /// No description provided for @leaveEditsGo.
  ///
  /// In zh, this message translates to:
  /// **'放弃修改'**
  String get leaveEditsGo;

  /// No description provided for @keysTitle.
  ///
  /// In zh, this message translates to:
  /// **'键盘快捷键'**
  String get keysTitle;

  /// No description provided for @keysTab.
  ///
  /// In zh, this message translates to:
  /// **'移到下一个 / 上一个控件'**
  String get keysTab;

  /// No description provided for @keySpace.
  ///
  /// In zh, this message translates to:
  /// **'空格'**
  String get keySpace;

  /// No description provided for @keysPress.
  ///
  /// In zh, this message translates to:
  /// **'按下按钮；展开或收起段落'**
  String get keysPress;

  /// No description provided for @keysEsc.
  ///
  /// In zh, this message translates to:
  /// **'返回上一层：先关闭菜单和对话框；测算未完成时会先提醒'**
  String get keysEsc;

  /// No description provided for @keysArrows.
  ///
  /// In zh, this message translates to:
  /// **'切换选项（如 公历 / 农历）和图表时期；滚动 大运 / 流年'**
  String get keysArrows;

  /// No description provided for @keysScroll.
  ///
  /// In zh, this message translates to:
  /// **'滚动页面；在菜单里上下选择'**
  String get keysScroll;

  /// No description provided for @keysSubmit.
  ///
  /// In zh, this message translates to:
  /// **'提交表单：登录、排盘、抽牌、保存'**
  String get keysSubmit;

  /// No description provided for @keysHelp.
  ///
  /// In zh, this message translates to:
  /// **'打开这个列表'**
  String get keysHelp;

  /// No description provided for @keysBrowser.
  ///
  /// In zh, this message translates to:
  /// **'切换浏览器标签页：这是浏览器自己的快捷键，本应用不占用。应用内切换选项请用 ← →'**
  String get keysBrowser;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @cardHidden.
  ///
  /// In zh, this message translates to:
  /// **'{position}，未翻开'**
  String cardHidden(String position);

  /// No description provided for @tarotQuestion.
  ///
  /// In zh, this message translates to:
  /// **'你想问的问题'**
  String get tarotQuestion;

  /// No description provided for @tarotQuestionHint.
  ///
  /// In zh, this message translates to:
  /// **'先写下你想问的问题才能抽牌：有所问，牌才有所答，解读也围绕它展开。'**
  String get tarotQuestionHint;

  /// No description provided for @tarotQuestionMissing.
  ///
  /// In zh, this message translates to:
  /// **'先写下你想问的问题，才能抽牌'**
  String get tarotQuestionMissing;

  /// No description provided for @tarotFocus.
  ///
  /// In zh, this message translates to:
  /// **'想看哪方面（可选）'**
  String get tarotFocus;

  /// No description provided for @focusAny.
  ///
  /// In zh, this message translates to:
  /// **'不限'**
  String get focusAny;

  /// No description provided for @focusCareer.
  ///
  /// In zh, this message translates to:
  /// **'事业'**
  String get focusCareer;

  /// No description provided for @focusLove.
  ///
  /// In zh, this message translates to:
  /// **'感情'**
  String get focusLove;

  /// No description provided for @focusHealth.
  ///
  /// In zh, this message translates to:
  /// **'健康'**
  String get focusHealth;

  /// No description provided for @focusSelf.
  ///
  /// In zh, this message translates to:
  /// **'自我'**
  String get focusSelf;

  /// No description provided for @tarotSections.
  ///
  /// In zh, this message translates to:
  /// **'解读分三部分：逐张解读、综合解读、建议。'**
  String get tarotSections;

  /// No description provided for @tarotQuestionShown.
  ///
  /// In zh, this message translates to:
  /// **'问题：{question}'**
  String tarotQuestionShown(String question);

  /// No description provided for @tarotSlot.
  ///
  /// In zh, this message translates to:
  /// **'第 {n} 张 · {position}'**
  String tarotSlot(int n, String position);

  /// No description provided for @tarotNext.
  ///
  /// In zh, this message translates to:
  /// **'按牌阵顺序翻牌，下一张：{slot}'**
  String tarotNext(String slot);

  /// No description provided for @tarotNextShort.
  ///
  /// In zh, this message translates to:
  /// **'下一张'**
  String get tarotNextShort;

  /// No description provided for @tarotZoomHint.
  ///
  /// In zh, this message translates to:
  /// **'点击小牌放大，在大图里翻开。'**
  String get tarotZoomHint;

  /// No description provided for @tarotAllTurned.
  ///
  /// In zh, this message translates to:
  /// **'牌已全部翻开。点击任意一张，看大图和位置含义。'**
  String get tarotAllTurned;

  /// No description provided for @tarotTapToTurn.
  ///
  /// In zh, this message translates to:
  /// **'点击牌面翻开'**
  String get tarotTapToTurn;

  /// No description provided for @shenshaTitle.
  ///
  /// In zh, this message translates to:
  /// **'神煞 · 空亡 · 胎元'**
  String get shenshaTitle;

  /// No description provided for @relationsTitle.
  ///
  /// In zh, this message translates to:
  /// **'原局刑冲合害'**
  String get relationsTitle;

  /// No description provided for @ziNextDay.
  ///
  /// In zh, this message translates to:
  /// **'23:00–24:00 出生，日柱算次日'**
  String get ziNextDay;

  /// No description provided for @ziNextDayHint.
  ///
  /// In zh, this message translates to:
  /// **'子时有两种算法；默认 23:00 后出生仍算当天'**
  String get ziNextDayHint;

  /// No description provided for @notDeLing.
  ///
  /// In zh, this message translates to:
  /// **'不得令'**
  String get notDeLing;

  /// No description provided for @favorableIs.
  ///
  /// In zh, this message translates to:
  /// **'喜用：{elements}'**
  String favorableIs(String elements);

  /// No description provided for @unfavorableIs.
  ///
  /// In zh, this message translates to:
  /// **'忌：{elements}'**
  String unfavorableIs(String elements);

  /// No description provided for @specialNote.
  ///
  /// In zh, this message translates to:
  /// **'宜请有经验的师傅细看'**
  String get specialNote;

  /// No description provided for @termTipHint.
  ///
  /// In zh, this message translates to:
  /// **'点击带虚线的术语，查看它的意思。'**
  String get termTipHint;

  /// No description provided for @termTipAbout.
  ///
  /// In zh, this message translates to:
  /// **'什么是{term}？'**
  String termTipAbout(String term);

  /// No description provided for @shenshaName.
  ///
  /// In zh, this message translates to:
  /// **'神煞'**
  String get shenshaName;

  /// No description provided for @timelineNow.
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get timelineNow;

  /// No description provided for @timelineThisYear.
  ///
  /// In zh, this message translates to:
  /// **'今年'**
  String get timelineThisYear;

  /// No description provided for @dayunTapHint.
  ///
  /// In zh, this message translates to:
  /// **'点击一步大运，查看它的十年。'**
  String get dayunTapHint;

  /// No description provided for @dayunYears.
  ///
  /// In zh, this message translates to:
  /// **'{ganzhi}大运 · {from}–{to}年'**
  String dayunYears(String ganzhi, int from, int to);

  /// No description provided for @liuyueOf.
  ///
  /// In zh, this message translates to:
  /// **'{year}年流月'**
  String liuyueOf(int year);

  /// No description provided for @pillarRelation.
  ///
  /// In zh, this message translates to:
  /// **'{pillar}{relation}'**
  String pillarRelation(String pillar, String relation);

  /// No description provided for @jumpTo.
  ///
  /// In zh, this message translates to:
  /// **'跳到'**
  String get jumpTo;

  /// No description provided for @jumpActions.
  ///
  /// In zh, this message translates to:
  /// **'行动建议'**
  String get jumpActions;

  /// No description provided for @jumpConclusion.
  ///
  /// In zh, this message translates to:
  /// **'总结'**
  String get jumpConclusion;

  /// No description provided for @shareImage.
  ///
  /// In zh, this message translates to:
  /// **'分享图片'**
  String get shareImage;

  /// No description provided for @shareImageFailed.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法生成分享图，请稍后再试。'**
  String get shareImageFailed;

  /// No description provided for @homeQiuqian.
  ///
  /// In zh, this message translates to:
  /// **'求签'**
  String get homeQiuqian;

  /// No description provided for @homeQiuqianDesc.
  ///
  /// In zh, this message translates to:
  /// **'摇签、掷筊，求一首签诗，仅供娱乐和玄学学习使用'**
  String get homeQiuqianDesc;

  /// No description provided for @qiuqianQuestion.
  ///
  /// In zh, this message translates to:
  /// **'所求之事'**
  String get qiuqianQuestion;

  /// No description provided for @qiuqianQuestionHint.
  ///
  /// In zh, this message translates to:
  /// **'先写下所求之事才能求签：有所求，才能去求。问题只用于解签，不会出现在分享图上。'**
  String get qiuqianQuestionHint;

  /// No description provided for @qiuqianQuestionMissing.
  ///
  /// In zh, this message translates to:
  /// **'先写下所求之事，才能求签'**
  String get qiuqianQuestionMissing;

  /// No description provided for @qiuqianExample1.
  ///
  /// In zh, this message translates to:
  /// **'今年的工作会顺利吗？'**
  String get qiuqianExample1;

  /// No description provided for @qiuqianExample2.
  ///
  /// In zh, this message translates to:
  /// **'这段关系该怎么经营？'**
  String get qiuqianExample2;

  /// No description provided for @qiuqianExample3.
  ///
  /// In zh, this message translates to:
  /// **'搬家的事该怎么决定？'**
  String get qiuqianExample3;

  /// No description provided for @qiuqianHowTo.
  ///
  /// In zh, this message translates to:
  /// **'摇签筒，一支签落下；再掷筊请示：圣筊（一平一凸）就是这一支，笑筊或阴筊就把签放回再摇。'**
  String get qiuqianHowTo;

  /// No description provided for @qiuqianDraw.
  ///
  /// In zh, this message translates to:
  /// **'求签'**
  String get qiuqianDraw;

  /// No description provided for @qiuqianThrow.
  ///
  /// In zh, this message translates to:
  /// **'掷筊'**
  String get qiuqianThrow;

  /// No description provided for @qiuqianAgain.
  ///
  /// In zh, this message translates to:
  /// **'放回再摇'**
  String get qiuqianAgain;

  /// No description provided for @qiuqianSkip.
  ///
  /// In zh, this message translates to:
  /// **'直接看结果'**
  String get qiuqianSkip;

  /// The character on the label of the 签筒 drawn in the 求签 animation (v9.1.0).
  ///
  /// In zh, this message translates to:
  /// **'签'**
  String get qiuqianCylinder;

  /// No description provided for @qiuqianShaking.
  ///
  /// In zh, this message translates to:
  /// **'摇签中……'**
  String get qiuqianShaking;

  /// No description provided for @qiuqianTossing.
  ///
  /// In zh, this message translates to:
  /// **'掷筊中……'**
  String get qiuqianTossing;

  /// No description provided for @qiuqianStickFell.
  ///
  /// In zh, this message translates to:
  /// **'摇出{title}'**
  String qiuqianStickFell(String title);

  /// No description provided for @qiuqianSheng.
  ///
  /// In zh, this message translates to:
  /// **'圣筊：神明应允，就是这一支'**
  String get qiuqianSheng;

  /// No description provided for @qiuqianXiao.
  ///
  /// In zh, this message translates to:
  /// **'笑筊：神明一笑，把签放回再求'**
  String get qiuqianXiao;

  /// No description provided for @qiuqianYin.
  ///
  /// In zh, this message translates to:
  /// **'阴筊：神明未允，把签放回再求'**
  String get qiuqianYin;

  /// No description provided for @qiuqianYourLot.
  ///
  /// In zh, this message translates to:
  /// **'你求得的签'**
  String get qiuqianYourLot;

  /// No description provided for @qiuqianTextNote.
  ///
  /// In zh, this message translates to:
  /// **'签诗依台湾庙宇通行文本，并以清代刻本校订。'**
  String get qiuqianTextNote;

  /// No description provided for @qiuqianSections.
  ///
  /// In zh, this message translates to:
  /// **'解签分三部分：签诗、所问之事、建议。'**
  String get qiuqianSections;

  /// No description provided for @leaveQiuqianBody.
  ///
  /// In zh, this message translates to:
  /// **'这次求得的签不会保留，下次要重新求签。已生成的解读会保存在历史记录里。'**
  String get leaveQiuqianBody;

  /// No description provided for @topicQiuqianPoem.
  ///
  /// In zh, this message translates to:
  /// **'签诗'**
  String get topicQiuqianPoem;

  /// No description provided for @topicQiuqianAnswer.
  ///
  /// In zh, this message translates to:
  /// **'所问之事'**
  String get topicQiuqianAnswer;

  /// No description provided for @topicQiuqianAdvice.
  ///
  /// In zh, this message translates to:
  /// **'建议'**
  String get topicQiuqianAdvice;

  /// No description provided for @blockFlat.
  ///
  /// In zh, this message translates to:
  /// **'平面朝上'**
  String get blockFlat;

  /// No description provided for @blockRound.
  ///
  /// In zh, this message translates to:
  /// **'凸面朝上'**
  String get blockRound;

  /// No description provided for @homeFengshui.
  ///
  /// In zh, this message translates to:
  /// **'风水'**
  String get homeFengshui;

  /// No description provided for @homeFengshuiDesc.
  ///
  /// In zh, this message translates to:
  /// **'房间布局的通用原则：采光、通风与动线，不论吉凶'**
  String get homeFengshuiDesc;

  /// No description provided for @fengshuiRoom.
  ///
  /// In zh, this message translates to:
  /// **'哪个房间'**
  String get fengshuiRoom;

  /// No description provided for @fengshuiFacing.
  ///
  /// In zh, this message translates to:
  /// **'主要窗户朝向（可不选）'**
  String get fengshuiFacing;

  /// No description provided for @fengshuiFacingUnknown.
  ///
  /// In zh, this message translates to:
  /// **'不确定'**
  String get fengshuiFacingUnknown;

  /// No description provided for @fengshuiDescription.
  ///
  /// In zh, this message translates to:
  /// **'房间现状（可不填）'**
  String get fengshuiDescription;

  /// No description provided for @fengshuiDescriptionHint.
  ///
  /// In zh, this message translates to:
  /// **'例如“床在窗下，门在左边”。只用于解读，不会保存地址或平面图。'**
  String get fengshuiDescriptionHint;

  /// No description provided for @fengshuiLook.
  ///
  /// In zh, this message translates to:
  /// **'看布局'**
  String get fengshuiLook;

  /// No description provided for @fengshuiPrinciples.
  ///
  /// In zh, this message translates to:
  /// **'这个房间可以留意'**
  String get fengshuiPrinciples;

  /// No description provided for @fengshuiNote.
  ///
  /// In zh, this message translates to:
  /// **'这些是通用的空间原则，不是对住宅吉凶的判断。'**
  String get fengshuiNote;

  /// No description provided for @fengshuiSections.
  ///
  /// In zh, this message translates to:
  /// **'解读分三部分：布局、光线与动线、建议。'**
  String get fengshuiSections;

  /// No description provided for @fengshuiDirection.
  ///
  /// In zh, this message translates to:
  /// **'传统上：{direction} · {trigram} · {element}'**
  String fengshuiDirection(String direction, String trigram, String element);

  /// No description provided for @topicFengshuiLayout.
  ///
  /// In zh, this message translates to:
  /// **'布局'**
  String get topicFengshuiLayout;

  /// No description provided for @topicFengshuiFlow.
  ///
  /// In zh, this message translates to:
  /// **'光线与动线'**
  String get topicFengshuiFlow;

  /// No description provided for @topicFengshuiAdvice.
  ///
  /// In zh, this message translates to:
  /// **'建议'**
  String get topicFengshuiAdvice;

  /// No description provided for @homeNaming.
  ///
  /// In zh, this message translates to:
  /// **'起名'**
  String get homeNaming;

  /// No description provided for @namingFromChart.
  ///
  /// In zh, this message translates to:
  /// **'为这个命盘起名'**
  String get namingFromChart;

  /// No description provided for @namingSurname.
  ///
  /// In zh, this message translates to:
  /// **'姓氏'**
  String get namingSurname;

  /// No description provided for @namingSurnameHint.
  ///
  /// In zh, this message translates to:
  /// **'一或两个汉字，例如“陈”或“欧阳”'**
  String get namingSurnameHint;

  /// No description provided for @namingLength.
  ///
  /// In zh, this message translates to:
  /// **'名字'**
  String get namingLength;

  /// No description provided for @namingOne.
  ///
  /// In zh, this message translates to:
  /// **'单字名'**
  String get namingOne;

  /// No description provided for @namingTwo.
  ///
  /// In zh, this message translates to:
  /// **'双字名'**
  String get namingTwo;

  /// No description provided for @namingSuggest.
  ///
  /// In zh, this message translates to:
  /// **'起名'**
  String get namingSuggest;

  /// No description provided for @namingElements.
  ///
  /// In zh, this message translates to:
  /// **'名字所补：{elements}'**
  String namingElements(String elements);

  /// No description provided for @namingBalance.
  ///
  /// In zh, this message translates to:
  /// **'这个命盘没有明显的喜用，名字以五行平衡为主。'**
  String get namingBalance;

  /// No description provided for @namingCandidates.
  ///
  /// In zh, this message translates to:
  /// **'候选名字'**
  String get namingCandidates;

  /// No description provided for @namingDraft.
  ///
  /// In zh, this message translates to:
  /// **'这些名字所用的字义库仍待专家校订。'**
  String get namingDraft;

  /// No description provided for @namingNote.
  ///
  /// In zh, this message translates to:
  /// **'名字是祝福与声音，不决定任何人的命运。'**
  String get namingNote;

  /// No description provided for @namingSections.
  ///
  /// In zh, this message translates to:
  /// **'解读分两部分：候选名字、怎么挑选。'**
  String get namingSections;

  /// No description provided for @topicNamingCandidates.
  ///
  /// In zh, this message translates to:
  /// **'候选名字'**
  String get topicNamingCandidates;

  /// No description provided for @topicNamingAdvice.
  ///
  /// In zh, this message translates to:
  /// **'建议'**
  String get topicNamingAdvice;

  /// No description provided for @homeLiuyao.
  ///
  /// In zh, this message translates to:
  /// **'算卦'**
  String get homeLiuyao;

  /// No description provided for @homeLiuyaoDesc.
  ///
  /// In zh, this message translates to:
  /// **'掷三枚硬币六次起卦，或自己掷好再填，马上看卦辞直说，仅供娱乐和玄学学习使用'**
  String get homeLiuyaoDesc;

  /// No description provided for @homeEast.
  ///
  /// In zh, this message translates to:
  /// **'东方'**
  String get homeEast;

  /// No description provided for @homeWest.
  ///
  /// In zh, this message translates to:
  /// **'西方'**
  String get homeWest;

  /// No description provided for @liuyaoQuestion.
  ///
  /// In zh, this message translates to:
  /// **'想问的事'**
  String get liuyaoQuestion;

  /// No description provided for @liuyaoQuestionHint.
  ///
  /// In zh, this message translates to:
  /// **'先写下想问的事才能起卦。一次只问一件事，问得越具体，解读越贴切'**
  String get liuyaoQuestionHint;

  /// No description provided for @liuyaoQuestionMissing.
  ///
  /// In zh, this message translates to:
  /// **'先写下想问的事，才能起卦'**
  String get liuyaoQuestionMissing;

  /// No description provided for @liuyaoRemind.
  ///
  /// In zh, this message translates to:
  /// **'起卦之前'**
  String get liuyaoRemind;

  /// No description provided for @liuyaoRemindBody.
  ///
  /// In zh, this message translates to:
  /// **'先静下心，把要问的事想清楚。一次只问一件事，同一件事不要一再重问。'**
  String get liuyaoRemindBody;

  /// No description provided for @liuyaoMode.
  ///
  /// In zh, this message translates to:
  /// **'起卦方式'**
  String get liuyaoMode;

  /// No description provided for @liuyaoModeAuto.
  ///
  /// In zh, this message translates to:
  /// **'自动掷币'**
  String get liuyaoModeAuto;

  /// No description provided for @liuyaoModePick.
  ///
  /// In zh, this message translates to:
  /// **'自己挑币'**
  String get liuyaoModePick;

  /// No description provided for @liuyaoModeManual.
  ///
  /// In zh, this message translates to:
  /// **'自掷自填'**
  String get liuyaoModeManual;

  /// No description provided for @liuyaoAutoHow.
  ///
  /// In zh, this message translates to:
  /// **'由系统替你掷三枚硬币，共掷六次，从下往上成卦。'**
  String get liuyaoAutoHow;

  /// No description provided for @liuyaoToss.
  ///
  /// In zh, this message translates to:
  /// **'掷币'**
  String get liuyaoToss;

  /// No description provided for @liuyaoTossNext.
  ///
  /// In zh, this message translates to:
  /// **'掷下一爻'**
  String get liuyaoTossNext;

  /// No description provided for @liuyaoSkip.
  ///
  /// In zh, this message translates to:
  /// **'直接看卦'**
  String get liuyaoSkip;

  /// No description provided for @liuyaoPickHow.
  ///
  /// In zh, this message translates to:
  /// **'24 枚硬币已经随机摆好，都扣着。凭直觉挑 18 枚，每 3 枚成一爻，从下往上。'**
  String get liuyaoPickHow;

  /// No description provided for @liuyaoPickStart.
  ///
  /// In zh, this message translates to:
  /// **'摆好硬币'**
  String get liuyaoPickStart;

  /// No description provided for @liuyaoPicked.
  ///
  /// In zh, this message translates to:
  /// **'已挑 {count} / 18 枚'**
  String liuyaoPicked(int count);

  /// No description provided for @liuyaoPickAgain.
  ///
  /// In zh, this message translates to:
  /// **'重新挑'**
  String get liuyaoPickAgain;

  /// No description provided for @liuyaoReveal.
  ///
  /// In zh, this message translates to:
  /// **'看卦'**
  String get liuyaoReveal;

  /// No description provided for @liuyaoCoin.
  ///
  /// In zh, this message translates to:
  /// **'第 {n} 枚硬币'**
  String liuyaoCoin(int n);

  /// No description provided for @liuyaoCoinFace.
  ///
  /// In zh, this message translates to:
  /// **'第 {n} 枚硬币：{face}'**
  String liuyaoCoinFace(int n, String face);

  /// No description provided for @liuyaoManualHow.
  ///
  /// In zh, this message translates to:
  /// **'三枚硬币一起掷，共掷六次，从下往上记（第一次是初爻）。有字的一面算“字”，另一面算“背”。掷之前，先记下时间。'**
  String get liuyaoManualHow;

  /// No description provided for @liuyaoTime.
  ///
  /// In zh, this message translates to:
  /// **'起卦时间（精确到分钟）'**
  String get liuyaoTime;

  /// No description provided for @liuyaoTimePick.
  ///
  /// In zh, this message translates to:
  /// **'选择时间'**
  String get liuyaoTimePick;

  /// No description provided for @liuyaoTimeNow.
  ///
  /// In zh, this message translates to:
  /// **'用现在的时间'**
  String get liuyaoTimeNow;

  /// No description provided for @liuyaoTimeMissing.
  ///
  /// In zh, this message translates to:
  /// **'请先填写起卦时间'**
  String get liuyaoTimeMissing;

  /// No description provided for @liuyaoEnterBy.
  ///
  /// In zh, this message translates to:
  /// **'填写方式'**
  String get liuyaoEnterBy;

  /// No description provided for @liuyaoByCoins.
  ///
  /// In zh, this message translates to:
  /// **'按硬币'**
  String get liuyaoByCoins;

  /// No description provided for @liuyaoByLines.
  ///
  /// In zh, this message translates to:
  /// **'按爻'**
  String get liuyaoByLines;

  /// No description provided for @liuyaoBei0.
  ///
  /// In zh, this message translates to:
  /// **'三字'**
  String get liuyaoBei0;

  /// No description provided for @liuyaoBei1.
  ///
  /// In zh, this message translates to:
  /// **'一背'**
  String get liuyaoBei1;

  /// No description provided for @liuyaoBei2.
  ///
  /// In zh, this message translates to:
  /// **'二背'**
  String get liuyaoBei2;

  /// No description provided for @liuyaoBei3.
  ///
  /// In zh, this message translates to:
  /// **'三背'**
  String get liuyaoBei3;

  /// No description provided for @liuyaoOldYin.
  ///
  /// In zh, this message translates to:
  /// **'老阴'**
  String get liuyaoOldYin;

  /// No description provided for @liuyaoYoungYang.
  ///
  /// In zh, this message translates to:
  /// **'少阳'**
  String get liuyaoYoungYang;

  /// No description provided for @liuyaoYoungYin.
  ///
  /// In zh, this message translates to:
  /// **'少阴'**
  String get liuyaoYoungYin;

  /// No description provided for @liuyaoOldYang.
  ///
  /// In zh, this message translates to:
  /// **'老阳'**
  String get liuyaoOldYang;

  /// No description provided for @liuyaoCoinZi.
  ///
  /// In zh, this message translates to:
  /// **'字'**
  String get liuyaoCoinZi;

  /// No description provided for @liuyaoCoinBei.
  ///
  /// In zh, this message translates to:
  /// **'背'**
  String get liuyaoCoinBei;

  /// No description provided for @liuyaoLine1.
  ///
  /// In zh, this message translates to:
  /// **'初爻'**
  String get liuyaoLine1;

  /// No description provided for @liuyaoLine2.
  ///
  /// In zh, this message translates to:
  /// **'二爻'**
  String get liuyaoLine2;

  /// No description provided for @liuyaoLine3.
  ///
  /// In zh, this message translates to:
  /// **'三爻'**
  String get liuyaoLine3;

  /// No description provided for @liuyaoLine4.
  ///
  /// In zh, this message translates to:
  /// **'四爻'**
  String get liuyaoLine4;

  /// No description provided for @liuyaoLine5.
  ///
  /// In zh, this message translates to:
  /// **'五爻'**
  String get liuyaoLine5;

  /// No description provided for @liuyaoLine6.
  ///
  /// In zh, this message translates to:
  /// **'上爻'**
  String get liuyaoLine6;

  /// No description provided for @liuyaoCast.
  ///
  /// In zh, this message translates to:
  /// **'起卦'**
  String get liuyaoCast;

  /// No description provided for @liuyaoPrimary.
  ///
  /// In zh, this message translates to:
  /// **'本卦'**
  String get liuyaoPrimary;

  /// No description provided for @liuyaoChanged.
  ///
  /// In zh, this message translates to:
  /// **'变卦'**
  String get liuyaoChanged;

  /// No description provided for @liuyaoNumber.
  ///
  /// In zh, this message translates to:
  /// **'第{n}卦'**
  String liuyaoNumber(int n);

  /// No description provided for @liuyaoTrigrams.
  ///
  /// In zh, this message translates to:
  /// **'上卦 {upper}\n下卦 {lower}'**
  String liuyaoTrigrams(String upper, String lower);

  /// No description provided for @liuyaoCastAt.
  ///
  /// In zh, this message translates to:
  /// **'起卦于 {time} · {year}年 {month}月 {day}日 {hour}时'**
  String liuyaoCastAt(
    String time,
    String year,
    String month,
    String day,
    String hour,
  );

  /// No description provided for @liuyaoStill.
  ///
  /// In zh, this message translates to:
  /// **'六爻皆静，看本卦卦辞。'**
  String get liuyaoStill;

  /// No description provided for @liuyaoMoving.
  ///
  /// In zh, this message translates to:
  /// **'动爻：{lines}'**
  String liuyaoMoving(String lines);

  /// No description provided for @liuyaoMain.
  ///
  /// In zh, this message translates to:
  /// **'看这一句'**
  String get liuyaoMain;

  /// No description provided for @liuyaoAlso.
  ///
  /// In zh, this message translates to:
  /// **'也看'**
  String get liuyaoAlso;

  /// No description provided for @liuyaoPlain.
  ///
  /// In zh, this message translates to:
  /// **'直说'**
  String get liuyaoPlain;

  /// No description provided for @liuyaoSections.
  ///
  /// In zh, this message translates to:
  /// **'解读分三部分：卦象、所问之事、建议。'**
  String get liuyaoSections;

  /// No description provided for @topicLiuyaoHexagram.
  ///
  /// In zh, this message translates to:
  /// **'卦象'**
  String get topicLiuyaoHexagram;

  /// No description provided for @topicLiuyaoAnswer.
  ///
  /// In zh, this message translates to:
  /// **'所问之事'**
  String get topicLiuyaoAnswer;

  /// No description provided for @topicLiuyaoAdvice.
  ///
  /// In zh, this message translates to:
  /// **'建议'**
  String get topicLiuyaoAdvice;

  /// No description provided for @leaveLiuyaoBody.
  ///
  /// In zh, this message translates to:
  /// **'这次起的卦不会保留，下次要重新起卦。已生成的解读会保存在历史记录里。'**
  String get leaveLiuyaoBody;

  /// No description provided for @followUpTitle.
  ///
  /// In zh, this message translates to:
  /// **'继续追问'**
  String get followUpTitle;

  /// No description provided for @followUpIntro.
  ///
  /// In zh, this message translates to:
  /// **'就这次的结果接着问。回答只依据这次的命盘、牌面、签诗或卦象和上面的解读，不会凭空编造；问题超出它能回答的范围时，会直接告诉你。'**
  String get followUpIntro;

  /// No description provided for @followUpHint.
  ///
  /// In zh, this message translates to:
  /// **'比如：这对我的工作意味着什么？'**
  String get followUpHint;

  /// No description provided for @followUpSend.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get followUpSend;

  /// No description provided for @followUpLeft.
  ///
  /// In zh, this message translates to:
  /// **'还可追问 {n} 次'**
  String followUpLeft(int n);

  /// No description provided for @followUpLimit.
  ///
  /// In zh, this message translates to:
  /// **'这次结果的追问次数已用完'**
  String get followUpLimit;

  /// No description provided for @followUpBusy.
  ///
  /// In zh, this message translates to:
  /// **'上一个追问还在回答，请稍候'**
  String get followUpBusy;

  /// No description provided for @followUpQuota.
  ///
  /// In zh, this message translates to:
  /// **'今天的 AI 次数已用完，请明天再来'**
  String get followUpQuota;

  /// No description provided for @followUpAnswering.
  ///
  /// In zh, this message translates to:
  /// **'AI 正在依据这次的结果作答…'**
  String get followUpAnswering;

  /// No description provided for @followUpFailed.
  ///
  /// In zh, this message translates to:
  /// **'这次没能答上，请再问一次'**
  String get followUpFailed;

  /// No description provided for @followUpHeld.
  ///
  /// In zh, this message translates to:
  /// **'这条回答需要复核，暂时不能显示'**
  String get followUpHeld;

  /// No description provided for @followUpOutOfScope.
  ///
  /// In zh, this message translates to:
  /// **'超出这次结果能回答的范围'**
  String get followUpOutOfScope;

  /// No description provided for @followUpStart.
  ///
  /// In zh, this message translates to:
  /// **'可以这样问'**
  String get followUpStart;

  /// No description provided for @followUpNext.
  ///
  /// In zh, this message translates to:
  /// **'你还可以问'**
  String get followUpNext;

  /// No description provided for @jumpFollowUp.
  ///
  /// In zh, this message translates to:
  /// **'追问'**
  String get jumpFollowUp;

  /// No description provided for @kindFollowUp.
  ///
  /// In zh, this message translates to:
  /// **'追问'**
  String get kindFollowUp;

  /// No description provided for @followUpStartBazi1.
  ///
  /// In zh, this message translates to:
  /// **'我适合什么样的工作？'**
  String get followUpStartBazi1;

  /// No description provided for @followUpStartBazi2.
  ///
  /// In zh, this message translates to:
  /// **'今年我最该注意什么？'**
  String get followUpStartBazi2;

  /// No description provided for @followUpStartTarot1.
  ///
  /// In zh, this message translates to:
  /// **'这组牌最想提醒我什么？'**
  String get followUpStartTarot1;

  /// No description provided for @followUpStartTarot2.
  ///
  /// In zh, this message translates to:
  /// **'我现在最该做的一步是什么？'**
  String get followUpStartTarot2;

  /// No description provided for @followUpStartQiuqian1.
  ///
  /// In zh, this message translates to:
  /// **'签诗里哪一句最要紧？'**
  String get followUpStartQiuqian1;

  /// No description provided for @followUpStartQiuqian2.
  ///
  /// In zh, this message translates to:
  /// **'这件事我该先做什么？'**
  String get followUpStartQiuqian2;

  /// No description provided for @followUpStartLiuyao1.
  ///
  /// In zh, this message translates to:
  /// **'动爻在提醒我什么？'**
  String get followUpStartLiuyao1;

  /// No description provided for @followUpStartLiuyao2.
  ///
  /// In zh, this message translates to:
  /// **'这件事我该等还是该动？'**
  String get followUpStartLiuyao2;

  /// No description provided for @followUpStartFengshui1.
  ///
  /// In zh, this message translates to:
  /// **'我先改哪一处最容易？'**
  String get followUpStartFengshui1;

  /// No description provided for @followUpStartFengshui2.
  ///
  /// In zh, this message translates to:
  /// **'书桌放在哪里比较好？'**
  String get followUpStartFengshui2;

  /// No description provided for @followUpStartNaming1.
  ///
  /// In zh, this message translates to:
  /// **'这几个名字怎么选？'**
  String get followUpStartNaming1;

  /// No description provided for @followUpStartNaming2.
  ///
  /// In zh, this message translates to:
  /// **'第一个名字的字义是什么？'**
  String get followUpStartNaming2;

  /// No description provided for @followUpStartLife1.
  ///
  /// In zh, this message translates to:
  /// **'我哪个阶段最需要用心？'**
  String get followUpStartLife1;

  /// No description provided for @followUpStartLife2.
  ///
  /// In zh, this message translates to:
  /// **'命爻对我的工作意味着什么？'**
  String get followUpStartLife2;

  /// No description provided for @followUpAsked.
  ///
  /// In zh, this message translates to:
  /// **'问：'**
  String get followUpAsked;

  /// No description provided for @archiveByTime.
  ///
  /// In zh, this message translates to:
  /// **'按时间'**
  String get archiveByTime;

  /// No description provided for @archiveByPerson.
  ///
  /// In zh, this message translates to:
  /// **'按人'**
  String get archiveByPerson;

  /// No description provided for @archiveYear.
  ///
  /// In zh, this message translates to:
  /// **'{year} 年'**
  String archiveYear(int year);

  /// No description provided for @archiveMonth.
  ///
  /// In zh, this message translates to:
  /// **'{month} 月'**
  String archiveMonth(int month);

  /// No description provided for @archiveUnfiled.
  ///
  /// In zh, this message translates to:
  /// **'未归类'**
  String get archiveUnfiled;

  /// No description provided for @archiveCount.
  ///
  /// In zh, this message translates to:
  /// **'{n} 条'**
  String archiveCount(int n);

  /// No description provided for @archiveSelect.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get archiveSelect;

  /// No description provided for @archiveSelected.
  ///
  /// In zh, this message translates to:
  /// **'已选 {n} 项'**
  String archiveSelected(int n);

  /// No description provided for @archiveSelectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get archiveSelectAll;

  /// No description provided for @archiveSend.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get archiveSend;

  /// No description provided for @archiveDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get archiveDelete;

  /// No description provided for @archiveDownloadPdf.
  ///
  /// In zh, this message translates to:
  /// **'下载 PDF'**
  String get archiveDownloadPdf;

  /// No description provided for @archiveDownloadWord.
  ///
  /// In zh, this message translates to:
  /// **'下载 Word'**
  String get archiveDownloadWord;

  /// No description provided for @archiveFile.
  ///
  /// In zh, this message translates to:
  /// **'归类到…'**
  String get archiveFile;

  /// No description provided for @archiveFormatTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择文档格式'**
  String get archiveFormatTitle;

  /// No description provided for @archiveFormatPdf.
  ///
  /// In zh, this message translates to:
  /// **'PDF'**
  String get archiveFormatPdf;

  /// No description provided for @archiveFormatWord.
  ///
  /// In zh, this message translates to:
  /// **'Word 文档'**
  String get archiveFormatWord;

  /// No description provided for @archiveDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除这些记录？'**
  String get archiveDeleteTitle;

  /// No description provided for @archiveDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'将删除 {n} 条记录，连同它们的追问和破除运势方案。删除后无法恢复。'**
  String archiveDeleteBody(int n);

  /// No description provided for @archiveDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {n} 条记录'**
  String archiveDeleted(int n);

  /// No description provided for @archiveFileHint.
  ///
  /// In zh, this message translates to:
  /// **'其他名字'**
  String get archiveFileHint;

  /// No description provided for @archiveFileNone.
  ///
  /// In zh, this message translates to:
  /// **'不归类'**
  String get archiveFileNone;

  /// No description provided for @archiveWorking.
  ///
  /// In zh, this message translates to:
  /// **'正在生成文档…'**
  String get archiveWorking;

  /// No description provided for @archiveNotReady.
  ///
  /// In zh, this message translates to:
  /// **'只有已完成的记录能下载或发送'**
  String get archiveNotReady;

  /// No description provided for @archiveDocFailed.
  ///
  /// In zh, this message translates to:
  /// **'文档没能生成，请稍后再试'**
  String get archiveDocFailed;

  /// No description provided for @archiveMethod.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get archiveMethod;

  /// No description provided for @archiveTime.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get archiveTime;

  /// No description provided for @menu.
  ///
  /// In zh, this message translates to:
  /// **'菜单'**
  String get menu;

  /// No description provided for @settingsAccountGroup.
  ///
  /// In zh, this message translates to:
  /// **'账号与登录'**
  String get settingsAccountGroup;

  /// No description provided for @loginField.
  ///
  /// In zh, this message translates to:
  /// **'用户名 / 邮箱 / 手机号'**
  String get loginField;

  /// No description provided for @loginFieldHint.
  ///
  /// In zh, this message translates to:
  /// **'手机号要先在“设置”里绑定'**
  String get loginFieldHint;

  /// No description provided for @username.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// No description provided for @usernameHint.
  ///
  /// In zh, this message translates to:
  /// **'2–24 个字：字母、数字、汉字或 _ . -，以字母或汉字开头'**
  String get usernameHint;

  /// No description provided for @emailOptional.
  ///
  /// In zh, this message translates to:
  /// **'邮箱（选填）'**
  String get emailOptional;

  /// No description provided for @loginFailed.
  ///
  /// In zh, this message translates to:
  /// **'账号或密码不正确'**
  String get loginFailed;

  /// No description provided for @usernameTaken.
  ///
  /// In zh, this message translates to:
  /// **'这个用户名已被使用'**
  String get usernameTaken;

  /// No description provided for @emailTaken.
  ///
  /// In zh, this message translates to:
  /// **'这个邮箱已注册，请直接登录'**
  String get emailTaken;

  /// No description provided for @emailInvalid.
  ///
  /// In zh, this message translates to:
  /// **'邮箱格式不正确'**
  String get emailInvalid;

  /// No description provided for @passwordWeak.
  ///
  /// In zh, this message translates to:
  /// **'密码至少要 10 个字符'**
  String get passwordWeak;

  /// No description provided for @phone.
  ///
  /// In zh, this message translates to:
  /// **'手机号'**
  String get phone;

  /// No description provided for @notSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get notSet;

  /// No description provided for @emailVerifiedLabel.
  ///
  /// In zh, this message translates to:
  /// **'已验证'**
  String get emailVerifiedLabel;

  /// No description provided for @emailUnverifiedLabel.
  ///
  /// In zh, this message translates to:
  /// **'未验证，点此验证'**
  String get emailUnverifiedLabel;

  /// No description provided for @phoneUnbound.
  ///
  /// In zh, this message translates to:
  /// **'未绑定，点此绑定'**
  String get phoneUnbound;

  /// No description provided for @loginsNote.
  ///
  /// In zh, this message translates to:
  /// **'用户名、邮箱和已绑定的手机号都能用来登录，密码相同'**
  String get loginsNote;

  /// No description provided for @usernameTitle.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get usernameTitle;

  /// No description provided for @usernameSaved.
  ///
  /// In zh, this message translates to:
  /// **'用户名已保存'**
  String get usernameSaved;

  /// No description provided for @bindPhoneTitle.
  ///
  /// In zh, this message translates to:
  /// **'绑定手机号'**
  String get bindPhoneTitle;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In zh, this message translates to:
  /// **'验证邮箱'**
  String get verifyEmailTitle;

  /// No description provided for @phoneHint.
  ///
  /// In zh, this message translates to:
  /// **'本地号码直接填写；其他地区的号码请加区号，如 +65 9123 4567'**
  String get phoneHint;

  /// No description provided for @sendCode.
  ///
  /// In zh, this message translates to:
  /// **'发送验证码'**
  String get sendCode;

  /// No description provided for @resendCode.
  ///
  /// In zh, this message translates to:
  /// **'重新发送'**
  String get resendCode;

  /// No description provided for @codeField.
  ///
  /// In zh, this message translates to:
  /// **'验证码'**
  String get codeField;

  /// No description provided for @codeSentTo.
  ///
  /// In zh, this message translates to:
  /// **'验证码已发送到 {to}，10 分钟内有效'**
  String codeSentTo(String to);

  /// No description provided for @outboxNotice.
  ///
  /// In zh, this message translates to:
  /// **'测试环境：还没有接入短信和邮件服务，验证码不会真的发出，而是写在服务器的 .outbox 文件夹里。'**
  String get outboxNotice;

  /// No description provided for @confirmBind.
  ///
  /// In zh, this message translates to:
  /// **'绑定'**
  String get confirmBind;

  /// No description provided for @confirmVerify.
  ///
  /// In zh, this message translates to:
  /// **'验证'**
  String get confirmVerify;

  /// No description provided for @unbindPhone.
  ///
  /// In zh, this message translates to:
  /// **'解绑'**
  String get unbindPhone;

  /// No description provided for @removeEmail.
  ///
  /// In zh, this message translates to:
  /// **'删除邮箱'**
  String get removeEmail;

  /// No description provided for @phoneBoundDone.
  ///
  /// In zh, this message translates to:
  /// **'手机号已绑定'**
  String get phoneBoundDone;

  /// No description provided for @phoneUnboundDone.
  ///
  /// In zh, this message translates to:
  /// **'手机号已解绑'**
  String get phoneUnboundDone;

  /// No description provided for @emailVerifiedDone.
  ///
  /// In zh, this message translates to:
  /// **'邮箱已验证'**
  String get emailVerifiedDone;

  /// No description provided for @emailRemovedDone.
  ///
  /// In zh, this message translates to:
  /// **'邮箱已删除'**
  String get emailRemovedDone;

  /// No description provided for @codeWrong.
  ///
  /// In zh, this message translates to:
  /// **'验证码不对，请再看一下'**
  String get codeWrong;

  /// No description provided for @codeExpired.
  ///
  /// In zh, this message translates to:
  /// **'验证码已过期，请重新发送'**
  String get codeExpired;

  /// No description provided for @codeVoid.
  ///
  /// In zh, this message translates to:
  /// **'验证码已失效，请重新发送'**
  String get codeVoid;

  /// No description provided for @codeWait.
  ///
  /// In zh, this message translates to:
  /// **'发送太频繁，请稍后再试'**
  String get codeWait;

  /// No description provided for @phoneTaken.
  ///
  /// In zh, this message translates to:
  /// **'这个手机号已绑定其他账号'**
  String get phoneTaken;

  /// No description provided for @phoneInvalid.
  ///
  /// In zh, this message translates to:
  /// **'手机号格式不正确'**
  String get phoneInvalid;

  /// No description provided for @alreadyBound.
  ///
  /// In zh, this message translates to:
  /// **'已经绑定好了'**
  String get alreadyBound;

  /// No description provided for @lastLogin.
  ///
  /// In zh, this message translates to:
  /// **'至少要保留一种登录方式：用户名、邮箱或手机号'**
  String get lastLogin;

  /// No description provided for @deliveryOff.
  ///
  /// In zh, this message translates to:
  /// **'服务器还没有接入短信或邮件服务'**
  String get deliveryOff;

  /// No description provided for @settingsReportsGroup.
  ///
  /// In zh, this message translates to:
  /// **'报告'**
  String get settingsReportsGroup;

  /// No description provided for @emailReports.
  ///
  /// In zh, this message translates to:
  /// **'测算完成后发到邮箱'**
  String get emailReports;

  /// No description provided for @emailReportsOn.
  ///
  /// In zh, this message translates to:
  /// **'每次 AI 测算完成，报告都会发到 {email}'**
  String emailReportsOn(String email);

  /// No description provided for @emailReportsOff.
  ///
  /// In zh, this message translates to:
  /// **'开启后，每次 AI 测算完成都会把报告发到 {email}'**
  String emailReportsOff(String email);

  /// No description provided for @emailReportsNeedsEmail.
  ///
  /// In zh, this message translates to:
  /// **'先在上面验证邮箱，才能开启'**
  String get emailReportsNeedsEmail;

  /// No description provided for @mailOutboxNotice.
  ///
  /// In zh, this message translates to:
  /// **'测试环境：还没有接入邮件服务，邮件写在服务器的 .outbox 文件夹里，不会真的发出。'**
  String get mailOutboxNotice;

  /// No description provided for @mailOffNotice.
  ///
  /// In zh, this message translates to:
  /// **'服务器还没有接入邮件服务，暂时不会发出。'**
  String get mailOffNotice;

  /// No description provided for @archiveEmail.
  ///
  /// In zh, this message translates to:
  /// **'发到邮箱'**
  String get archiveEmail;

  /// No description provided for @archiveEmailShort.
  ///
  /// In zh, this message translates to:
  /// **'发邮箱'**
  String get archiveEmailShort;

  /// No description provided for @emailFirst.
  ///
  /// In zh, this message translates to:
  /// **'先在“设置”里验证邮箱，才能发到邮箱'**
  String get emailFirst;

  /// No description provided for @emailedTo.
  ///
  /// In zh, this message translates to:
  /// **'已发到 {to}'**
  String emailedTo(String to);

  /// No description provided for @emailedOutbox.
  ///
  /// In zh, this message translates to:
  /// **'已发到 {to}（测试环境：写在服务器的 .outbox 文件夹里）'**
  String emailedOutbox(String to);

  /// No description provided for @emailFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能发出，请稍后再试'**
  String get emailFailed;

  /// No description provided for @emailTooMany.
  ///
  /// In zh, this message translates to:
  /// **'今天发得太多了，明天再试'**
  String get emailTooMany;

  /// No description provided for @reportMailed.
  ///
  /// In zh, this message translates to:
  /// **'这份报告已发到你的邮箱'**
  String get reportMailed;

  /// No description provided for @reportMailFailed.
  ///
  /// In zh, this message translates to:
  /// **'这份报告没能发到邮箱，可以在“以往记录”里再发一次'**
  String get reportMailFailed;

  /// No description provided for @inquiryButton.
  ///
  /// In zh, this message translates to:
  /// **'深度分析'**
  String get inquiryButton;

  /// No description provided for @inquiryButtonNote.
  ///
  /// In zh, this message translates to:
  /// **'大师先问你几个问题（最多 {n} 个），再给出更贴合你的最终解答'**
  String inquiryButtonNote(int n);

  /// No description provided for @inquiryGoalTitle.
  ///
  /// In zh, this message translates to:
  /// **'先说说你的目标'**
  String get inquiryGoalTitle;

  /// No description provided for @inquiryGoalBody.
  ///
  /// In zh, this message translates to:
  /// **'使用深度分析，一定要先给出一个明确的目标：你最想通过这次测算知道什么？'**
  String get inquiryGoalBody;

  /// No description provided for @inquiryGoalHint.
  ///
  /// In zh, this message translates to:
  /// **'比如：明年适不适合换工作？'**
  String get inquiryGoalHint;

  /// No description provided for @inquiryGoalShort.
  ///
  /// In zh, this message translates to:
  /// **'目标太短了，请写清楚你最想知道什么'**
  String get inquiryGoalShort;

  /// No description provided for @inquiryGoalStart.
  ///
  /// In zh, this message translates to:
  /// **'开始深度分析'**
  String get inquiryGoalStart;

  /// No description provided for @inquiryTitle.
  ///
  /// In zh, this message translates to:
  /// **'深度分析'**
  String get inquiryTitle;

  /// No description provided for @inquiryAsking.
  ///
  /// In zh, this message translates to:
  /// **'大师现在有问题要问你'**
  String get inquiryAsking;

  /// No description provided for @inquiryAskingNote.
  ///
  /// In zh, this message translates to:
  /// **'回答完这些问题，大师才能给你最终解答。'**
  String get inquiryAskingNote;

  /// No description provided for @inquiryGoalLine.
  ///
  /// In zh, this message translates to:
  /// **'你的目标：{goal}'**
  String inquiryGoalLine(String goal);

  /// No description provided for @inquiryProgress.
  ///
  /// In zh, this message translates to:
  /// **'第 {n} 个问题 · 大师打算问 {planned} 个（最多 {max} 个）'**
  String inquiryProgress(int n, int planned, int max);

  /// No description provided for @inquiryThinking.
  ///
  /// In zh, this message translates to:
  /// **'大师正在思考…'**
  String get inquiryThinking;

  /// No description provided for @inquiryMaster.
  ///
  /// In zh, this message translates to:
  /// **'大师'**
  String get inquiryMaster;

  /// No description provided for @inquiryYou.
  ///
  /// In zh, this message translates to:
  /// **'你'**
  String get inquiryYou;

  /// No description provided for @inquiryAnswerHint.
  ///
  /// In zh, this message translates to:
  /// **'说说你的情况'**
  String get inquiryAnswerHint;

  /// No description provided for @inquiryAnswerSend.
  ///
  /// In zh, this message translates to:
  /// **'回答'**
  String get inquiryAnswerSend;

  /// No description provided for @inquirySkip.
  ///
  /// In zh, this message translates to:
  /// **'跳过剩下的问题，直接解答'**
  String get inquirySkip;

  /// No description provided for @inquiryReady.
  ///
  /// In zh, this message translates to:
  /// **'大师已经了解你的情况，可以开始最终解答了。'**
  String get inquiryReady;

  /// No description provided for @inquiryUnderstanding.
  ///
  /// In zh, this message translates to:
  /// **'大师的理解：{text}'**
  String inquiryUnderstanding(String text);

  /// No description provided for @inquiryStartReading.
  ///
  /// In zh, this message translates to:
  /// **'开始最终解答'**
  String get inquiryStartReading;

  /// No description provided for @inquiryFailed.
  ///
  /// In zh, this message translates to:
  /// **'大师这次没能想好问题。可以重新开始深度分析，或者回到上一页直接生成解读。'**
  String get inquiryFailed;

  /// No description provided for @inquiryRetry.
  ///
  /// In zh, this message translates to:
  /// **'重新开始'**
  String get inquiryRetry;

  /// No description provided for @inquiryBusy.
  ///
  /// In zh, this message translates to:
  /// **'大师还在思考，请稍候'**
  String get inquiryBusy;

  /// No description provided for @inquiryLeaveBody.
  ///
  /// In zh, this message translates to:
  /// **'深度分析还没做完，返回后这次的问答就结束了。'**
  String get inquiryLeaveBody;

  /// No description provided for @inquiryCardTitle.
  ///
  /// In zh, this message translates to:
  /// **'深度分析 · 大师问了你 {n} 个问题'**
  String inquiryCardTitle(int n);

  /// No description provided for @micStart.
  ///
  /// In zh, this message translates to:
  /// **'语音输入'**
  String get micStart;

  /// No description provided for @micStop.
  ///
  /// In zh, this message translates to:
  /// **'停止语音输入'**
  String get micStop;

  /// No description provided for @micListening.
  ///
  /// In zh, this message translates to:
  /// **'正在听，请说话…'**
  String get micListening;

  /// No description provided for @micUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'这个浏览器暂时不能语音输入，可以用输入法自带的语音输入'**
  String get micUnavailable;

  /// No description provided for @micDenied.
  ///
  /// In zh, this message translates to:
  /// **'需要允许使用麦克风，才能语音输入'**
  String get micDenied;

  /// No description provided for @micNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'没听清，请再说一次'**
  String get micNoMatch;

  /// No description provided for @recalcTitle.
  ///
  /// In zh, this message translates to:
  /// **'之前已经算过'**
  String get recalcTitle;

  /// No description provided for @recalcBody.
  ///
  /// In zh, this message translates to:
  /// **'“{name}”在 {date} 已经算过{method}。是否还要重新再算一次？'**
  String recalcBody(String name, String date, String method);

  /// No description provided for @recalcBodyQuestion.
  ///
  /// In zh, this message translates to:
  /// **'“{name}”在 {date} 已经算过{method}，问的是“{question}”。是否还要重新再算一次？'**
  String recalcBodyQuestion(
    String name,
    String date,
    String method,
    String question,
  );

  /// No description provided for @recalcView.
  ///
  /// In zh, this message translates to:
  /// **'查看之前的'**
  String get recalcView;

  /// No description provided for @recalcAgain.
  ///
  /// In zh, this message translates to:
  /// **'重新再算'**
  String get recalcAgain;

  /// No description provided for @accountSuspended.
  ///
  /// In zh, this message translates to:
  /// **'这个账号已被管理员停用，暂时不能登录。如有疑问请联系客服。'**
  String get accountSuspended;

  /// No description provided for @pointsTitle.
  ///
  /// In zh, this message translates to:
  /// **'我的积分'**
  String get pointsTitle;

  /// No description provided for @pointsAvailable.
  ///
  /// In zh, this message translates to:
  /// **'可用积分'**
  String get pointsAvailable;

  /// No description provided for @pointsBalanceLine.
  ///
  /// In zh, this message translates to:
  /// **'余额 {balance} 积分'**
  String pointsBalanceLine(int balance);

  /// No description provided for @pointsHeldLine.
  ///
  /// In zh, this message translates to:
  /// **'进行中的测算先冻结了 {held} 积分，完成后按实际用量扣除，多的退回'**
  String pointsHeldLine(int held);

  /// No description provided for @pointsTopUp.
  ///
  /// In zh, this message translates to:
  /// **'充值'**
  String get pointsTopUp;

  /// No description provided for @pointsTopUpSimulated.
  ///
  /// In zh, this message translates to:
  /// **'测试阶段为模拟充值：不收钱，点一下积分就到账。'**
  String get pointsTopUpSimulated;

  /// No description provided for @pointsTopUpUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'充值即将开放：正式支付会在下一阶段接入。'**
  String get pointsTopUpUnavailable;

  /// No description provided for @pointsPackYuan.
  ///
  /// In zh, this message translates to:
  /// **'{yuan} 元'**
  String pointsPackYuan(int yuan);

  /// No description provided for @pointsPackPoints.
  ///
  /// In zh, this message translates to:
  /// **'{points} 积分'**
  String pointsPackPoints(int points);

  /// No description provided for @pointsPackBonus.
  ///
  /// In zh, this message translates to:
  /// **'多送 {percent}%'**
  String pointsPackBonus(int percent);

  /// No description provided for @pointsToppedUp.
  ///
  /// In zh, this message translates to:
  /// **'已充值 {points} 积分（模拟，未收费）'**
  String pointsToppedUp(int points);

  /// No description provided for @pointsHowTitle.
  ///
  /// In zh, this message translates to:
  /// **'怎么计费'**
  String get pointsHowTitle;

  /// No description provided for @pointsHow.
  ///
  /// In zh, this message translates to:
  /// **'每次 AI 测算先按预估冻结积分，完成后按这次实际用掉的 AI 用量扣除，多冻结的退回；没有完成、没有给出结果的不扣。深度分析统一收费，不论大师问几个问题；之后的最终解读另计。'**
  String get pointsHow;

  /// No description provided for @pointsEntries.
  ///
  /// In zh, this message translates to:
  /// **'积分明细'**
  String get pointsEntries;

  /// No description provided for @pointsNoEntries.
  ///
  /// In zh, this message translates to:
  /// **'还没有积分记录'**
  String get pointsNoEntries;

  /// No description provided for @pointsBazi.
  ///
  /// In zh, this message translates to:
  /// **'八字'**
  String get pointsBazi;

  /// No description provided for @pointsForReading.
  ///
  /// In zh, this message translates to:
  /// **'{method} AI 解读'**
  String pointsForReading(String method);

  /// No description provided for @pointsForInquiry.
  ///
  /// In zh, this message translates to:
  /// **'{method} 深度分析'**
  String pointsForInquiry(String method);

  /// No description provided for @pointsGrantDev.
  ///
  /// In zh, this message translates to:
  /// **'开发测试赠送'**
  String get pointsGrantDev;

  /// No description provided for @pointsGrantAdmin.
  ///
  /// In zh, this message translates to:
  /// **'管理员赠送'**
  String get pointsGrantAdmin;

  /// No description provided for @pointsTopUpEntry.
  ///
  /// In zh, this message translates to:
  /// **'充值 {yuan} 元（模拟）'**
  String pointsTopUpEntry(int yuan);

  /// No description provided for @pointsBasisMeasured.
  ///
  /// In zh, this message translates to:
  /// **'按实际用量'**
  String get pointsBasisMeasured;

  /// No description provided for @pointsBasisEstimate.
  ///
  /// In zh, this message translates to:
  /// **'演示模式，按预估'**
  String get pointsBasisEstimate;

  /// No description provided for @pointsBasisFlat.
  ///
  /// In zh, this message translates to:
  /// **'统一收费'**
  String get pointsBasisFlat;

  /// No description provided for @pointsCost.
  ///
  /// In zh, this message translates to:
  /// **'AI 成本 {usd} 美元'**
  String pointsCost(String usd);

  /// No description provided for @pointsAbout.
  ///
  /// In zh, this message translates to:
  /// **'约 {points} 积分'**
  String pointsAbout(int points);

  /// No description provided for @pointsAboutLine.
  ///
  /// In zh, this message translates to:
  /// **'约 {points} 积分 · 完成后按实际用量扣除 · 可用 {available}'**
  String pointsAboutLine(int points, int available);

  /// No description provided for @pointsInquiryFee.
  ///
  /// In zh, this message translates to:
  /// **'统一收费 {points} 积分，不论问几个问题；最终解读另计'**
  String pointsInquiryFee(int points);

  /// No description provided for @pointsShortTitle.
  ///
  /// In zh, this message translates to:
  /// **'积分不足'**
  String get pointsShortTitle;

  /// No description provided for @pointsShortBody.
  ///
  /// In zh, this message translates to:
  /// **'这次约需 {need} 积分，你现在可用 {available} 积分。充值后再试一次。'**
  String pointsShortBody(int need, int available);

  /// No description provided for @pointsGoTopUp.
  ///
  /// In zh, this message translates to:
  /// **'去充值'**
  String get pointsGoTopUp;

  /// No description provided for @pointsFollowUpLeft.
  ///
  /// In zh, this message translates to:
  /// **'还可追问 {n} 次 · 每问约 {points} 积分'**
  String pointsFollowUpLeft(int n, int points);

  /// No description provided for @remedyConfirmPoints.
  ///
  /// In zh, this message translates to:
  /// **'“{topic}”的破除运势方案约需 {points} 积分，生成后按实际用量从积分中扣除。'**
  String remedyConfirmPoints(String topic, int points);

  /// No description provided for @adminDashboard.
  ///
  /// In zh, this message translates to:
  /// **'管理后台'**
  String get adminDashboard;

  /// No description provided for @adminDashboardOpen.
  ///
  /// In zh, this message translates to:
  /// **'以{role}身份，在新标签页打开'**
  String adminDashboardOpen(String role);

  /// No description provided for @adminDashboardCopy.
  ///
  /// In zh, this message translates to:
  /// **'以{role}身份：复制地址，在浏览器里打开'**
  String adminDashboardCopy(String role);

  /// No description provided for @adminLinkCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制管理后台的地址：{url}'**
  String adminLinkCopied(String url);

  /// No description provided for @staffAdmin.
  ///
  /// In zh, this message translates to:
  /// **'管理员'**
  String get staffAdmin;

  /// No description provided for @staffManager.
  ///
  /// In zh, this message translates to:
  /// **'经理'**
  String get staffManager;

  /// No description provided for @staffIntegrator.
  ///
  /// In zh, this message translates to:
  /// **'集成人员'**
  String get staffIntegrator;
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
      <String>['zh'].contains(locale.languageCode);

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
