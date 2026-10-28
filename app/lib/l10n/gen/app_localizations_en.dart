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
      'Four pillars, luck pillars and years from your birth time, or a whole-life report';

  @override
  String get homeTarot => 'Tarot';

  @override
  String get homeTarotDesc =>
      'Draw a spread, for entertainment and metaphysics study only';

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
    return 'nominal age $age';
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
  String get topicTarotCards => 'Card by card';

  @override
  String get topicTarotSynthesis => 'The whole spread';

  @override
  String get topicTarotAdvice => 'Advice';

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
  String get retry => 'Retry';

  @override
  String get errorTitle => 'Couldn\'t complete the request';

  @override
  String get disclaimerShort =>
      'For entertainment and metaphysics study only, not a prediction.';

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
    return 'Nominal age $ages';
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

  @override
  String get placePick => 'Choose birthplace';

  @override
  String get placeCountry => 'Country or region';

  @override
  String get placeRegion => 'Province / state';

  @override
  String get placeCity => 'City';

  @override
  String get placeSearch => 'Search';

  @override
  String get placeCommon => 'Common';

  @override
  String get placeAll => 'All';

  @override
  String get placeNone => 'No match';

  @override
  String placeDetail(String tz, String lon) {
    return 'Time zone $tz · longitude $lon';
  }

  @override
  String get placeSource => 'Place data: GeoNames (CC BY 4.0)';

  @override
  String serverUnreachable(String url) {
    return 'Can\'t reach the server at $url.\nOn a phone, 127.0.0.1 is the phone itself: start `npm run api:lan` on the computer and open http://<computer\'s Wi-Fi address>:5000. From an https page, add ?api=<https server address> to the page URL.';
  }

  @override
  String get lifeTitle => 'Your situation (optional)';

  @override
  String get lifeHint =>
      'Two people born at the same time and place share a chart; your situation is what makes the reading yours. Stored on this device; sent to the AI only with a reading.';

  @override
  String get lifeUseName => 'Address me by name in readings';

  @override
  String get lifeResidence => 'Where you live now';

  @override
  String get lifeNotSet => 'Not set';

  @override
  String get lifeMarital => 'Relationship status';

  @override
  String get maritalSingle => 'Single';

  @override
  String get maritalDating => 'In a relationship';

  @override
  String get maritalMarried => 'Married';

  @override
  String get maritalSeparated => 'Separated';

  @override
  String get maritalDivorced => 'Divorced';

  @override
  String get maritalWidowed => 'Widowed';

  @override
  String get lifeChildren => 'Children';

  @override
  String get childrenNone => 'None';

  @override
  String get childrenHas => 'Yes';

  @override
  String get lifeOccupation => 'Occupation / industry';

  @override
  String get lifeFamily => 'Family situation';

  @override
  String get lifeFamilyHint => 'e.g. live with my parents, caring for an elder';

  @override
  String get lifeConcern => 'What do you want to know?';

  @override
  String get lifeConcernHint => 'e.g. is next year good for changing jobs?';

  @override
  String get sectionSummary => 'In short';

  @override
  String get remedyReady => 'Ready';

  @override
  String get lifeEntry => 'Life report';

  @override
  String get lifeEntryDesc =>
      'I Ching natal hexagram, Plum Blossom and Five Elements, read together over a whole life';

  @override
  String get lifeGenerate => 'Create life report';

  @override
  String get lifeSubtitle =>
      'I Ching natal hexagram  |  Plum Blossom  |  Five Elements';

  @override
  String lifeReportOf(String name) {
    return '$name · Life report';
  }

  @override
  String get lifeItem => 'Item';

  @override
  String get lifeContent => 'Details';

  @override
  String get lifeName => 'Name';

  @override
  String get lifeBirthLunar => 'Born (lunar)';

  @override
  String get lifeBirthSolar => 'Born (Gregorian)';

  @override
  String get lifeBirthPlace => 'Birthplace';

  @override
  String get lifeTrueSolar => 'True solar time';

  @override
  String get lifeGanzhi => 'Four pillars';

  @override
  String get lifeNote =>
      'This report follows traditional methods and is for entertainment and metaphysics study only, not scientific prediction. The three methods are worked out separately and then read together.';

  @override
  String get lifeSec1 => '1. I Ching natal hexagram';

  @override
  String get lifeQigua => 'Casting';

  @override
  String get lifeBenGua => 'Natal hexagram';

  @override
  String get lifeHuGua => 'Nuclear';

  @override
  String get lifeZhiGuaShort => 'Changed';

  @override
  String get lifeGuaYi => 'Meaning: the base tone of a life';

  @override
  String get lifeMingYao => 'The life line';

  @override
  String get lifeZhiGua => 'Changed hexagram: where life arrives';

  @override
  String get lifeSixLines => 'Six lines and life stages';

  @override
  String get lifeLine => 'Line';

  @override
  String get lifeAge => 'Age';

  @override
  String get lifeYaoCi => 'Line text';

  @override
  String get lifeForLife => 'For your life';

  @override
  String get lifeSec2 => '2. Plum Blossom numerology';

  @override
  String get lifeMhGua => 'Trigram';

  @override
  String get lifeMhRel => 'To the self trigram';

  @override
  String get lifeMhStage => 'Governs';

  @override
  String get lifeTi => 'Self (体)';

  @override
  String get lifeYong => 'Use (用)';

  @override
  String get lifeHu => 'Nuclear (互)';

  @override
  String get lifeBian => 'Changed (变)';

  @override
  String get lifeSelf => 'Yourself';

  @override
  String get lifeEarly => 'Early life';

  @override
  String get lifeMiddle => 'Middle age';

  @override
  String get lifeLate => 'Later life';

  @override
  String get lifeSeason => 'Season';

  @override
  String get lifeMhConclusion => 'Plum Blossom conclusion';

  @override
  String get relBihe => 'Harmony';

  @override
  String get relShengti => 'Supports you';

  @override
  String get relTisheng => 'Drains you';

  @override
  String get relTike => 'You control it (effort brings gain)';

  @override
  String get relKeti => 'Pressures you';

  @override
  String get lifeSec3 => '3. Five Elements and Eight Mansions';

  @override
  String get lifeWuxingDist => 'Five Elements (weighted, simplified)';

  @override
  String get lifeFavorable => 'Favourable';

  @override
  String get lifeUnfavorable => 'Unfavourable';

  @override
  String get lifeBazhai => 'Eight Mansions life gua';

  @override
  String lifeKua(String kua, String name, String group, String wuxing) {
    return 'Life gua $kua · $name ($group, $wuxing)';
  }

  @override
  String get lifeDaily => 'Everyday use';

  @override
  String get lifeSec4 => '4. Life topics';

  @override
  String get lifeTopicPersonality => 'Personality';

  @override
  String get lifeTopicCareer => 'Career';

  @override
  String get lifeTopicWealth => 'Money';

  @override
  String get lifeTopicRelationships => 'Love and marriage';

  @override
  String get lifeTopicChildren => 'Family and children';

  @override
  String get lifeTopicParents => 'Parents';

  @override
  String get lifeTopicHealth => 'Wellbeing';

  @override
  String get lifeSec5 => '5. Life stages';

  @override
  String get lifeYears => 'Years';

  @override
  String get lifeFortune => 'Outlook';

  @override
  String get lifeFocus => 'Focus';

  @override
  String get lifeSec6 => '6. Overall reading and advice';

  @override
  String get lifeDownload => 'Download report package';

  @override
  String get lifePrint => 'Print / save as PDF';

  @override
  String get lifeGenerating => 'AI is writing your life report…';

  @override
  String get lifeStageMethods =>
      'Reading the I Ching, Plum Blossom and Eight Mansions';

  @override
  String get lifeStageTopics => 'Writing the topics and life stages';

  @override
  String get lifeTook =>
      'About 3–5 minutes. You can leave this page; it keeps going.';

  @override
  String get lifeDirection => 'Direction';

  @override
  String get lifeStar => 'Star';

  @override
  String get lifeLuck => 'Luck';

  @override
  String get lifeMhName => 'Name';

  @override
  String get lifeWuxing => 'Element';

  @override
  String get reviewTitle => 'Content review';

  @override
  String get reviewEmpty => 'Nothing is waiting for review.';

  @override
  String get reviewHint =>
      'Readings the compliance checks held back. Release only what is acceptable; rule-layer blocks can only be rejected.';

  @override
  String get kindReport => 'Reading';

  @override
  String get kindRemedy => 'Remedy plan';

  @override
  String get kindLife => 'Life report';

  @override
  String get reviewHeld => 'Held for review';

  @override
  String get reviewBlocked => 'Blocked by rules';

  @override
  String get reviewReasons => 'Why it was held';

  @override
  String get reviewRuleHits => 'Rule hits';

  @override
  String get reviewGuard => 'AI reviewer\'s findings';

  @override
  String get reviewContent => 'Content';

  @override
  String get reviewNote => 'Review note (optional)';

  @override
  String get reviewApprove => 'Approve and release';

  @override
  String get reviewReject => 'Reject';

  @override
  String get reviewBlockedOnly =>
      'A rule-layer block is a hard violation: it can only be rejected.';

  @override
  String get reviewApproved => 'Released to the user';

  @override
  String get reviewRejected => 'Rejected';

  @override
  String get reviewNoContent => 'No content was kept for this item.';

  @override
  String get modeChart => 'Chart & reading';

  @override
  String get addTester => 'Add a new person';

  @override
  String editCurrent(String name) {
    return 'Edit $name\'s details';
  }

  @override
  String get leaveReadingTitle => 'Going back starts over';

  @override
  String get leaveReadingBody =>
      'This reading isn\'t finished: going back means starting it again.';

  @override
  String get leaveFormBody =>
      'What you entered for this reading won\'t be kept.';

  @override
  String get leaveChartBody =>
      'You\'ll need to compute the chart again to see it. Readings you generated stay in History.';

  @override
  String get leaveTarotBody =>
      'These cards won\'t be kept: you\'ll draw again next time. Readings you generated stay in History.';

  @override
  String get leaveReadingStay => 'Keep going';

  @override
  String get leaveReadingGo => 'Go back';

  @override
  String get leaveEditsTitle => 'Discard unsaved changes?';

  @override
  String get leaveEditsBody => 'Your changes won\'t be saved.';

  @override
  String get leaveEditsStay => 'Keep editing';

  @override
  String get leaveEditsGo => 'Discard';

  @override
  String get keysTitle => 'Keyboard shortcuts';

  @override
  String get keysTab => 'Move to the next / previous control';

  @override
  String get keySpace => 'Space';

  @override
  String get keysPress =>
      'Press the focused button; expand or collapse a section';

  @override
  String get keysEsc =>
      'Back one level: menus and dialogs close first; an unfinished reading asks first';

  @override
  String get keysArrows =>
      'Switch options (e.g. Gregorian / Lunar) and chart periods; scroll the luck and annual pillars';

  @override
  String get keysScroll => 'Scroll the page; move through a menu';

  @override
  String get keysSubmit =>
      'Submit the form: sign in, compute the chart, draw the cards, save';

  @override
  String get keysHelp => 'Show this list';

  @override
  String get keysBrowser =>
      'Switches browser tabs: the browser\'s own key, which the app leaves alone. Inside the app, switch options with ← →';

  @override
  String get close => 'Close';

  @override
  String cardHidden(String position) {
    return '$position, face down';
  }

  @override
  String get tarotQuestion => 'Your question (optional)';

  @override
  String get tarotQuestionHint =>
      'Think of one question before you draw; the reading will answer it.';

  @override
  String get tarotFocus => 'Focus on (optional)';

  @override
  String get focusAny => 'Anything';

  @override
  String get focusCareer => 'Work';

  @override
  String get focusLove => 'Love';

  @override
  String get focusHealth => 'Health';

  @override
  String get focusSelf => 'Myself';

  @override
  String get tarotSections =>
      'The reading has three parts: card by card, the whole spread, and advice.';

  @override
  String tarotQuestionShown(String question) {
    return 'Question: $question';
  }

  @override
  String tarotSlot(int n, String position) {
    return 'Card $n · $position';
  }

  @override
  String tarotNext(String slot) {
    return 'Turn the cards in order. Next: $slot';
  }

  @override
  String get tarotNextShort => 'next';

  @override
  String get tarotZoomHint =>
      'Tap a small card to see it large and turn it there.';

  @override
  String get tarotAllTurned =>
      'All cards are turned. Tap a card to see it large with its position\'s meaning.';

  @override
  String get tarotTapToTurn => 'Tap the card to turn it over';

  @override
  String get shenshaTitle => 'Stars, void and conception pillar';

  @override
  String get relationsTitle => 'Combinations and clashes in the chart';

  @override
  String get ziNextDay => 'Born 23:00–24:00: take the next day\'s day pillar';

  @override
  String get ziNextDayHint =>
      'Two schools; by default a birth after 23:00 keeps the same day';

  @override
  String get notDeLing => 'Not in season';

  @override
  String favorableIs(String elements) {
    return 'Favourable: $elements';
  }

  @override
  String unfavorableIs(String elements) {
    return 'Unfavourable: $elements';
  }

  @override
  String get specialNote => 'worth a closer look by a practitioner';
}
