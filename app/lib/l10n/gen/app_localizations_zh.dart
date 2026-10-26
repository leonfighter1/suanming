// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '命理大师';

  @override
  String get homeBazi => '八字排盘';

  @override
  String get homeBaziDesc => '依出生时间排出四柱、大运与流年';

  @override
  String get homeTarot => '塔罗';

  @override
  String get homeTarotDesc => '抽一组牌阵，作为自我反思的参考';

  @override
  String get settings => '设置';

  @override
  String get language => '语言';

  @override
  String get region => '地区';

  @override
  String get birthTime => '出生时间（当地民用时）';

  @override
  String get pickDate => '日期';

  @override
  String get pickTime => '时间';

  @override
  String get city => '出生地';

  @override
  String get gender => '性别（决定大运顺逆）';

  @override
  String get male => '男';

  @override
  String get female => '女';

  @override
  String get trueSolarTime => '真太阳时校正';

  @override
  String get compute => '排盘';

  @override
  String get fourPillars => '四柱';

  @override
  String get pillarYear => '年柱';

  @override
  String get pillarMonth => '月柱';

  @override
  String get pillarDay => '日柱';

  @override
  String get pillarHour => '时柱';

  @override
  String get rowTenGod => '十神';

  @override
  String get rowStem => '天干';

  @override
  String get rowBranch => '地支';

  @override
  String get rowHidden => '藏干';

  @override
  String get rowLifeStage => '十二长生';

  @override
  String get rowNayin => '纳音';

  @override
  String get dayMaster => '日主';

  @override
  String get wuxingWeighted => '五行（加权，简化计分）';

  @override
  String get dayun => '大运';

  @override
  String dayunFrom(String date) {
    return '$date 起运';
  }

  @override
  String get liunian => '流年';

  @override
  String age(int age) {
    return '$age 岁';
  }

  @override
  String get aiReport => 'AI 解读';

  @override
  String get chooseTopics => '分析方面';

  @override
  String get generate => '生成 AI 解读';

  @override
  String get generating => '正在生成解读…';

  @override
  String get generatingHint => '约需数分钟。可以先离开此页，完成后回来即可查看。';

  @override
  String get statusBlocked => '这份解读未通过内容审查，不会显示。请重新生成。';

  @override
  String get statusReview => '这份解读正在由团队审核，通过后才会显示。';

  @override
  String get statusFailed => '生成时出现问题，请重试。';

  @override
  String get layerFacts => '命盘事实 · 引擎计算，非 AI';

  @override
  String get layerInterpretation => '解读 · AI 生成';

  @override
  String get layerActions => '行动建议 · AI 生成';

  @override
  String get aiBadge => 'AI';

  @override
  String get topicWuxing => '五行';

  @override
  String get topicPersonality => '性格';

  @override
  String get topicCareerWealth => '事业财运';

  @override
  String get topicRelationships => '婚姻感情';

  @override
  String get topicDayunLiunian => '大运流年';

  @override
  String get topicHealth => '健康';

  @override
  String get srcTraditional => '典籍';

  @override
  String get srcConsensus => '通行共识';

  @override
  String get srcSimplified => '简化规则';

  @override
  String get srcDerived => '综合推导';

  @override
  String get horizonWeek => '本周';

  @override
  String get horizonMonth => '本月';

  @override
  String get horizonYear => '今年';

  @override
  String get horizonOngoing => '持续';

  @override
  String get spread => '牌阵';

  @override
  String get spreadSingle => '单张';

  @override
  String get spreadThree => '三张（过去・现在・未来）';

  @override
  String get spreadCeltic => '凯尔特十字（10 张）';

  @override
  String get draw => '抽牌';

  @override
  String get reversed => '逆位';

  @override
  String get tapToReveal => '点击卡牌翻开';

  @override
  String get retry => '重试';

  @override
  String get errorTitle => '无法完成请求';

  @override
  String get disclaimerShort => '文化参考与自我反思，并非预测。';

  @override
  String get signIn => '登录';

  @override
  String get createAccount => '注册账户';

  @override
  String get haveAccount => '已有账户？登录';

  @override
  String get noAccount => '新用户？注册账户';

  @override
  String get email => '电子邮件';

  @override
  String get password => '密码';

  @override
  String get passwordHint => '至少 10 个字符';

  @override
  String get regionAccount => '居住地区';

  @override
  String get regionAccountHint => '决定适用的规则与内容。此版本注册后无法更改。';

  @override
  String get ageConfirm => '我确认已年满 18 岁';

  @override
  String get appleSignIn => '通过 Apple 登录';

  @override
  String get googleSignIn => '通过 Google 登录';

  @override
  String get comingSoon => '即将推出';

  @override
  String get account => '账户';

  @override
  String get signOut => '退出登录';

  @override
  String get deleteAccount => '删除账户与数据';

  @override
  String get deleteAccountTitle => '要删除账户吗？';

  @override
  String get deleteAccountBody => '你的账户、命盘与解读会立即从服务器删除，无法恢复。';

  @override
  String get cancel => '取消';

  @override
  String get confirmDelete => '删除';

  @override
  String get accountDeleted => '你的账户与数据已删除。';

  @override
  String get signInMethods => '登录方式';

  @override
  String get captchaRequired => '尝试次数过多，请稍等几分钟再试。';

  @override
  String get profiles => '个人资料';

  @override
  String get profileFor => '为谁排盘';

  @override
  String get addProfile => '新增资料';

  @override
  String get editProfile => '编辑资料';

  @override
  String get name => '姓名';

  @override
  String get setDefault => '设为默认';

  @override
  String get isDefault => '默认';

  @override
  String get deleteProfile => '删除资料';

  @override
  String get profileHint => '以下修改只用于本次排盘；要永久修改请编辑资料。';

  @override
  String get noProfileTitle => '填写你的出生资料';

  @override
  String get noProfileBody => '保存一次，之后每次排盘都会自动带入。也可以为他人新增资料。';

  @override
  String get createProfile => '建立资料';

  @override
  String get save => '保存';

  @override
  String get saved => '已保存';

  @override
  String get lunarCompare => '农历对照';

  @override
  String get gregorian => '公历';

  @override
  String get lunarLabel => '农历';

  @override
  String get zodiac => '生肖';

  @override
  String get lunarYearNote => '农历年以春节为界，八字年柱以立春为界。';

  @override
  String get history => '历史记录';

  @override
  String get historyEmpty => '还没有解读记录，生成后会显示在这里。';

  @override
  String get recent => '最近记录';

  @override
  String get viewAll => '查看全部';

  @override
  String get analyzing => 'AI 正在深度分析中';

  @override
  String get stageNarrative => '深度解读命盘';

  @override
  String get stageAction => '整理行动建议';

  @override
  String get stageGuard => '内容合规审查';

  @override
  String get stageWaiting => '排队中';

  @override
  String elapsed(String time) {
    return '已用时 $time';
  }

  @override
  String retrying(int n) {
    return '上一稿未通过检查，正在重写（第 $n 次）';
  }

  @override
  String get download => '下载';

  @override
  String get copyAll => '复制全文';

  @override
  String get copied => '已复制';

  @override
  String get more => '更多';

  @override
  String chartOf(String name) {
    return '$name 的命盘';
  }

  @override
  String greeting(String name) {
    return '你好，$name';
  }

  @override
  String get reportTitle => '命理大师 AI 解读';

  @override
  String get openChart => '查看命盘';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => '命理大師';

  @override
  String get homeBazi => '八字排盤';

  @override
  String get homeBaziDesc => '依出生時間排出四柱、大運與流年';

  @override
  String get homeTarot => '塔羅';

  @override
  String get homeTarotDesc => '抽一組牌陣，作為自我反思的參考';

  @override
  String get settings => '設定';

  @override
  String get language => '語言';

  @override
  String get region => '地區';

  @override
  String get birthTime => '出生時間（當地民用時）';

  @override
  String get pickDate => '日期';

  @override
  String get pickTime => '時間';

  @override
  String get city => '出生地';

  @override
  String get gender => '性別（決定大運順逆）';

  @override
  String get male => '男';

  @override
  String get female => '女';

  @override
  String get trueSolarTime => '真太陽時校正';

  @override
  String get compute => '排盤';

  @override
  String get fourPillars => '四柱';

  @override
  String get pillarYear => '年柱';

  @override
  String get pillarMonth => '月柱';

  @override
  String get pillarDay => '日柱';

  @override
  String get pillarHour => '時柱';

  @override
  String get rowTenGod => '十神';

  @override
  String get rowStem => '天干';

  @override
  String get rowBranch => '地支';

  @override
  String get rowHidden => '藏干';

  @override
  String get rowLifeStage => '十二長生';

  @override
  String get rowNayin => '納音';

  @override
  String get dayMaster => '日主';

  @override
  String get wuxingWeighted => '五行（加權，簡化計分）';

  @override
  String get dayun => '大運';

  @override
  String dayunFrom(String date) {
    return '$date 起運';
  }

  @override
  String get liunian => '流年';

  @override
  String age(int age) {
    return '$age 歲';
  }

  @override
  String get aiReport => 'AI 解讀';

  @override
  String get chooseTopics => '分析方面';

  @override
  String get generate => '生成 AI 解讀';

  @override
  String get generating => '正在生成解讀…';

  @override
  String get generatingHint => '約需數分鐘。可以先離開此頁，完成後回來即可查看。';

  @override
  String get statusBlocked => '這份解讀未通過內容審查，不會顯示。請重新生成。';

  @override
  String get statusReview => '這份解讀正在由團隊審核，通過後才會顯示。';

  @override
  String get statusFailed => '生成時出現問題，請重試。';

  @override
  String get layerFacts => '命盤事實 · 引擎計算，非 AI';

  @override
  String get layerInterpretation => '解讀 · AI 生成';

  @override
  String get layerActions => '行動建議 · AI 生成';

  @override
  String get aiBadge => 'AI';

  @override
  String get topicWuxing => '五行';

  @override
  String get topicPersonality => '性格';

  @override
  String get topicCareerWealth => '事業財運';

  @override
  String get topicRelationships => '婚姻感情';

  @override
  String get topicDayunLiunian => '大運流年';

  @override
  String get topicHealth => '健康';

  @override
  String get srcTraditional => '典籍';

  @override
  String get srcConsensus => '通行共識';

  @override
  String get srcSimplified => '簡化規則';

  @override
  String get srcDerived => '綜合推導';

  @override
  String get horizonWeek => '本週';

  @override
  String get horizonMonth => '本月';

  @override
  String get horizonYear => '今年';

  @override
  String get horizonOngoing => '持續';

  @override
  String get spread => '牌陣';

  @override
  String get spreadSingle => '單張';

  @override
  String get spreadThree => '三張（過去・現在・未來）';

  @override
  String get spreadCeltic => '凱爾特十字（10 張）';

  @override
  String get draw => '抽牌';

  @override
  String get reversed => '逆位';

  @override
  String get tapToReveal => '點擊卡牌翻開';

  @override
  String get retry => '重試';

  @override
  String get errorTitle => '無法完成請求';

  @override
  String get disclaimerShort => '文化參考與自我反思，並非預測。';

  @override
  String get signIn => '登入';

  @override
  String get createAccount => '註冊帳戶';

  @override
  String get haveAccount => '已有帳戶？登入';

  @override
  String get noAccount => '新用戶？註冊帳戶';

  @override
  String get email => '電子郵件';

  @override
  String get password => '密碼';

  @override
  String get passwordHint => '至少 10 個字元';

  @override
  String get regionAccount => '居住地區';

  @override
  String get regionAccountHint => '決定適用的規則與內容。此版本註冊後無法更改。';

  @override
  String get ageConfirm => '我確認已年滿 18 歲';

  @override
  String get appleSignIn => '使用 Apple 登入';

  @override
  String get googleSignIn => '使用 Google 登入';

  @override
  String get comingSoon => '即將推出';

  @override
  String get account => '帳戶';

  @override
  String get signOut => '登出';

  @override
  String get deleteAccount => '刪除帳戶與資料';

  @override
  String get deleteAccountTitle => '要刪除帳戶嗎？';

  @override
  String get deleteAccountBody => '你的帳戶、命盤與解讀會立即從伺服器刪除，無法復原。';

  @override
  String get cancel => '取消';

  @override
  String get confirmDelete => '刪除';

  @override
  String get accountDeleted => '你的帳戶與資料已刪除。';

  @override
  String get signInMethods => '登入方式';

  @override
  String get captchaRequired => '嘗試次數過多，請稍候幾分鐘再試。';

  @override
  String get profiles => '個人資料';

  @override
  String get profileFor => '為誰排盤';

  @override
  String get addProfile => '新增資料';

  @override
  String get editProfile => '編輯資料';

  @override
  String get name => '姓名';

  @override
  String get setDefault => '設為預設';

  @override
  String get isDefault => '預設';

  @override
  String get deleteProfile => '刪除資料';

  @override
  String get profileHint => '以下修改只用於本次排盤；要永久修改請編輯資料。';

  @override
  String get noProfileTitle => '填寫你的出生資料';

  @override
  String get noProfileBody => '儲存一次，之後每次排盤都會自動帶入。也可以為他人新增資料。';

  @override
  String get createProfile => '建立資料';

  @override
  String get save => '儲存';

  @override
  String get saved => '已儲存';

  @override
  String get lunarCompare => '農曆對照';

  @override
  String get gregorian => '公曆';

  @override
  String get lunarLabel => '農曆';

  @override
  String get zodiac => '生肖';

  @override
  String get lunarYearNote => '農曆年以春節為界，八字年柱以立春為界。';

  @override
  String get history => '歷史紀錄';

  @override
  String get historyEmpty => '還沒有解讀紀錄，生成後會顯示在這裡。';

  @override
  String get recent => '最近紀錄';

  @override
  String get viewAll => '查看全部';

  @override
  String get analyzing => 'AI 正在深度分析中';

  @override
  String get stageNarrative => '深度解讀命盤';

  @override
  String get stageAction => '整理行動建議';

  @override
  String get stageGuard => '內容合規審查';

  @override
  String get stageWaiting => '排隊中';

  @override
  String elapsed(String time) {
    return '已用時 $time';
  }

  @override
  String retrying(int n) {
    return '上一稿未通過檢查，正在重寫（第 $n 次）';
  }

  @override
  String get download => '下載';

  @override
  String get copyAll => '複製全文';

  @override
  String get copied => '已複製';

  @override
  String get more => '更多';

  @override
  String chartOf(String name) {
    return '$name 的命盤';
  }

  @override
  String greeting(String name) {
    return '你好，$name';
  }

  @override
  String get reportTitle => '命理大師 AI 解讀';

  @override
  String get openChart => '查看命盤';
}
