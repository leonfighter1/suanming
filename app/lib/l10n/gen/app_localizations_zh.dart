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
  String get homeBaziDesc => '根据出生时间排出四柱、大运和流年，也可以生成一生运势报告';

  @override
  String get homeTarot => '塔罗';

  @override
  String get homeTarotDesc => '抽一组牌阵，仅供娱乐和玄学学习使用';

  @override
  String get settings => '设置';

  @override
  String get language => '语言';

  @override
  String get appearance => '外观';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeTime => '跟随时间';

  @override
  String get themeTimeHint => '晚上 7 点到早上 6 点为深色，其余为浅色';

  @override
  String get region => '地区';

  @override
  String get birthTime => '出生时间（当地时间）';

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
  String get chartGroupChart => '命盘';

  @override
  String get chartGroupMakeup => '命局';

  @override
  String get chartGroupLuck => '运势';

  @override
  String get chartGroupReading => '解读与报告';

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
    return '虚岁 $age';
  }

  @override
  String get aiReport => 'AI 解读';

  @override
  String get chooseTopics => '分析方面';

  @override
  String get generate => '生成 AI 解读';

  @override
  String get generateBazi => '用AI做更精确解读';

  @override
  String get generating => '正在生成解读…';

  @override
  String get generatingHint => '大约需要几分钟。可以先离开这个页面，完成后回来查看。';

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
  String get layerConclusion => '总结 · AI 生成';

  @override
  String get conclusionPortrait => '你是怎样的人';

  @override
  String get conclusionPast => '过去';

  @override
  String get conclusionPresent => '现在';

  @override
  String get conclusionChallenges => '可能遇到的问题';

  @override
  String get conclusionGains => '得势与得失';

  @override
  String get conclusionFuture => '未来运势';

  @override
  String get conclusionCaution => '何时开始要注意';

  @override
  String get conclusionMomentum => '何时开始要发力';

  @override
  String get conclusionCoping => '遇到问题时怎么办';

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
  String get topicTarotCards => '逐张解读';

  @override
  String get topicTarotSynthesis => '综合解读';

  @override
  String get topicTarotAdvice => '建议';

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
  String get pillarMore => '更多：藏干、长生、纳音';

  @override
  String get pillarLess => '收起';

  @override
  String get ritualTitle => '洗牌 · 切牌 · 选牌';

  @override
  String get ritualShuffleHint => '心里想着你的问题，按“洗牌”把牌洗匀。';

  @override
  String get ritualShuffle => '洗牌';

  @override
  String get ritualCutHint => '切牌：选一叠，放到最上面。';

  @override
  String ritualPile(int n) {
    return '第 $n 叠';
  }

  @override
  String ritualPickHint(int count, int picked) {
    return '选牌：凭直觉选 $count 张（已选 $picked 张）';
  }

  @override
  String ritualCard(int n) {
    return '第 $n 张牌，背面朝上';
  }

  @override
  String get ritualSkip => '让牌组替我选';

  @override
  String get ritualNote => '牌由系统公平洗好，你在背面朝上时选择；每次抽牌事后都可以核对。';

  @override
  String get tarotGlossary => '牌义图鉴';

  @override
  String get glossaryMajor => '大阿尔卡那';

  @override
  String get glossaryWands => '权杖';

  @override
  String get glossaryCups => '圣杯';

  @override
  String get glossarySwords => '宝剑';

  @override
  String get glossaryPentacles => '星币';

  @override
  String get glossaryKeywords => '牌面关键词';

  @override
  String get dailyCard => '今日一牌';

  @override
  String get dailyCardHint => '每天一张，当天不变。点开看大图，也可以请 AI 解读。';

  @override
  String get dailyLot => '今日一签';

  @override
  String get dailyLotHint => '每天一签，当天不变。点开看签诗，也可以请 AI 解读。';

  @override
  String get dailyHexagram => '今日一卦';

  @override
  String get dailyHexagramHint => '每天一卦，当天不变。点开看卦辞，也可以请 AI 解读。';

  @override
  String get spreadSingleShort => '单张';

  @override
  String get spreadThreeShort => '三张';

  @override
  String get spreadCelticShort => '凯尔特十字';

  @override
  String get spreadTwoPathsShort => '二选一';

  @override
  String get spreadRelationshipShort => '关系牌阵';

  @override
  String get tarotExample1 => '这份工作还适合我吗？';

  @override
  String get tarotExample2 => '我们的关系会往哪里走？';

  @override
  String get tarotExample3 => '接下来三个月我该注意什么？';

  @override
  String get tarotExample4 => '这个决定我该怎么做？';

  @override
  String get draw => '抽牌';

  @override
  String get reversed => '逆位';

  @override
  String get retry => '重试';

  @override
  String get errorTitle => '请求失败';

  @override
  String get disclaimerShort => '仅供娱乐和玄学学习使用，不是预测。';

  @override
  String get signIn => '登录';

  @override
  String get createAccount => '注册账号';

  @override
  String get haveAccount => '已有账号？去登录';

  @override
  String get noAccount => '新用户？立即注册';

  @override
  String get email => '邮箱';

  @override
  String get password => '密码';

  @override
  String get passwordHint => '至少 10 个字符';

  @override
  String get regionAccount => '居住地区';

  @override
  String get regionAccountHint => '决定适用的规则和内容。当前版本注册后不能修改。';

  @override
  String get ageConfirm => '我确认已年满 18 岁';

  @override
  String get appleSignIn => '通过 Apple 登录';

  @override
  String get googleSignIn => '通过 Google 登录';

  @override
  String get comingSoon => '即将推出';

  @override
  String get account => '账号';

  @override
  String get signOut => '退出登录';

  @override
  String get deleteAccount => '注销账号并删除数据';

  @override
  String get deleteAccountTitle => '确定注销账号吗？';

  @override
  String get deleteAccountBody => '你的账号、命盘和解读会立即从服务器删除，无法恢复。';

  @override
  String get deleteAccountStaff => '这是管理后台的账号，不能在这里注销：请管理员在管理后台的账号页面注销。';

  @override
  String get maintenanceTitle => '系统维护中';

  @override
  String maintenanceWindow(String from, String to) {
    return '预计 $from 到 $to 之间可以再登录。';
  }

  @override
  String maintenanceUntil(String time) {
    return '预计 $time 可以再登录。';
  }

  @override
  String get maintenanceSoon => '很快就可以再登录，请稍后再试。';

  @override
  String get maintenanceStaff => '你是后台人员，可以照常使用；用户现在看到的是这条通知。';

  @override
  String get maintenanceCheck => '再看看';

  @override
  String get cancel => '取消';

  @override
  String get confirmDelete => '删除';

  @override
  String get accountDeleted => '账号和数据已删除。';

  @override
  String get signInMethods => '登录方式';

  @override
  String get captchaRequired => '尝试次数过多，请稍等几分钟再试。';

  @override
  String get profiles => '个人资料';

  @override
  String get profileFor => '为谁排盘';

  @override
  String get addProfile => '添加资料';

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
  String get noProfileTitle => '填写你的出生信息';

  @override
  String get noProfileBody => '保存一次，以后排盘会自动带入。也可以给家人朋友添加资料。';

  @override
  String get createProfile => '创建资料';

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
  String get loading => '正在加载';

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

  @override
  String get timeExact => '精确时间';

  @override
  String get timeShichen => '时辰';

  @override
  String get lunarYear => '农历年';

  @override
  String get lunarMonth => '月';

  @override
  String get lunarDay => '日';

  @override
  String get shichenNote => '只知道时辰：时柱只精确到两小时，相关解读会标明为参考。';

  @override
  String get trendTitle => '运势走势';

  @override
  String get trendDayun => '按年龄（大运）';

  @override
  String get trendLiunian => '按年份（流年）';

  @override
  String get trendCombined => '综合';

  @override
  String get trendTotal => '总分';

  @override
  String get trendCompare => '叠加对比';

  @override
  String get trendTapHint => '点击图上的时期，查看各项分数和依据。';

  @override
  String trendAge(String ages) {
    return '虚岁 $ages';
  }

  @override
  String get expandAll => '展开全部';

  @override
  String get collapseAll => '收起全部';

  @override
  String get remedyTitle => '破除运势';

  @override
  String get remedyDesc => '针对单个项目的改运方案：写明针对哪一项、哪些时期，并给出具体做法。每个项目单独解锁。';

  @override
  String remedyFor(String topic) {
    return '破除运势：$topic';
  }

  @override
  String remedyUnlock(String price) {
    return '解锁 · $price';
  }

  @override
  String get remedyView => '查看方案';

  @override
  String remedyConfirmTitle(String topic) {
    return '解锁“$topic”破除运势方案';
  }

  @override
  String remedyConfirmBody(String topic, String price) {
    return '这个方案针对“$topic”单独收费：$price。\n支付功能尚未接入（TODO）：现在点确认会直接扣款（演示，不会真实收费）。';
  }

  @override
  String remedyPay(String price) {
    return '确认支付 $price';
  }

  @override
  String remedyGenerating(String topic) {
    return 'AI 正在为“$topic”制定方案…';
  }

  @override
  String get remedyTarget => '针对项目';

  @override
  String get remedyFocus => '重点时期';

  @override
  String get remedySteps => '具体做法';

  @override
  String get remedyBasis => '命理依据';

  @override
  String get remedySave => '保存';

  @override
  String get remedySend => '发送';

  @override
  String get remedyPrint => '打印';

  @override
  String get remedyHeld => '方案正在审核中，暂时无法显示。';

  @override
  String get remedyFailed => '生成失败，请重试（不会重复收费）。';

  @override
  String get remedyDemoPaid => '演示支付（未真实扣款）';

  @override
  String get placePick => '选择出生地';

  @override
  String get placeCountry => '国家和地区';

  @override
  String get placeRegion => '省／州';

  @override
  String get placeCity => '城市';

  @override
  String get placeSearch => '搜索';

  @override
  String get placeCommon => '常用';

  @override
  String get placeAll => '全部';

  @override
  String get placeNone => '没有符合的结果';

  @override
  String placeDetail(String tz, String lon) {
    return '时区 $tz · 经度 $lon';
  }

  @override
  String get placeSource => '地点数据：GeoNames（CC BY 4.0）';

  @override
  String serverUnreachable(String url) {
    return '无法连接服务器 $url。\n手机上的 127.0.0.1 指的是手机本身：请在电脑上运行 npm run api:lan，再用手机打开 http://电脑的局域网地址:5000。如果页面是 https，请在网址后面加上 ?api=https 服务器地址。';
  }

  @override
  String get lifeTitle => '个人情况（选填）';

  @override
  String get lifeHint =>
      '同时同地出生的人命盘相同，填上你的实际情况，解读才会贴近你本人。信息只保存在本机，只在生成解读时和命盘一起发给 AI。';

  @override
  String get lifeUseName => '解读时用名字称呼我';

  @override
  String get lifeResidence => '现居地';

  @override
  String get lifeNotSet => '未填写';

  @override
  String get lifeMarital => '婚姻状况';

  @override
  String get maritalSingle => '单身';

  @override
  String get maritalDating => '恋爱中';

  @override
  String get maritalMarried => '已婚';

  @override
  String get maritalSeparated => '分居';

  @override
  String get maritalDivorced => '离婚';

  @override
  String get maritalWidowed => '丧偶';

  @override
  String get lifeChildren => '子女';

  @override
  String get childrenNone => '没有';

  @override
  String get childrenHas => '有';

  @override
  String get lifeOccupation => '职业／行业';

  @override
  String get lifeFamily => '家庭情况';

  @override
  String get lifeFamilyHint => '例如：和父母同住、需要照顾老人';

  @override
  String get lifeConcern => '想问的事';

  @override
  String get lifeConcernHint => '例如：明年适合跳槽吗？';

  @override
  String get sectionSummary => '一句话重点';

  @override
  String get remedyReady => '已备好';

  @override
  String get lifeEntry => '一生运势报告';

  @override
  String get lifeEntryDesc => '易经本命卦、梅花易数、五行八卦，三法合看一生走势';

  @override
  String get lifeGenerate => '生成一生运势报告';

  @override
  String get lifeSubtitle => '易经本命卦　|　梅花易数　|　五行八卦';

  @override
  String lifeReportOf(String name) {
    return '$name 一生运势报告';
  }

  @override
  String get lifeItem => '项目';

  @override
  String get lifeContent => '内容';

  @override
  String get lifeName => '姓名';

  @override
  String get lifeBirthLunar => '出生（农历）';

  @override
  String get lifeBirthSolar => '出生（公历）';

  @override
  String get lifeBirthPlace => '出生地';

  @override
  String get lifeTrueSolar => '真太阳时';

  @override
  String get lifeGanzhi => '生辰干支';

  @override
  String get lifeNote => '说明：本报告依传统术数推演，仅供娱乐和玄学学习使用，不是科学预测。三种方法各自独立推演，最后再合看。';

  @override
  String get lifeSec1 => '一、易经本命卦';

  @override
  String get lifeQigua => '起卦';

  @override
  String get lifeBenGua => '本命卦';

  @override
  String get lifeHuGua => '互卦';

  @override
  String get lifeZhiGuaShort => '之卦';

  @override
  String get lifeGuaYi => '卦义：一生的底色';

  @override
  String get lifeMingYao => '命爻';

  @override
  String get lifeZhiGua => '之卦：人生归宿';

  @override
  String get lifeSixLines => '六爻配人生阶段';

  @override
  String get lifeLine => '爻';

  @override
  String get lifeAge => '年龄';

  @override
  String get lifeYaoCi => '爻辞';

  @override
  String get lifeForLife => '对应人生';

  @override
  String get lifeSec2 => '二、梅花易数';

  @override
  String get lifeMhGua => '卦';

  @override
  String get lifeMhRel => '与体卦的关系';

  @override
  String get lifeMhStage => '主管';

  @override
  String get lifeTi => '体卦';

  @override
  String get lifeYong => '用卦';

  @override
  String get lifeHu => '互卦';

  @override
  String get lifeBian => '变卦';

  @override
  String get lifeSelf => '代表本人';

  @override
  String get lifeEarly => '早年';

  @override
  String get lifeMiddle => '中年';

  @override
  String get lifeLate => '晚年';

  @override
  String get lifeSeason => '时令';

  @override
  String get lifeMhConclusion => '梅花结论';

  @override
  String get relBihe => '比和（同气相助）';

  @override
  String get relShengti => '生体（得助）';

  @override
  String get relTisheng => '体生（耗泄）';

  @override
  String get relTike => '体克（我克为财，辛苦得）';

  @override
  String get relKeti => '克体（受压）';

  @override
  String get lifeSec3 => '三、五行八卦';

  @override
  String get lifeWuxingDist => '五行分布（加权，简化计分）';

  @override
  String get lifeFavorable => '喜';

  @override
  String get lifeUnfavorable => '忌';

  @override
  String get lifeBazhai => '八卦命卦（八宅）';

  @override
  String lifeKua(String kua, String name, String group, String wuxing) {
    return '命卦 $kua · $name卦（$group，五行属$wuxing）';
  }

  @override
  String get lifeDaily => '日常宜用';

  @override
  String get lifeSec4 => '四、分项运势';

  @override
  String get lifeTopicPersonality => '性格';

  @override
  String get lifeTopicCareer => '事业';

  @override
  String get lifeTopicWealth => '财运';

  @override
  String get lifeTopicRelationships => '情感与婚姻';

  @override
  String get lifeTopicChildren => '家庭与子女';

  @override
  String get lifeTopicParents => '父母';

  @override
  String get lifeTopicHealth => '健康';

  @override
  String get lifeSec5 => '五、人生阶段总览';

  @override
  String get lifeYears => '年份';

  @override
  String get lifeFortune => '运势';

  @override
  String get lifeFocus => '重点';

  @override
  String get lifeSec6 => '六、总评与建议';

  @override
  String get lifeDownload => '下载报告包';

  @override
  String get lifePrint => '打印 / 保存 PDF';

  @override
  String get lifeGenerating => 'AI 正在撰写一生运势报告…';

  @override
  String get lifeStageMethods => '推演易经、梅花与八宅';

  @override
  String get lifeStageTopics => '撰写分项运势与人生阶段';

  @override
  String get lifeTook => '大约需要 3–5 分钟。可以先离开这个页面，完成后回来查看。';

  @override
  String get lifeDirection => '方位';

  @override
  String get lifeStar => '星名';

  @override
  String get lifeLuck => '吉凶';

  @override
  String get lifeMhName => '卦名';

  @override
  String get lifeWuxing => '五行';

  @override
  String get reviewTitle => '内容审核';

  @override
  String get reviewEmpty => '目前没有待审核的内容。';

  @override
  String get reviewHint => '这里是被合规检查拦下的内容。确认没有问题才通过；规则层拦截的只能查看或驳回。';

  @override
  String get kindReport => 'AI 解读';

  @override
  String get kindRemedy => '破除运势方案';

  @override
  String get kindLife => '一生运势报告';

  @override
  String get reviewHeld => '待审核';

  @override
  String get reviewBlocked => '规则层拦截';

  @override
  String get reviewReasons => '拦截原因';

  @override
  String get reviewRuleHits => '规则命中';

  @override
  String get reviewGuard => 'AI 审核意见';

  @override
  String get reviewContent => '内容';

  @override
  String get reviewNote => '审核备注（可选）';

  @override
  String get reviewApprove => '通过并发布';

  @override
  String get reviewReject => '驳回';

  @override
  String get reviewBlockedOnly => '规则层拦截属于硬性违规，只能驳回，不能发布。';

  @override
  String get reviewApproved => '已通过并发布给用户';

  @override
  String get reviewRejected => '已驳回';

  @override
  String get reviewNoContent => '这条没有保留内容。';

  @override
  String get modeChart => '排盘解读';

  @override
  String get addTester => '添加新的测试者';

  @override
  String editCurrent(String name) {
    return '编辑“$name”的资料';
  }

  @override
  String get leaveReadingTitle => '返回将重新开始';

  @override
  String get leaveReadingBody => '这次测算还没有完成，返回后需要重新开始。';

  @override
  String get leaveFormBody => '本次填写的内容不会保留，返回后需要重新填写。';

  @override
  String get leaveChartBody => '返回后要重新排盘才能再看到这个命盘。已生成的解读会保存在历史记录里。';

  @override
  String get leaveTarotBody => '这次抽到的牌不会保留，下次要重新抽牌。已生成的解读会保存在历史记录里。';

  @override
  String get leaveReadingStay => '继续测算';

  @override
  String get leaveReadingGo => '返回';

  @override
  String get leaveEditsTitle => '放弃未保存的修改？';

  @override
  String get leaveEditsBody => '返回后，这次的修改不会保存。';

  @override
  String get leaveEditsStay => '继续编辑';

  @override
  String get leaveEditsGo => '放弃修改';

  @override
  String get keysTitle => '键盘快捷键';

  @override
  String get keysTab => '移到下一个 / 上一个控件';

  @override
  String get keySpace => '空格';

  @override
  String get keysPress => '按下按钮；展开或收起段落';

  @override
  String get keysEsc => '返回上一层：先关闭菜单和对话框；测算未完成时会先提醒';

  @override
  String get keysArrows => '切换选项（如 公历 / 农历）和图表时期；滚动 大运 / 流年';

  @override
  String get keysScroll => '滚动页面；在菜单里上下选择';

  @override
  String get keysSubmit => '提交表单：登录、排盘、抽牌、保存';

  @override
  String get keysHelp => '打开这个列表';

  @override
  String get keysBrowser => '切换浏览器标签页：这是浏览器自己的快捷键，本应用不占用。应用内切换选项请用 ← →';

  @override
  String get close => '关闭';

  @override
  String cardHidden(String position) {
    return '$position，未翻开';
  }

  @override
  String get tarotQuestion => '你想问的问题';

  @override
  String get tarotQuestionHint => '先写下你想问的问题才能抽牌：有所问，牌才有所答，解读也围绕它展开。';

  @override
  String get tarotQuestionMissing => '先写下你想问的问题，才能抽牌';

  @override
  String get tarotFocus => '想看哪方面（可选）';

  @override
  String get focusAny => '不限';

  @override
  String get focusCareer => '事业';

  @override
  String get focusLove => '感情';

  @override
  String get focusHealth => '健康';

  @override
  String get focusSelf => '自我';

  @override
  String get tarotSections => '解读分三部分：逐张解读、综合解读、建议。';

  @override
  String tarotQuestionShown(String question) {
    return '问题：$question';
  }

  @override
  String tarotSlot(int n, String position) {
    return '第 $n 张 · $position';
  }

  @override
  String tarotNext(String slot) {
    return '按牌阵顺序翻牌，下一张：$slot';
  }

  @override
  String get tarotNextShort => '下一张';

  @override
  String get tarotZoomHint => '点击小牌放大，在大图里翻开。';

  @override
  String get tarotAllTurned => '牌已全部翻开。点击任意一张，看大图和位置含义。';

  @override
  String get tarotTapToTurn => '点击牌面翻开';

  @override
  String get shenshaTitle => '神煞 · 空亡 · 胎元';

  @override
  String get relationsTitle => '原局刑冲合害';

  @override
  String get ziNextDay => '23:00–24:00 出生，日柱算次日';

  @override
  String get ziNextDayHint => '子时有两种算法；默认 23:00 后出生仍算当天';

  @override
  String get notDeLing => '不得令';

  @override
  String favorableIs(String elements) {
    return '喜用：$elements';
  }

  @override
  String unfavorableIs(String elements) {
    return '忌：$elements';
  }

  @override
  String get specialNote => '宜请有经验的师傅细看';

  @override
  String get termTipHint => '点击带虚线的术语，查看它的意思。';

  @override
  String termTipAbout(String term) {
    return '什么是$term？';
  }

  @override
  String get shenshaName => '神煞';

  @override
  String get timelineNow => '当前';

  @override
  String get timelineThisYear => '今年';

  @override
  String get dayunTapHint => '点击一步大运，查看它的十年。';

  @override
  String dayunYears(String ganzhi, int from, int to) {
    return '$ganzhi大运 · $from–$to年';
  }

  @override
  String liuyueOf(int year) {
    return '$year年流月';
  }

  @override
  String pillarRelation(String pillar, String relation) {
    return '$pillar$relation';
  }

  @override
  String get jumpTo => '跳到';

  @override
  String get jumpActions => '行动建议';

  @override
  String get jumpConclusion => '总结';

  @override
  String get shareImage => '分享图片';

  @override
  String get shareImageFailed => '暂时无法生成分享图，请稍后再试。';

  @override
  String get homeQiuqian => '求签';

  @override
  String get homeQiuqianDesc => '摇签、掷筊，求一首签诗，仅供娱乐和玄学学习使用';

  @override
  String get qiuqianQuestion => '所求之事';

  @override
  String get qiuqianQuestionHint => '先写下所求之事才能求签：有所求，才能去求。问题只用于解签，不会出现在分享图上。';

  @override
  String get qiuqianQuestionMissing => '先写下所求之事，才能求签';

  @override
  String get qiuqianExample1 => '今年的工作会顺利吗？';

  @override
  String get qiuqianExample2 => '这段关系该怎么经营？';

  @override
  String get qiuqianExample3 => '搬家的事该怎么决定？';

  @override
  String get qiuqianHowTo => '摇签筒，一支签落下；再掷筊请示：圣筊（一平一凸）就是这一支，笑筊或阴筊就把签放回再摇。';

  @override
  String get qiuqianDraw => '求签';

  @override
  String get qiuqianThrow => '掷筊';

  @override
  String get qiuqianAgain => '放回再摇';

  @override
  String get qiuqianSkip => '直接看结果';

  @override
  String get qiuqianCylinder => '签';

  @override
  String get qiuqianShaking => '摇签中……';

  @override
  String get qiuqianTossing => '掷筊中……';

  @override
  String qiuqianStickFell(String title) {
    return '摇出$title';
  }

  @override
  String get qiuqianSheng => '圣筊：神明应允，就是这一支';

  @override
  String get qiuqianXiao => '笑筊：神明一笑，把签放回再求';

  @override
  String get qiuqianYin => '阴筊：神明未允，把签放回再求';

  @override
  String get qiuqianYourLot => '你求得的签';

  @override
  String get qiuqianTextNote => '签诗依台湾庙宇通行文本，并以清代刻本校订。';

  @override
  String get qiuqianSections => '解签分三部分：签诗、所问之事、建议。';

  @override
  String get leaveQiuqianBody => '这次求得的签不会保留，下次要重新求签。已生成的解读会保存在历史记录里。';

  @override
  String get topicQiuqianPoem => '签诗';

  @override
  String get topicQiuqianAnswer => '所问之事';

  @override
  String get topicQiuqianAdvice => '建议';

  @override
  String get blockFlat => '平面朝上';

  @override
  String get blockRound => '凸面朝上';

  @override
  String get homeFengshui => '风水';

  @override
  String get homeFengshuiDesc => '房间布局的通用原则：采光、通风与动线，不论吉凶';

  @override
  String get fengshuiRoom => '哪个房间';

  @override
  String get fengshuiFacing => '主要窗户朝向（可不选）';

  @override
  String get fengshuiFacingUnknown => '不确定';

  @override
  String get fengshuiDescription => '房间现状（可不填）';

  @override
  String get fengshuiDescriptionHint => '例如“床在窗下，门在左边”。只用于解读，不会保存地址或平面图。';

  @override
  String get fengshuiLook => '看布局';

  @override
  String get fengshuiPrinciples => '这个房间可以留意';

  @override
  String get fengshuiNote => '这些是通用的空间原则，不是对住宅吉凶的判断。';

  @override
  String get fengshuiSections => '解读分三部分：布局、光线与动线、建议。';

  @override
  String fengshuiDirection(String direction, String trigram, String element) {
    return '传统上：$direction · $trigram · $element';
  }

  @override
  String get topicFengshuiLayout => '布局';

  @override
  String get topicFengshuiFlow => '光线与动线';

  @override
  String get topicFengshuiAdvice => '建议';

  @override
  String get homeNaming => '起名';

  @override
  String get namingFromChart => '为这个命盘起名';

  @override
  String get namingSurname => '姓氏';

  @override
  String get namingSurnameHint => '一或两个汉字，例如“陈”或“欧阳”';

  @override
  String get namingLength => '名字';

  @override
  String get namingOne => '单字名';

  @override
  String get namingTwo => '双字名';

  @override
  String get namingSuggest => '起名';

  @override
  String namingElements(String elements) {
    return '名字所补：$elements';
  }

  @override
  String get namingBalance => '这个命盘没有明显的喜用，名字以五行平衡为主。';

  @override
  String get namingCandidates => '候选名字';

  @override
  String get namingDraft => '这些名字所用的字义库仍待专家校订。';

  @override
  String get namingNote => '名字是祝福与声音，不决定任何人的命运。';

  @override
  String get namingSections => '解读分两部分：候选名字、怎么挑选。';

  @override
  String get topicNamingCandidates => '候选名字';

  @override
  String get topicNamingAdvice => '建议';

  @override
  String get homeLiuyao => '算卦';

  @override
  String get homeLiuyaoDesc => '掷三枚硬币六次起卦，或自己掷好再填，马上看卦辞直说，仅供娱乐和玄学学习使用';

  @override
  String get homeEast => '东方';

  @override
  String get homeWest => '西方';

  @override
  String get liuyaoQuestion => '想问的事';

  @override
  String get liuyaoQuestionHint => '先写下想问的事才能起卦。一次只问一件事，问得越具体，解读越贴切';

  @override
  String get liuyaoQuestionMissing => '先写下想问的事，才能起卦';

  @override
  String get liuyaoRemind => '起卦之前';

  @override
  String get liuyaoGroupAsk => '问卦';

  @override
  String get liuyaoGroupCast => '起卦';

  @override
  String get liuyaoGroupResult => '得卦';

  @override
  String get liuyaoGroupReading => '解读';

  @override
  String get liuyaoRemindBody => '先静下心，把要问的事想清楚。一次只问一件事，同一件事不要一再重问。';

  @override
  String get liuyaoMode => '起卦方式';

  @override
  String get liuyaoModeAuto => '自动掷币';

  @override
  String get liuyaoModePick => '自己挑币';

  @override
  String get liuyaoModeManual => '自掷自填';

  @override
  String get liuyaoAutoHow => '由系统替你掷三枚硬币，共掷六次，从下往上成卦。';

  @override
  String get liuyaoToss => '掷币';

  @override
  String get liuyaoTossNext => '掷下一爻';

  @override
  String get liuyaoSkip => '直接看卦';

  @override
  String get liuyaoPickHow => '24 枚硬币已经随机摆好，都扣着。凭直觉挑 18 枚，每 3 枚成一爻，从下往上。';

  @override
  String get liuyaoPickStart => '摆好硬币';

  @override
  String liuyaoPicked(int count) {
    return '已挑 $count / 18 枚';
  }

  @override
  String get liuyaoPickAgain => '重新挑';

  @override
  String get liuyaoReveal => '看卦';

  @override
  String liuyaoCoin(int n) {
    return '第 $n 枚硬币';
  }

  @override
  String liuyaoCoinFace(int n, String face) {
    return '第 $n 枚硬币：$face';
  }

  @override
  String get liuyaoManualHow =>
      '三枚硬币一起掷，共掷六次，从下往上记（第一次是初爻）。有字的一面算“字”，另一面算“背”。掷之前，先记下时间。';

  @override
  String get liuyaoTime => '起卦时间（精确到分钟）';

  @override
  String get liuyaoTimePick => '选择时间';

  @override
  String get liuyaoTimeNow => '用现在的时间';

  @override
  String get liuyaoTimeMissing => '请先填写起卦时间';

  @override
  String get liuyaoEnterBy => '填写方式';

  @override
  String get liuyaoByCoins => '按硬币';

  @override
  String get liuyaoByLines => '按爻';

  @override
  String get liuyaoBei0 => '三字';

  @override
  String get liuyaoBei1 => '一背';

  @override
  String get liuyaoBei2 => '二背';

  @override
  String get liuyaoBei3 => '三背';

  @override
  String get liuyaoOldYin => '老阴';

  @override
  String get liuyaoYoungYang => '少阳';

  @override
  String get liuyaoYoungYin => '少阴';

  @override
  String get liuyaoOldYang => '老阳';

  @override
  String get liuyaoCoinZi => '字';

  @override
  String get liuyaoCoinBei => '背';

  @override
  String get liuyaoLine1 => '初爻';

  @override
  String get liuyaoLine2 => '二爻';

  @override
  String get liuyaoLine3 => '三爻';

  @override
  String get liuyaoLine4 => '四爻';

  @override
  String get liuyaoLine5 => '五爻';

  @override
  String get liuyaoLine6 => '上爻';

  @override
  String get liuyaoCast => '起卦';

  @override
  String get liuyaoPrimary => '本卦';

  @override
  String get liuyaoChanged => '变卦';

  @override
  String liuyaoNumber(int n) {
    return '第$n卦';
  }

  @override
  String liuyaoTrigrams(String upper, String lower) {
    return '上卦 $upper\n下卦 $lower';
  }

  @override
  String liuyaoCastAt(
    String time,
    String year,
    String month,
    String day,
    String hour,
  ) {
    return '起卦于 $time · $year年 $month月 $day日 $hour时';
  }

  @override
  String get liuyaoStill => '六爻皆静，看本卦卦辞。';

  @override
  String liuyaoMoving(String lines) {
    return '动爻：$lines';
  }

  @override
  String get liuyaoMain => '看这一句';

  @override
  String get liuyaoAlso => '也看';

  @override
  String get liuyaoPlain => '直说';

  @override
  String get liuyaoSections => '解读分三部分：卦象、所问之事、建议。';

  @override
  String get topicLiuyaoHexagram => '卦象';

  @override
  String get topicLiuyaoAnswer => '所问之事';

  @override
  String get topicLiuyaoAdvice => '建议';

  @override
  String get leaveLiuyaoBody => '这次起的卦不会保留，下次要重新起卦。已生成的解读会保存在历史记录里。';

  @override
  String get followUpTitle => '继续追问';

  @override
  String get followUpIntro =>
      '就这次的结果接着问。回答只依据这次的命盘、牌面、签诗或卦象和上面的解读，不会凭空编造；问题超出它能回答的范围时，会直接告诉你。';

  @override
  String get followUpHint => '比如：这对我的工作意味着什么？';

  @override
  String get followUpSend => '发送';

  @override
  String followUpLeft(int n) {
    return '还可追问 $n 次';
  }

  @override
  String get followUpLimit => '这次结果的追问次数已用完';

  @override
  String get followUpBusy => '上一个追问还在回答，请稍候';

  @override
  String get followUpQuota => '今天的 AI 次数已用完，请明天再来';

  @override
  String get followUpAnswering => 'AI 正在依据这次的结果作答…';

  @override
  String get followUpFailed => '这次没能答上，请再问一次';

  @override
  String get followUpHeld => '这条回答需要复核，暂时不能显示';

  @override
  String get followUpOutOfScope => '超出这次结果能回答的范围';

  @override
  String get followUpStart => '可以这样问';

  @override
  String get followUpNext => '你还可以问';

  @override
  String get jumpFollowUp => '追问';

  @override
  String get kindFollowUp => '追问';

  @override
  String get followUpStartBazi1 => '我适合什么样的工作？';

  @override
  String get followUpStartBazi2 => '今年我最该注意什么？';

  @override
  String get followUpStartTarot1 => '这组牌最想提醒我什么？';

  @override
  String get followUpStartTarot2 => '我现在最该做的一步是什么？';

  @override
  String get followUpStartQiuqian1 => '签诗里哪一句最要紧？';

  @override
  String get followUpStartQiuqian2 => '这件事我该先做什么？';

  @override
  String get followUpStartLiuyao1 => '动爻在提醒我什么？';

  @override
  String get followUpStartLiuyao2 => '这件事我该等还是该动？';

  @override
  String get followUpStartFengshui1 => '我先改哪一处最容易？';

  @override
  String get followUpStartFengshui2 => '书桌放在哪里比较好？';

  @override
  String get followUpStartNaming1 => '这几个名字怎么选？';

  @override
  String get followUpStartNaming2 => '第一个名字的字义是什么？';

  @override
  String get followUpStartLife1 => '我哪个阶段最需要用心？';

  @override
  String get followUpStartLife2 => '命爻对我的工作意味着什么？';

  @override
  String get followUpAsked => '问：';

  @override
  String get archiveByTime => '按时间';

  @override
  String get archiveByPerson => '按人';

  @override
  String archiveYear(int year) {
    return '$year 年';
  }

  @override
  String archiveMonth(int month) {
    return '$month 月';
  }

  @override
  String get archiveUnfiled => '未归类';

  @override
  String archiveCount(int n) {
    return '$n 条';
  }

  @override
  String get archiveSelect => '选择';

  @override
  String archiveSelected(int n) {
    return '已选 $n 项';
  }

  @override
  String get archiveSelectAll => '全选';

  @override
  String get archiveSend => '发送';

  @override
  String get archiveDelete => '删除';

  @override
  String get archiveDownloadPdf => '下载 PDF';

  @override
  String get archiveDownloadWord => '下载 Word';

  @override
  String get archiveFile => '归类到…';

  @override
  String get archiveFormatTitle => '选择文档格式';

  @override
  String get archiveFormatPdf => 'PDF';

  @override
  String get archiveFormatWord => 'Word 文档';

  @override
  String get archiveDeleteTitle => '删除这些记录？';

  @override
  String archiveDeleteBody(int n) {
    return '将删除 $n 条记录，连同它们的追问和破除运势方案。删除后无法恢复。';
  }

  @override
  String archiveDeleted(int n) {
    return '已删除 $n 条记录';
  }

  @override
  String get archiveFileHint => '其他名字';

  @override
  String get archiveFileNone => '不归类';

  @override
  String get archiveWorking => '正在生成文档…';

  @override
  String get archiveNotReady => '只有已完成的记录能下载或发送';

  @override
  String get archiveDocFailed => '文档没能生成，请稍后再试';

  @override
  String get archiveMethod => '类型';

  @override
  String get archiveTime => '时间';

  @override
  String get menu => '菜单';

  @override
  String get settingsAccountGroup => '账号与登录';

  @override
  String get loginField => '用户名 / 邮箱 / 手机号';

  @override
  String get loginFieldHint => '手机号要先在“设置”里绑定';

  @override
  String get username => '用户名';

  @override
  String get usernameHint => '2–24 个字：字母、数字、汉字或 _ . -，以字母或汉字开头';

  @override
  String get emailOptional => '邮箱（选填）';

  @override
  String get loginFailed => '账号或密码不正确';

  @override
  String get usernameTaken => '这个用户名已被使用';

  @override
  String get emailTaken => '这个邮箱已注册，请直接登录';

  @override
  String get emailInvalid => '邮箱格式不正确';

  @override
  String get passwordWeak => '密码至少要 10 个字符';

  @override
  String get phone => '手机号';

  @override
  String get notSet => '未设置';

  @override
  String get emailVerifiedLabel => '已验证';

  @override
  String get emailUnverifiedLabel => '未验证，点此验证';

  @override
  String get phoneUnbound => '未绑定，点此绑定';

  @override
  String get loginsNote => '用户名、邮箱和已绑定的手机号都能用来登录，密码相同';

  @override
  String get usernameTitle => '用户名';

  @override
  String get usernameSaved => '用户名已保存';

  @override
  String get bindPhoneTitle => '绑定手机号';

  @override
  String get verifyEmailTitle => '验证邮箱';

  @override
  String get phoneHint => '本地号码直接填写；其他地区的号码请加区号，如 +65 9123 4567';

  @override
  String get sendCode => '发送验证码';

  @override
  String get resendCode => '重新发送';

  @override
  String get codeField => '验证码';

  @override
  String codeSentTo(String to) {
    return '验证码已发送到 $to，10 分钟内有效';
  }

  @override
  String get outboxNotice =>
      '测试环境：还没有接入短信和邮件服务，验证码不会真的发出，而是写在服务器的 .outbox 文件夹里。';

  @override
  String get confirmBind => '绑定';

  @override
  String get confirmVerify => '验证';

  @override
  String get unbindPhone => '解绑';

  @override
  String get removeEmail => '删除邮箱';

  @override
  String get phoneBoundDone => '手机号已绑定';

  @override
  String get phoneUnboundDone => '手机号已解绑';

  @override
  String get emailVerifiedDone => '邮箱已验证';

  @override
  String get emailRemovedDone => '邮箱已删除';

  @override
  String get codeWrong => '验证码不对，请再看一下';

  @override
  String get codeExpired => '验证码已过期，请重新发送';

  @override
  String get codeVoid => '验证码已失效，请重新发送';

  @override
  String get codeWait => '发送太频繁，请稍后再试';

  @override
  String get phoneTaken => '这个手机号已绑定其他账号';

  @override
  String get phoneInvalid => '手机号格式不正确';

  @override
  String get alreadyBound => '已经绑定好了';

  @override
  String get lastLogin => '至少要保留一种登录方式：用户名、邮箱或手机号';

  @override
  String get deliveryOff => '服务器还没有接入短信或邮件服务';

  @override
  String get settingsReportsGroup => '报告';

  @override
  String get emailReports => '测算完成后发到邮箱';

  @override
  String emailReportsOn(String email) {
    return '每次 AI 测算完成，报告都会发到 $email';
  }

  @override
  String emailReportsOff(String email) {
    return '开启后，每次 AI 测算完成都会把报告发到 $email';
  }

  @override
  String get emailReportsNeedsEmail => '先在上面验证邮箱，才能开启';

  @override
  String get mailOutboxNotice => '测试环境：还没有接入邮件服务，邮件写在服务器的 .outbox 文件夹里，不会真的发出。';

  @override
  String get mailOffNotice => '服务器还没有接入邮件服务，暂时不会发出。';

  @override
  String get archiveEmail => '发到邮箱';

  @override
  String get archiveEmailShort => '发邮箱';

  @override
  String get emailFirst => '先在“设置”里验证邮箱，才能发到邮箱';

  @override
  String emailedTo(String to) {
    return '已发到 $to';
  }

  @override
  String emailedOutbox(String to) {
    return '已发到 $to（测试环境：写在服务器的 .outbox 文件夹里）';
  }

  @override
  String get emailFailed => '没能发出，请稍后再试';

  @override
  String get emailTooMany => '今天发得太多了，明天再试';

  @override
  String get reportMailed => '这份报告已发到你的邮箱';

  @override
  String get reportMailFailed => '这份报告没能发到邮箱，可以在“以往记录”里再发一次';

  @override
  String get inquiryButton => '深度分析';

  @override
  String inquiryButtonNote(int n) {
    return '大师先问你几个问题（最多 $n 个），再给出更贴合你的最终解答';
  }

  @override
  String get inquiryGoalTitle => '先说说你的目标';

  @override
  String get inquiryGoalBody => '使用深度分析，一定要先给出一个明确的目标：你最想通过这次测算知道什么？';

  @override
  String get inquiryGoalHint => '比如：明年适不适合换工作？';

  @override
  String get inquiryGoalShort => '目标太短了，请写清楚你最想知道什么';

  @override
  String get inquiryGoalStart => '开始深度分析';

  @override
  String get inquiryTitle => '深度分析';

  @override
  String get inquiryAsking => '大师现在有问题要问你';

  @override
  String get inquiryAskingNote => '回答完这些问题，大师才能给你最终解答。';

  @override
  String inquiryGoalLine(String goal) {
    return '你的目标：$goal';
  }

  @override
  String inquiryProgress(int n, int planned, int max) {
    return '第 $n 个问题 · 大师打算问 $planned 个（最多 $max 个）';
  }

  @override
  String get inquiryThinking => '大师正在思考…';

  @override
  String get inquiryMaster => '大师';

  @override
  String get inquiryYou => '你';

  @override
  String get inquiryAnswerHint => '说说你的情况';

  @override
  String get inquiryAnswerSend => '回答';

  @override
  String get inquirySkip => '跳过剩下的问题，直接解答';

  @override
  String get inquiryReady => '大师已经了解你的情况，可以开始最终解答了。';

  @override
  String inquiryUnderstanding(String text) {
    return '大师的理解：$text';
  }

  @override
  String get inquiryStartReading => '开始最终解答';

  @override
  String get inquiryFailed => '大师这次没能想好问题。可以重新开始深度分析，或者回到上一页直接生成解读。';

  @override
  String get inquiryRetry => '重新开始';

  @override
  String get inquiryBusy => '大师还在思考，请稍候';

  @override
  String get inquiryLeaveBody => '深度分析还没做完，返回后这次的问答就结束了。';

  @override
  String inquiryCardTitle(int n) {
    return '深度分析 · 大师问了你 $n 个问题';
  }

  @override
  String get micStart => '语音输入';

  @override
  String get micStop => '停止语音输入';

  @override
  String get micListening => '正在听，请说话…';

  @override
  String get micUnavailable => '这个浏览器暂时不能语音输入，可以用输入法自带的语音输入';

  @override
  String get micDenied => '需要允许使用麦克风，才能语音输入';

  @override
  String get micNoMatch => '没听清，请再说一次';

  @override
  String get recalcTitle => '之前已经算过';

  @override
  String recalcBody(String name, String date, String method) {
    return '“$name”在 $date 已经算过$method。是否还要重新再算一次？';
  }

  @override
  String recalcBodyQuestion(
    String name,
    String date,
    String method,
    String question,
  ) {
    return '“$name”在 $date 已经算过$method，问的是“$question”。是否还要重新再算一次？';
  }

  @override
  String get recalcView => '查看之前的';

  @override
  String get recalcAgain => '重新再算';

  @override
  String get accountSuspended => '这个账号已被管理员停用，暂时不能登录。如有疑问请联系客服。';

  @override
  String get pointsTitle => '我的积分';

  @override
  String get pointsAvailable => '可用积分';

  @override
  String pointsBalanceLine(int balance) {
    return '余额 $balance 积分';
  }

  @override
  String pointsHeldLine(int held) {
    return '进行中的测算先冻结了 $held 积分，完成后按实际用量扣除，多的退回';
  }

  @override
  String get pointsTopUp => '充值';

  @override
  String get pointsTopUpSimulated => '测试阶段为模拟充值：不收钱，点一下积分就到账。';

  @override
  String get pointsTopUpUnavailable => '充值即将开放：正式支付会在下一阶段接入。';

  @override
  String pointsPackYuan(int yuan) {
    return '$yuan 元';
  }

  @override
  String pointsPackPoints(int points) {
    return '$points 积分';
  }

  @override
  String pointsPackBonus(int percent) {
    return '多送 $percent%';
  }

  @override
  String pointsToppedUp(int points) {
    return '已充值 $points 积分（模拟，未收费）';
  }

  @override
  String get pointsHowTitle => '怎么计费';

  @override
  String get pointsHow =>
      '每次 AI 测算先按预估冻结积分，完成后按这次实际用掉的 AI 用量扣除，多冻结的退回；没有完成、没有给出结果的不扣。深度分析统一收费，不论大师问几个问题；之后的最终解读另计。';

  @override
  String get pointsEntries => '积分明细';

  @override
  String get pointsNoEntries => '还没有积分记录';

  @override
  String get pointsBazi => '八字';

  @override
  String pointsForReading(String method) {
    return '$method AI 解读';
  }

  @override
  String pointsForInquiry(String method) {
    return '$method 深度分析';
  }

  @override
  String get pointsGrantDev => '开发测试赠送';

  @override
  String get pointsGrantAdmin => '管理员赠送';

  @override
  String pointsTopUpEntry(int yuan) {
    return '充值 $yuan 元（模拟）';
  }

  @override
  String get pointsBasisMeasured => '按实际用量';

  @override
  String get pointsBasisEstimate => '演示模式，按预估';

  @override
  String get pointsBasisFlat => '统一收费';

  @override
  String pointsCost(String usd) {
    return 'AI 成本 $usd 美元';
  }

  @override
  String pointsAbout(int points) {
    return '约 $points 积分';
  }

  @override
  String pointsAboutLine(int points, int available) {
    return '约 $points 积分 · 完成后按实际用量扣除 · 可用 $available';
  }

  @override
  String pointsInquiryFee(int points) {
    return '统一收费 $points 积分，不论问几个问题；最终解读另计';
  }

  @override
  String get pointsShortTitle => '积分不足';

  @override
  String pointsShortBody(int need, int available) {
    return '这次约需 $need 积分，你现在可用 $available 积分。充值后再试一次。';
  }

  @override
  String get pointsGoTopUp => '去充值';

  @override
  String pointsFollowUpLeft(int n, int points) {
    return '还可追问 $n 次 · 每问约 $points 积分';
  }

  @override
  String remedyConfirmPoints(String topic, int points) {
    return '“$topic”的破除运势方案约需 $points 积分，生成后按实际用量从积分中扣除。';
  }

  @override
  String get adminDashboard => '管理后台';

  @override
  String adminDashboardOpen(String role) {
    return '以$role身份，在新标签页打开';
  }

  @override
  String adminDashboardCopy(String role) {
    return '以$role身份：复制地址，在浏览器里打开';
  }

  @override
  String adminLinkCopied(String url) {
    return '已复制管理后台的地址：$url';
  }

  @override
  String get staffAdmin => '管理员';

  @override
  String get staffManager => '经理';

  @override
  String get staffEditor => '网站编辑';

  @override
  String get introWelcome => '欢迎来到命理大师';

  @override
  String get introJoin =>
      '加入我们：八字、塔罗、求签、算卦与风水，东西方的智慧在这里相会。排盘由引擎精确计算，解读有据可查，仅供参考。';

  @override
  String get introSignIn => '登录 / 注册';

  @override
  String get introServices => '我们的服务';

  @override
  String get introServicesHint => '点一项服务：登录后直接进入';

  @override
  String pointsRatesNote(String date, String percent) {
    return '按 $date 的汇率换算，另加 $percent% 换算服务费';
  }

  @override
  String pointsRatesStale(String date, String percent) {
    return '汇率服务暂时无法连接，用的是 $date 的汇率，另加 $percent% 换算服务费';
  }

  @override
  String get pointsViewReceipt => '查看收据';

  @override
  String get pointsEmailNeededTitle => '先填写邮箱';

  @override
  String get pointsEmailNeededBody => '充值的收据上会写你的邮箱。请先在“设置”里填写邮箱，再来充值。';

  @override
  String get pointsGoToSettings => '去设置';

  @override
  String get receiptsTitle => '收据';

  @override
  String get receiptsAbout => '每次充值的收据：付了多少、用的汇率和服务费、得到多少积分，可以打印。';

  @override
  String get receiptsEmpty => '还没有收据：充值后会有。';

  @override
  String receiptTitle(String number) {
    return '收据 $number';
  }

  @override
  String get receiptNumber => '收据编号';

  @override
  String get receiptDate => '日期';

  @override
  String get receiptEmail => '邮箱';

  @override
  String get receiptPack => '充值';

  @override
  String receiptPackLine(int yuan, int points) {
    return '$yuan 元档，$points 积分';
  }

  @override
  String get receiptPaid => '支付';

  @override
  String get receiptRate => '汇率';

  @override
  String receiptRateLine(String rate, String currency) {
    return '1 元 = $rate $currency';
  }

  @override
  String get receiptCharge => '换算服务费';

  @override
  String receiptChargeLine(String percent) {
    return '$percent%，已含在支付金额里';
  }

  @override
  String get receiptSimulated => '模拟充值：没有实际收款。';

  @override
  String get receiptPrint => '打印';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => '命理大師';

  @override
  String get homeBazi => '八字排盤';

  @override
  String get homeBaziDesc => '依出生時間排出四柱、大運與流年，也可以生成一生運勢報告';

  @override
  String get homeTarot => '塔羅';

  @override
  String get homeTarotDesc => '抽一組牌陣，僅供娛樂和玄學學習使用';

  @override
  String get settings => '設定';

  @override
  String get language => '語言';

  @override
  String get appearance => '外觀';

  @override
  String get themeSystem => '跟隨系統';

  @override
  String get themeLight => '淺色';

  @override
  String get themeDark => '深色';

  @override
  String get themeTime => '跟隨時間';

  @override
  String get themeTimeHint => '晚上 7 點到早上 6 點為深色，其餘為淺色';

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
  String get chartGroupChart => '命盤';

  @override
  String get chartGroupMakeup => '命局';

  @override
  String get chartGroupLuck => '運勢';

  @override
  String get chartGroupReading => '解讀與報告';

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
    return '虛歲 $age';
  }

  @override
  String get aiReport => 'AI 解讀';

  @override
  String get chooseTopics => '分析方面';

  @override
  String get generate => '生成 AI 解讀';

  @override
  String get generateBazi => '用AI做更精確解讀';

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
  String get layerConclusion => '總結 · AI 生成';

  @override
  String get conclusionPortrait => '你是怎樣的人';

  @override
  String get conclusionPast => '過去';

  @override
  String get conclusionPresent => '現在';

  @override
  String get conclusionChallenges => '可能遇到的問題';

  @override
  String get conclusionGains => '得勢與得失';

  @override
  String get conclusionFuture => '未來運勢';

  @override
  String get conclusionCaution => '何時開始要注意';

  @override
  String get conclusionMomentum => '何時開始要發力';

  @override
  String get conclusionCoping => '遇到問題時怎麼辦';

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
  String get topicTarotCards => '逐張解讀';

  @override
  String get topicTarotSynthesis => '綜合解讀';

  @override
  String get topicTarotAdvice => '建議';

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
  String get pillarMore => '更多：藏干、長生、納音';

  @override
  String get pillarLess => '收起';

  @override
  String get ritualTitle => '洗牌 · 切牌 · 選牌';

  @override
  String get ritualShuffleHint => '心裡想著你的問題，按「洗牌」把牌洗勻。';

  @override
  String get ritualShuffle => '洗牌';

  @override
  String get ritualCutHint => '切牌：選一疊，放到最上面。';

  @override
  String ritualPile(int n) {
    return '第 $n 疊';
  }

  @override
  String ritualPickHint(int count, int picked) {
    return '選牌：憑直覺選 $count 張（已選 $picked 張）';
  }

  @override
  String ritualCard(int n) {
    return '第 $n 張牌，背面朝上';
  }

  @override
  String get ritualSkip => '讓牌組替我選';

  @override
  String get ritualNote => '牌由系統公平洗好，你在背面朝上時選擇；每次抽牌事後都可以核對。';

  @override
  String get tarotGlossary => '牌義圖鑑';

  @override
  String get glossaryMajor => '大阿爾卡那';

  @override
  String get glossaryWands => '權杖';

  @override
  String get glossaryCups => '聖杯';

  @override
  String get glossarySwords => '寶劍';

  @override
  String get glossaryPentacles => '星幣';

  @override
  String get glossaryKeywords => '牌面關鍵詞';

  @override
  String get dailyCard => '今日一牌';

  @override
  String get dailyCardHint => '每天一張，當天不變。點開看大圖，也可以請 AI 解讀。';

  @override
  String get dailyLot => '今日一籤';

  @override
  String get dailyLotHint => '每天一籤，當天不變。點開看籤詩，也可以請 AI 解讀。';

  @override
  String get dailyHexagram => '今日一卦';

  @override
  String get dailyHexagramHint => '每天一卦，當天不變。點開看卦辭，也可以請 AI 解讀。';

  @override
  String get spreadSingleShort => '單張';

  @override
  String get spreadThreeShort => '三張';

  @override
  String get spreadCelticShort => '凱爾特十字';

  @override
  String get spreadTwoPathsShort => '二選一';

  @override
  String get spreadRelationshipShort => '關係牌陣';

  @override
  String get tarotExample1 => '這份工作還適合我嗎？';

  @override
  String get tarotExample2 => '我們的關係會往哪裡走？';

  @override
  String get tarotExample3 => '接下來三個月我該注意什麼？';

  @override
  String get tarotExample4 => '這個決定我該怎麼做？';

  @override
  String get draw => '抽牌';

  @override
  String get reversed => '逆位';

  @override
  String get retry => '重試';

  @override
  String get errorTitle => '無法完成請求';

  @override
  String get disclaimerShort => '僅供娛樂和玄學學習使用，並非預測。';

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
  String get deleteAccountStaff => '這是管理後台的帳戶，不能在這裡刪除：請管理員在管理後台的帳戶頁面刪除。';

  @override
  String get maintenanceTitle => '系統維護中';

  @override
  String maintenanceWindow(String from, String to) {
    return '預計 $from 到 $to 之間可以再登入。';
  }

  @override
  String maintenanceUntil(String time) {
    return '預計 $time 可以再登入。';
  }

  @override
  String get maintenanceSoon => '很快就可以再登入，請稍後再試。';

  @override
  String get maintenanceStaff => '你是後台人員，可以照常使用；使用者現在看到的是這則通知。';

  @override
  String get maintenanceCheck => '再看看';

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
  String get loading => '正在載入';

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

  @override
  String get timeExact => '精確時間';

  @override
  String get timeShichen => '時辰';

  @override
  String get lunarYear => '農曆年';

  @override
  String get lunarMonth => '月';

  @override
  String get lunarDay => '日';

  @override
  String get shichenNote => '只知道時辰：時柱只精確到兩小時，相關解讀會標明為參考。';

  @override
  String get trendTitle => '運勢走勢';

  @override
  String get trendDayun => '按年齡（大運）';

  @override
  String get trendLiunian => '按年份（流年）';

  @override
  String get trendCombined => '綜合';

  @override
  String get trendTotal => '總分';

  @override
  String get trendCompare => '疊加比較';

  @override
  String get trendTapHint => '點選圖上的時期，查看各項分數與依據。';

  @override
  String trendAge(String ages) {
    return '虛歲 $ages';
  }

  @override
  String get expandAll => '展開全部';

  @override
  String get collapseAll => '收起全部';

  @override
  String get remedyTitle => '破除運勢';

  @override
  String get remedyDesc => '針對單一項目的改運方案：指明針對哪一項、哪些時期，並給出具體做法。每個項目單獨解鎖。';

  @override
  String remedyFor(String topic) {
    return '破除運勢：$topic';
  }

  @override
  String remedyUnlock(String price) {
    return '解鎖 · $price';
  }

  @override
  String get remedyView => '查看方案';

  @override
  String remedyConfirmTitle(String topic) {
    return '解鎖「$topic」破除運勢方案';
  }

  @override
  String remedyConfirmBody(String topic, String price) {
    return '此方案針對「$topic」單獨收費：$price。\n付款功能尚未接入（TODO）：現在按確認即直接扣款（示範，不會實際收費）。';
  }

  @override
  String remedyPay(String price) {
    return '確認支付 $price';
  }

  @override
  String remedyGenerating(String topic) {
    return 'AI 正在為「$topic」制定方案…';
  }

  @override
  String get remedyTarget => '針對項目';

  @override
  String get remedyFocus => '重點時期';

  @override
  String get remedySteps => '具體做法';

  @override
  String get remedyBasis => '命理依據';

  @override
  String get remedySave => '保存';

  @override
  String get remedySend => '發送';

  @override
  String get remedyPrint => '列印';

  @override
  String get remedyHeld => '方案正在審核中，暫時無法顯示。';

  @override
  String get remedyFailed => '生成失敗，請重試（不會重複收費）。';

  @override
  String get remedyDemoPaid => '示範付款（未實際收費）';

  @override
  String get placePick => '選擇出生地';

  @override
  String get placeCountry => '國家和地區';

  @override
  String get placeRegion => '省／州／縣市';

  @override
  String get placeCity => '城市';

  @override
  String get placeSearch => '搜尋';

  @override
  String get placeCommon => '常用';

  @override
  String get placeAll => '全部';

  @override
  String get placeNone => '沒有符合的結果';

  @override
  String placeDetail(String tz, String lon) {
    return '時區 $tz · 經度 $lon';
  }

  @override
  String get placeSource => '地點資料：GeoNames（CC BY 4.0）';

  @override
  String serverUnreachable(String url) {
    return '連不上伺服器 $url。\n手機上的 127.0.0.1 是手機本身：請在電腦執行 npm run api:lan，再用手機開啟 http://電腦的區域網路位址:5000。若頁面是 https，請在網址後加 ?api=https 伺服器位址。';
  }

  @override
  String get lifeTitle => '個人情況（選填）';

  @override
  String get lifeHint =>
      '同時同地出生的人命盤相同，填上你的實際情況，解讀才會貼近你本人。資料只存在本機，只在產生解讀時連同命盤送給 AI。';

  @override
  String get lifeUseName => '解讀時用名字稱呼我';

  @override
  String get lifeResidence => '現居地';

  @override
  String get lifeNotSet => '未填寫';

  @override
  String get lifeMarital => '婚姻狀況';

  @override
  String get maritalSingle => '單身';

  @override
  String get maritalDating => '戀愛中';

  @override
  String get maritalMarried => '已婚';

  @override
  String get maritalSeparated => '分居';

  @override
  String get maritalDivorced => '離婚';

  @override
  String get maritalWidowed => '喪偶';

  @override
  String get lifeChildren => '子女';

  @override
  String get childrenNone => '沒有';

  @override
  String get childrenHas => '有';

  @override
  String get lifeOccupation => '職業／行業';

  @override
  String get lifeFamily => '家庭情況';

  @override
  String get lifeFamilyHint => '例如：與父母同住、需要照顧長輩';

  @override
  String get lifeConcern => '想問的事';

  @override
  String get lifeConcernHint => '例如：明年適合轉工嗎？';

  @override
  String get sectionSummary => '一句話重點';

  @override
  String get remedyReady => '已備好';

  @override
  String get lifeEntry => '一生運勢報告';

  @override
  String get lifeEntryDesc => '易經本命卦、梅花易數、五行八卦，三法合看一生走勢';

  @override
  String get lifeGenerate => '生成一生運勢報告';

  @override
  String get lifeSubtitle => '易經本命卦　|　梅花易數　|　五行八卦';

  @override
  String lifeReportOf(String name) {
    return '$name 一生運勢報告';
  }

  @override
  String get lifeItem => '項目';

  @override
  String get lifeContent => '內容';

  @override
  String get lifeName => '姓名';

  @override
  String get lifeBirthLunar => '出生（農曆）';

  @override
  String get lifeBirthSolar => '出生（公曆）';

  @override
  String get lifeBirthPlace => '出生地';

  @override
  String get lifeTrueSolar => '真太陽時';

  @override
  String get lifeGanzhi => '生辰干支';

  @override
  String get lifeNote => '說明：本報告依傳統術數推演，僅供娛樂和玄學學習使用，不是科學預測。三種方法各自獨立推演，最後再合看。';

  @override
  String get lifeSec1 => '一、易經本命卦';

  @override
  String get lifeQigua => '起卦';

  @override
  String get lifeBenGua => '本命卦';

  @override
  String get lifeHuGua => '互卦';

  @override
  String get lifeZhiGuaShort => '之卦';

  @override
  String get lifeGuaYi => '卦義：一生的底色';

  @override
  String get lifeMingYao => '命爻';

  @override
  String get lifeZhiGua => '之卦：人生歸宿';

  @override
  String get lifeSixLines => '六爻配人生階段';

  @override
  String get lifeLine => '爻';

  @override
  String get lifeAge => '年齡';

  @override
  String get lifeYaoCi => '爻辭';

  @override
  String get lifeForLife => '對應人生';

  @override
  String get lifeSec2 => '二、梅花易數';

  @override
  String get lifeMhGua => '卦';

  @override
  String get lifeMhRel => '與體卦的關係';

  @override
  String get lifeMhStage => '主管';

  @override
  String get lifeTi => '體卦';

  @override
  String get lifeYong => '用卦';

  @override
  String get lifeHu => '互卦';

  @override
  String get lifeBian => '變卦';

  @override
  String get lifeSelf => '代表本人';

  @override
  String get lifeEarly => '早年';

  @override
  String get lifeMiddle => '中年';

  @override
  String get lifeLate => '晚年';

  @override
  String get lifeSeason => '時令';

  @override
  String get lifeMhConclusion => '梅花結論';

  @override
  String get relBihe => '比和（同氣相助）';

  @override
  String get relShengti => '生體（得助）';

  @override
  String get relTisheng => '體生（耗洩）';

  @override
  String get relTike => '體克（我剋為財，辛苦得）';

  @override
  String get relKeti => '剋體（受壓）';

  @override
  String get lifeSec3 => '三、五行八卦';

  @override
  String get lifeWuxingDist => '五行分佈（加權，簡化計分）';

  @override
  String get lifeFavorable => '喜';

  @override
  String get lifeUnfavorable => '忌';

  @override
  String get lifeBazhai => '八卦命卦（八宅）';

  @override
  String lifeKua(String kua, String name, String group, String wuxing) {
    return '命卦 $kua · $name卦（$group，五行屬$wuxing）';
  }

  @override
  String get lifeDaily => '日常宜用';

  @override
  String get lifeSec4 => '四、分項運勢';

  @override
  String get lifeTopicPersonality => '性格';

  @override
  String get lifeTopicCareer => '事業';

  @override
  String get lifeTopicWealth => '財運';

  @override
  String get lifeTopicRelationships => '情感與婚姻';

  @override
  String get lifeTopicChildren => '家庭與子女';

  @override
  String get lifeTopicParents => '父母';

  @override
  String get lifeTopicHealth => '健康';

  @override
  String get lifeSec5 => '五、人生階段總覽';

  @override
  String get lifeYears => '年份';

  @override
  String get lifeFortune => '運勢';

  @override
  String get lifeFocus => '重點';

  @override
  String get lifeSec6 => '六、總評與建議';

  @override
  String get lifeDownload => '下載報告包';

  @override
  String get lifePrint => '列印 / 儲存 PDF';

  @override
  String get lifeGenerating => 'AI 正在撰寫一生運勢報告…';

  @override
  String get lifeStageMethods => '推演易經、梅花與八宅';

  @override
  String get lifeStageTopics => '撰寫分項運勢與人生階段';

  @override
  String get lifeTook => '大約需要 3–5 分鐘。可以先離開這個頁面，完成後回來查看。';

  @override
  String get lifeDirection => '方位';

  @override
  String get lifeStar => '星名';

  @override
  String get lifeLuck => '吉凶';

  @override
  String get lifeMhName => '卦名';

  @override
  String get lifeWuxing => '五行';

  @override
  String get reviewTitle => '內容審核';

  @override
  String get reviewEmpty => '目前沒有待審核的內容。';

  @override
  String get reviewHint => '這裡是被合規檢查攔下的內容。確認沒有問題才通過；規則層攔截的只能查看或駁回。';

  @override
  String get kindReport => 'AI 解讀';

  @override
  String get kindRemedy => '破除運勢方案';

  @override
  String get kindLife => '一生運勢報告';

  @override
  String get reviewHeld => '待審核';

  @override
  String get reviewBlocked => '規則層攔截';

  @override
  String get reviewReasons => '攔截原因';

  @override
  String get reviewRuleHits => '規則命中';

  @override
  String get reviewGuard => 'AI 審核意見';

  @override
  String get reviewContent => '內容';

  @override
  String get reviewNote => '審核備註（可選）';

  @override
  String get reviewApprove => '通過並發布';

  @override
  String get reviewReject => '駁回';

  @override
  String get reviewBlockedOnly => '規則層攔截屬於硬性違規，只能駁回，不能發布。';

  @override
  String get reviewApproved => '已通過並發布給用戶';

  @override
  String get reviewRejected => '已駁回';

  @override
  String get reviewNoContent => '這條沒有保留內容。';

  @override
  String get modeChart => '排盤解讀';

  @override
  String get addTester => '新增測試者';

  @override
  String editCurrent(String name) {
    return '編輯「$name」的資料';
  }

  @override
  String get leaveReadingTitle => '返回將重新開始';

  @override
  String get leaveReadingBody => '這次測算還沒有完成，返回後需要重新開始。';

  @override
  String get leaveFormBody => '本次填寫的內容不會保留，返回後需要重新填寫。';

  @override
  String get leaveChartBody => '返回後要重新排盤才能再看到這個命盤。已生成的解讀會保存在歷史紀錄裡。';

  @override
  String get leaveTarotBody => '這次抽到的牌不會保留，下次要重新抽牌。已生成的解讀會保存在歷史紀錄裡。';

  @override
  String get leaveReadingStay => '繼續測算';

  @override
  String get leaveReadingGo => '返回';

  @override
  String get leaveEditsTitle => '放棄未儲存的修改？';

  @override
  String get leaveEditsBody => '返回後，這次的修改不會儲存。';

  @override
  String get leaveEditsStay => '繼續編輯';

  @override
  String get leaveEditsGo => '放棄修改';

  @override
  String get keysTitle => '鍵盤快速鍵';

  @override
  String get keysTab => '移到下一個／上一個控制項';

  @override
  String get keySpace => '空白鍵';

  @override
  String get keysPress => '按下按鈕；展開或收起段落';

  @override
  String get keysEsc => '返回上一層：先關閉選單和對話框；測算未完成時會先提醒';

  @override
  String get keysArrows => '切換選項（如 公曆／農曆）和圖表時期；捲動 大運／流年';

  @override
  String get keysScroll => '捲動頁面；在選單裡上下選擇';

  @override
  String get keysSubmit => '提交表單：登入、排盤、抽牌、儲存';

  @override
  String get keysHelp => '開啟這個列表';

  @override
  String get keysBrowser => '切換瀏覽器分頁：這是瀏覽器自己的快速鍵，本應用不佔用。應用內切換選項請用 ← →';

  @override
  String get close => '關閉';

  @override
  String cardHidden(String position) {
    return '$position，未翻開';
  }

  @override
  String get tarotQuestion => '你想問的問題';

  @override
  String get tarotQuestionHint => '先寫下你想問的問題才能抽牌：有所問，牌才有所答，解讀也圍繞它展開。';

  @override
  String get tarotQuestionMissing => '先寫下你想問的問題，才能抽牌';

  @override
  String get tarotFocus => '想看哪方面（可選）';

  @override
  String get focusAny => '不限';

  @override
  String get focusCareer => '事業';

  @override
  String get focusLove => '感情';

  @override
  String get focusHealth => '健康';

  @override
  String get focusSelf => '自我';

  @override
  String get tarotSections => '解讀分三部分：逐張解讀、綜合解讀、建議。';

  @override
  String tarotQuestionShown(String question) {
    return '問題：$question';
  }

  @override
  String tarotSlot(int n, String position) {
    return '第 $n 張 · $position';
  }

  @override
  String tarotNext(String slot) {
    return '按牌陣順序翻牌，下一張：$slot';
  }

  @override
  String get tarotNextShort => '下一張';

  @override
  String get tarotZoomHint => '點擊小牌放大，在大圖裡翻開。';

  @override
  String get tarotAllTurned => '牌已全部翻開。點擊任意一張，看大圖和位置含義。';

  @override
  String get tarotTapToTurn => '點擊牌面翻開';

  @override
  String get shenshaTitle => '神煞 · 空亡 · 胎元';

  @override
  String get relationsTitle => '原局刑沖合害';

  @override
  String get ziNextDay => '23:00–24:00 出生，日柱算次日';

  @override
  String get ziNextDayHint => '子時有兩種算法；預設 23:00 後出生仍算當天';

  @override
  String get notDeLing => '不得令';

  @override
  String favorableIs(String elements) {
    return '喜用：$elements';
  }

  @override
  String unfavorableIs(String elements) {
    return '忌：$elements';
  }

  @override
  String get specialNote => '宜請有經驗的師傅細看';

  @override
  String get termTipHint => '點選帶虛線的術語，查看它的意思。';

  @override
  String termTipAbout(String term) {
    return '什麼是$term？';
  }

  @override
  String get shenshaName => '神煞';

  @override
  String get timelineNow => '當前';

  @override
  String get timelineThisYear => '今年';

  @override
  String get dayunTapHint => '點選一步大運，查看它的十年。';

  @override
  String dayunYears(String ganzhi, int from, int to) {
    return '$ganzhi大運 · $from–$to年';
  }

  @override
  String liuyueOf(int year) {
    return '$year年流月';
  }

  @override
  String pillarRelation(String pillar, String relation) {
    return '$pillar$relation';
  }

  @override
  String get jumpTo => '跳到';

  @override
  String get jumpActions => '行動建議';

  @override
  String get jumpConclusion => '總結';

  @override
  String get shareImage => '分享圖片';

  @override
  String get shareImageFailed => '暫時無法生成分享圖，請稍後再試。';

  @override
  String get homeQiuqian => '求籤';

  @override
  String get homeQiuqianDesc => '搖籤、擲筊，求一首籤詩，僅供娛樂和玄學學習使用';

  @override
  String get qiuqianQuestion => '所求之事';

  @override
  String get qiuqianQuestionHint => '先寫下所求之事才能求籤：有所求，才能去求。問題只用於解籤，不會出現在分享圖上。';

  @override
  String get qiuqianQuestionMissing => '先寫下所求之事，才能求籤';

  @override
  String get qiuqianExample1 => '今年的工作會順利嗎？';

  @override
  String get qiuqianExample2 => '這段關係該怎麼經營？';

  @override
  String get qiuqianExample3 => '搬家的事該怎麼決定？';

  @override
  String get qiuqianHowTo => '搖籤筒，一支籤落下；再擲筊請示：聖筊（一平一凸）就是這一支，笑筊或陰筊就把籤放回再搖。';

  @override
  String get qiuqianDraw => '求籤';

  @override
  String get qiuqianThrow => '擲筊';

  @override
  String get qiuqianAgain => '放回再搖';

  @override
  String get qiuqianSkip => '直接看結果';

  @override
  String get qiuqianCylinder => '籤';

  @override
  String get qiuqianShaking => '搖籤中……';

  @override
  String get qiuqianTossing => '擲筊中……';

  @override
  String qiuqianStickFell(String title) {
    return '搖出$title';
  }

  @override
  String get qiuqianSheng => '聖筊：神明應允，就是這一支';

  @override
  String get qiuqianXiao => '笑筊：神明一笑，把籤放回再求';

  @override
  String get qiuqianYin => '陰筊：神明未允，把籤放回再求';

  @override
  String get qiuqianYourLot => '你求得的籤';

  @override
  String get qiuqianTextNote => '籤詩依臺灣廟宇通行文本，並以清代刻本校訂。';

  @override
  String get qiuqianSections => '解籤分三部分：籤詩、所問之事、建議。';

  @override
  String get leaveQiuqianBody => '這次求得的籤不會保留，下次要重新求籤。已生成的解讀會保存在歷史紀錄裡。';

  @override
  String get topicQiuqianPoem => '籤詩';

  @override
  String get topicQiuqianAnswer => '所問之事';

  @override
  String get topicQiuqianAdvice => '建議';

  @override
  String get blockFlat => '平面朝上';

  @override
  String get blockRound => '凸面朝上';

  @override
  String get homeFengshui => '風水';

  @override
  String get homeFengshuiDesc => '房間佈局的通用原則：採光、通風與動線，不論吉凶';

  @override
  String get fengshuiRoom => '哪個房間';

  @override
  String get fengshuiFacing => '主要窗戶朝向（可不選）';

  @override
  String get fengshuiFacingUnknown => '不確定';

  @override
  String get fengshuiDescription => '房間現況（可不填）';

  @override
  String get fengshuiDescriptionHint => '例如「床在窗下，門在左邊」。只用於解讀，不會保存地址或平面圖。';

  @override
  String get fengshuiLook => '看佈局';

  @override
  String get fengshuiPrinciples => '這個房間可以留意';

  @override
  String get fengshuiNote => '這些是通用的空間原則，不是對住宅吉凶的判斷。';

  @override
  String get fengshuiSections => '解讀分三部分：佈局、光線與動線、建議。';

  @override
  String fengshuiDirection(String direction, String trigram, String element) {
    return '傳統上：$direction · $trigram · $element';
  }

  @override
  String get topicFengshuiLayout => '佈局';

  @override
  String get topicFengshuiFlow => '光線與動線';

  @override
  String get topicFengshuiAdvice => '建議';

  @override
  String get homeNaming => '起名';

  @override
  String get namingFromChart => '為這個命盤起名';

  @override
  String get namingSurname => '姓氏';

  @override
  String get namingSurnameHint => '一或兩個漢字，例如「陳」或「歐陽」';

  @override
  String get namingLength => '名字';

  @override
  String get namingOne => '單字名';

  @override
  String get namingTwo => '雙字名';

  @override
  String get namingSuggest => '起名';

  @override
  String namingElements(String elements) {
    return '名字所補：$elements';
  }

  @override
  String get namingBalance => '這個命盤沒有明顯的喜用，名字以五行平衡為主。';

  @override
  String get namingCandidates => '候選名字';

  @override
  String get namingDraft => '這些名字所用的字義庫仍待專家校訂。';

  @override
  String get namingNote => '名字是祝福與聲音，不決定任何人的命運。';

  @override
  String get namingSections => '解讀分兩部分：候選名字、怎麼挑選。';

  @override
  String get topicNamingCandidates => '候選名字';

  @override
  String get topicNamingAdvice => '建議';

  @override
  String get homeLiuyao => '算卦';

  @override
  String get homeLiuyaoDesc => '擲三枚硬幣六次起卦，或自己擲好再填，馬上看卦辭直說，僅供娛樂和玄學學習使用';

  @override
  String get homeEast => '東方';

  @override
  String get homeWest => '西方';

  @override
  String get liuyaoQuestion => '想問的事';

  @override
  String get liuyaoQuestionHint => '先寫下想問的事才能起卦。一次只問一件事，問得越具體，解讀越貼切';

  @override
  String get liuyaoQuestionMissing => '先寫下想問的事，才能起卦';

  @override
  String get liuyaoRemind => '起卦之前';

  @override
  String get liuyaoGroupAsk => '問卦';

  @override
  String get liuyaoGroupCast => '起卦';

  @override
  String get liuyaoGroupResult => '得卦';

  @override
  String get liuyaoGroupReading => '解讀';

  @override
  String get liuyaoRemindBody => '先靜下心，把要問的事想清楚。一次只問一件事，同一件事不要一再重問。';

  @override
  String get liuyaoMode => '起卦方式';

  @override
  String get liuyaoModeAuto => '自動擲幣';

  @override
  String get liuyaoModePick => '自己挑幣';

  @override
  String get liuyaoModeManual => '自擲自填';

  @override
  String get liuyaoAutoHow => '由系統替你擲三枚硬幣，共擲六次，從下往上成卦。';

  @override
  String get liuyaoToss => '擲幣';

  @override
  String get liuyaoTossNext => '擲下一爻';

  @override
  String get liuyaoSkip => '直接看卦';

  @override
  String get liuyaoPickHow => '24 枚硬幣已經隨機擺好，都蓋著。憑直覺挑 18 枚，每 3 枚成一爻，從下往上。';

  @override
  String get liuyaoPickStart => '擺好硬幣';

  @override
  String liuyaoPicked(int count) {
    return '已挑 $count / 18 枚';
  }

  @override
  String get liuyaoPickAgain => '重新挑';

  @override
  String get liuyaoReveal => '看卦';

  @override
  String liuyaoCoin(int n) {
    return '第 $n 枚硬幣';
  }

  @override
  String liuyaoCoinFace(int n, String face) {
    return '第 $n 枚硬幣：$face';
  }

  @override
  String get liuyaoManualHow =>
      '三枚硬幣一起擲，共擲六次，從下往上記（第一次是初爻）。有字的一面算「字」，另一面算「背」。擲之前，先記下時間。';

  @override
  String get liuyaoTime => '起卦時間（精確到分鐘）';

  @override
  String get liuyaoTimePick => '選擇時間';

  @override
  String get liuyaoTimeNow => '用現在的時間';

  @override
  String get liuyaoTimeMissing => '請先填寫起卦時間';

  @override
  String get liuyaoEnterBy => '填寫方式';

  @override
  String get liuyaoByCoins => '按硬幣';

  @override
  String get liuyaoByLines => '按爻';

  @override
  String get liuyaoBei0 => '三字';

  @override
  String get liuyaoBei1 => '一背';

  @override
  String get liuyaoBei2 => '二背';

  @override
  String get liuyaoBei3 => '三背';

  @override
  String get liuyaoOldYin => '老陰';

  @override
  String get liuyaoYoungYang => '少陽';

  @override
  String get liuyaoYoungYin => '少陰';

  @override
  String get liuyaoOldYang => '老陽';

  @override
  String get liuyaoCoinZi => '字';

  @override
  String get liuyaoCoinBei => '背';

  @override
  String get liuyaoLine1 => '初爻';

  @override
  String get liuyaoLine2 => '二爻';

  @override
  String get liuyaoLine3 => '三爻';

  @override
  String get liuyaoLine4 => '四爻';

  @override
  String get liuyaoLine5 => '五爻';

  @override
  String get liuyaoLine6 => '上爻';

  @override
  String get liuyaoCast => '起卦';

  @override
  String get liuyaoPrimary => '本卦';

  @override
  String get liuyaoChanged => '變卦';

  @override
  String liuyaoNumber(int n) {
    return '第$n卦';
  }

  @override
  String liuyaoTrigrams(String upper, String lower) {
    return '上卦 $upper\n下卦 $lower';
  }

  @override
  String liuyaoCastAt(
    String time,
    String year,
    String month,
    String day,
    String hour,
  ) {
    return '起卦於 $time · $year年 $month月 $day日 $hour時';
  }

  @override
  String get liuyaoStill => '六爻皆靜，看本卦卦辭。';

  @override
  String liuyaoMoving(String lines) {
    return '動爻：$lines';
  }

  @override
  String get liuyaoMain => '看這一句';

  @override
  String get liuyaoAlso => '也看';

  @override
  String get liuyaoPlain => '直說';

  @override
  String get liuyaoSections => '解讀分三部分：卦象、所問之事、建議。';

  @override
  String get topicLiuyaoHexagram => '卦象';

  @override
  String get topicLiuyaoAnswer => '所問之事';

  @override
  String get topicLiuyaoAdvice => '建議';

  @override
  String get leaveLiuyaoBody => '這次起的卦不會保留，下次要重新起卦。已生成的解讀會保存在歷史紀錄裡。';

  @override
  String get followUpTitle => '繼續追問';

  @override
  String get followUpIntro =>
      '就這次的結果接著問。回答只依據這次的命盤、牌面、籤詩或卦象和上面的解讀，不會憑空編造；問題超出它能回答的範圍時，會直接告訴你。';

  @override
  String get followUpHint => '比如：這對我的工作意味著什麼？';

  @override
  String get followUpSend => '發送';

  @override
  String followUpLeft(int n) {
    return '還可追問 $n 次';
  }

  @override
  String get followUpLimit => '這次結果的追問次數已用完';

  @override
  String get followUpBusy => '上一個追問還在回答，請稍候';

  @override
  String get followUpQuota => '今天的 AI 次數已用完，請明天再來';

  @override
  String get followUpAnswering => 'AI 正在依據這次的結果作答…';

  @override
  String get followUpFailed => '這次沒能答上，請再問一次';

  @override
  String get followUpHeld => '這條回答需要覆核，暫時不能顯示';

  @override
  String get followUpOutOfScope => '超出這次結果能回答的範圍';

  @override
  String get followUpStart => '可以這樣問';

  @override
  String get followUpNext => '你還可以問';

  @override
  String get jumpFollowUp => '追問';

  @override
  String get kindFollowUp => '追問';

  @override
  String get followUpStartBazi1 => '我適合什麼樣的工作？';

  @override
  String get followUpStartBazi2 => '今年我最該注意什麼？';

  @override
  String get followUpStartTarot1 => '這組牌最想提醒我什麼？';

  @override
  String get followUpStartTarot2 => '我現在最該做的一步是什麼？';

  @override
  String get followUpStartQiuqian1 => '籤詩裡哪一句最要緊？';

  @override
  String get followUpStartQiuqian2 => '這件事我該先做什麼？';

  @override
  String get followUpStartLiuyao1 => '動爻在提醒我什麼？';

  @override
  String get followUpStartLiuyao2 => '這件事我該等還是該動？';

  @override
  String get followUpStartFengshui1 => '我先改哪一處最容易？';

  @override
  String get followUpStartFengshui2 => '書桌放在哪裡比較好？';

  @override
  String get followUpStartNaming1 => '這幾個名字怎麼選？';

  @override
  String get followUpStartNaming2 => '第一個名字的字義是什麼？';

  @override
  String get followUpStartLife1 => '我哪個階段最需要用心？';

  @override
  String get followUpStartLife2 => '命爻對我的工作意味著什麼？';

  @override
  String get followUpAsked => '問：';

  @override
  String get archiveByTime => '按時間';

  @override
  String get archiveByPerson => '按人';

  @override
  String archiveYear(int year) {
    return '$year 年';
  }

  @override
  String archiveMonth(int month) {
    return '$month 月';
  }

  @override
  String get archiveUnfiled => '未歸類';

  @override
  String archiveCount(int n) {
    return '$n 條';
  }

  @override
  String get archiveSelect => '選擇';

  @override
  String archiveSelected(int n) {
    return '已選 $n 項';
  }

  @override
  String get archiveSelectAll => '全選';

  @override
  String get archiveSend => '發送';

  @override
  String get archiveDelete => '刪除';

  @override
  String get archiveDownloadPdf => '下載 PDF';

  @override
  String get archiveDownloadWord => '下載 Word';

  @override
  String get archiveFile => '歸類到…';

  @override
  String get archiveFormatTitle => '選擇文件格式';

  @override
  String get archiveFormatPdf => 'PDF';

  @override
  String get archiveFormatWord => 'Word 文件';

  @override
  String get archiveDeleteTitle => '刪除這些記錄？';

  @override
  String archiveDeleteBody(int n) {
    return '將刪除 $n 條記錄，連同它們的追問和破除運勢方案。刪除後無法恢復。';
  }

  @override
  String archiveDeleted(int n) {
    return '已刪除 $n 條記錄';
  }

  @override
  String get archiveFileHint => '其他名字';

  @override
  String get archiveFileNone => '不歸類';

  @override
  String get archiveWorking => '正在生成文件…';

  @override
  String get archiveNotReady => '只有已完成的記錄能下載或發送';

  @override
  String get archiveDocFailed => '文件沒能生成，請稍後再試';

  @override
  String get archiveMethod => '類型';

  @override
  String get archiveTime => '時間';

  @override
  String get menu => '選單';

  @override
  String get settingsAccountGroup => '帳戶與登入';

  @override
  String get loginField => '用戶名稱 / 電子郵件 / 手機號碼';

  @override
  String get loginFieldHint => '手機號碼要先在「設定」裡綁定';

  @override
  String get username => '用戶名稱';

  @override
  String get usernameHint => '2–24 個字：字母、數字、漢字或 _ . -，以字母或漢字開頭';

  @override
  String get emailOptional => '電子郵件（選填）';

  @override
  String get loginFailed => '帳戶或密碼不正確';

  @override
  String get usernameTaken => '這個用戶名稱已被使用';

  @override
  String get emailTaken => '這個電子郵件已註冊，請直接登入';

  @override
  String get emailInvalid => '電子郵件格式不正確';

  @override
  String get passwordWeak => '密碼至少要 10 個字元';

  @override
  String get phone => '手機號碼';

  @override
  String get notSet => '未設定';

  @override
  String get emailVerifiedLabel => '已驗證';

  @override
  String get emailUnverifiedLabel => '未驗證，點此驗證';

  @override
  String get phoneUnbound => '未綁定，點此綁定';

  @override
  String get loginsNote => '用戶名稱、電子郵件和已綁定的手機號碼都能用來登入，密碼相同';

  @override
  String get usernameTitle => '用戶名稱';

  @override
  String get usernameSaved => '用戶名稱已儲存';

  @override
  String get bindPhoneTitle => '綁定手機號碼';

  @override
  String get verifyEmailTitle => '驗證電子郵件';

  @override
  String get phoneHint => '本地號碼直接填寫；其他地區的號碼請加區號，如 +65 9123 4567';

  @override
  String get sendCode => '傳送驗證碼';

  @override
  String get resendCode => '重新傳送';

  @override
  String get codeField => '驗證碼';

  @override
  String codeSentTo(String to) {
    return '驗證碼已傳送到 $to，10 分鐘內有效';
  }

  @override
  String get outboxNotice =>
      '測試環境：尚未接入短訊和郵件服務，驗證碼不會真的發出，而是寫在伺服器的 .outbox 資料夾裡。';

  @override
  String get confirmBind => '綁定';

  @override
  String get confirmVerify => '驗證';

  @override
  String get unbindPhone => '解除綁定';

  @override
  String get removeEmail => '刪除電子郵件';

  @override
  String get phoneBoundDone => '手機號碼已綁定';

  @override
  String get phoneUnboundDone => '手機號碼已解除綁定';

  @override
  String get emailVerifiedDone => '電子郵件已驗證';

  @override
  String get emailRemovedDone => '電子郵件已刪除';

  @override
  String get codeWrong => '驗證碼不正確，請再看一下';

  @override
  String get codeExpired => '驗證碼已過期，請重新傳送';

  @override
  String get codeVoid => '驗證碼已失效，請重新傳送';

  @override
  String get codeWait => '傳送太頻繁，請稍後再試';

  @override
  String get phoneTaken => '這個手機號碼已綁定其他帳戶';

  @override
  String get phoneInvalid => '手機號碼格式不正確';

  @override
  String get alreadyBound => '已經綁定好了';

  @override
  String get lastLogin => '至少要保留一種登入方式：用戶名稱、電子郵件或手機號碼';

  @override
  String get deliveryOff => '伺服器尚未接入短訊或郵件服務';

  @override
  String get settingsReportsGroup => '報告';

  @override
  String get emailReports => '測算完成後發到電子郵件';

  @override
  String emailReportsOn(String email) {
    return '每次 AI 測算完成，報告都會發到 $email';
  }

  @override
  String emailReportsOff(String email) {
    return '開啟後，每次 AI 測算完成都會把報告發到 $email';
  }

  @override
  String get emailReportsNeedsEmail => '先在上面驗證電子郵件，才能開啟';

  @override
  String get mailOutboxNotice => '測試環境：尚未接入郵件服務，郵件寫在伺服器的 .outbox 資料夾裡，不會真的發出。';

  @override
  String get mailOffNotice => '伺服器尚未接入郵件服務，暫時不會發出。';

  @override
  String get archiveEmail => '發到電子郵件';

  @override
  String get archiveEmailShort => '發郵件';

  @override
  String get emailFirst => '先在「設定」裡驗證電子郵件，才能發到電子郵件';

  @override
  String emailedTo(String to) {
    return '已發到 $to';
  }

  @override
  String emailedOutbox(String to) {
    return '已發到 $to（測試環境：寫在伺服器的 .outbox 資料夾裡）';
  }

  @override
  String get emailFailed => '沒能發出，請稍後再試';

  @override
  String get emailTooMany => '今天發得太多了，明天再試';

  @override
  String get reportMailed => '這份報告已發到你的電子郵件';

  @override
  String get reportMailFailed => '這份報告沒能發到電子郵件，可以在「以往紀錄」裡再發一次';

  @override
  String get inquiryButton => '深度分析';

  @override
  String inquiryButtonNote(int n) {
    return '大師先問你幾個問題（最多 $n 個），再給出更貼合你的最終解答';
  }

  @override
  String get inquiryGoalTitle => '先說說你的目標';

  @override
  String get inquiryGoalBody => '使用深度分析，一定要先給出一個明確的目標：你最想透過這次測算知道什麼？';

  @override
  String get inquiryGoalHint => '例如：明年適不適合換工作？';

  @override
  String get inquiryGoalShort => '目標太短了，請寫清楚你最想知道什麼';

  @override
  String get inquiryGoalStart => '開始深度分析';

  @override
  String get inquiryTitle => '深度分析';

  @override
  String get inquiryAsking => '大師現在有問題要問你';

  @override
  String get inquiryAskingNote => '回答完這些問題，大師才能給你最終解答。';

  @override
  String inquiryGoalLine(String goal) {
    return '你的目標：$goal';
  }

  @override
  String inquiryProgress(int n, int planned, int max) {
    return '第 $n 個問題 · 大師打算問 $planned 個（最多 $max 個）';
  }

  @override
  String get inquiryThinking => '大師正在思考…';

  @override
  String get inquiryMaster => '大師';

  @override
  String get inquiryYou => '你';

  @override
  String get inquiryAnswerHint => '說說你的情況';

  @override
  String get inquiryAnswerSend => '回答';

  @override
  String get inquirySkip => '跳過剩下的問題，直接解答';

  @override
  String get inquiryReady => '大師已經了解你的情況，可以開始最終解答了。';

  @override
  String inquiryUnderstanding(String text) {
    return '大師的理解：$text';
  }

  @override
  String get inquiryStartReading => '開始最終解答';

  @override
  String get inquiryFailed => '大師這次沒能想好問題。可以重新開始深度分析，或者回到上一頁直接生成解讀。';

  @override
  String get inquiryRetry => '重新開始';

  @override
  String get inquiryBusy => '大師還在思考，請稍候';

  @override
  String get inquiryLeaveBody => '深度分析還沒做完，返回後這次的問答就結束了。';

  @override
  String inquiryCardTitle(int n) {
    return '深度分析 · 大師問了你 $n 個問題';
  }

  @override
  String get micStart => '語音輸入';

  @override
  String get micStop => '停止語音輸入';

  @override
  String get micListening => '正在聽，請說話…';

  @override
  String get micUnavailable => '這個瀏覽器暫時不能語音輸入，可以用輸入法內建的語音輸入';

  @override
  String get micDenied => '需要允許使用麥克風，才能語音輸入';

  @override
  String get micNoMatch => '沒聽清楚，請再說一次';

  @override
  String get recalcTitle => '之前已經算過';

  @override
  String recalcBody(String name, String date, String method) {
    return '「$name」在 $date 已經算過$method。是否還要重新再算一次？';
  }

  @override
  String recalcBodyQuestion(
    String name,
    String date,
    String method,
    String question,
  ) {
    return '「$name」在 $date 已經算過$method，問的是「$question」。是否還要重新再算一次？';
  }

  @override
  String get recalcView => '查看之前的';

  @override
  String get recalcAgain => '重新再算';

  @override
  String get accountSuspended => '這個帳戶已被管理員停用，暫時不能登入。如有疑問請聯絡客服。';

  @override
  String get pointsTitle => '我的積分';

  @override
  String get pointsAvailable => '可用積分';

  @override
  String pointsBalanceLine(int balance) {
    return '餘額 $balance 積分';
  }

  @override
  String pointsHeldLine(int held) {
    return '進行中的測算先凍結了 $held 積分，完成後按實際用量扣除，多的退回';
  }

  @override
  String get pointsTopUp => '充值';

  @override
  String get pointsTopUpSimulated => '測試階段為模擬充值：不收錢，點一下積分就到帳。';

  @override
  String get pointsTopUpUnavailable => '充值即將開放：正式付款會在下一階段接入。';

  @override
  String pointsPackYuan(int yuan) {
    return '$yuan 元';
  }

  @override
  String pointsPackPoints(int points) {
    return '$points 積分';
  }

  @override
  String pointsPackBonus(int percent) {
    return '多送 $percent%';
  }

  @override
  String pointsToppedUp(int points) {
    return '已充值 $points 積分（模擬，未收費）';
  }

  @override
  String get pointsHowTitle => '怎麼計費';

  @override
  String get pointsHow =>
      '每次 AI 測算先按預估凍結積分，完成後按這次實際用掉的 AI 用量扣除，多凍結的退回；沒有完成、沒有給出結果的不扣。深度分析統一收費，不論大師問幾個問題；之後的最終解讀另計。';

  @override
  String get pointsEntries => '積分明細';

  @override
  String get pointsNoEntries => '還沒有積分紀錄';

  @override
  String get pointsBazi => '八字';

  @override
  String pointsForReading(String method) {
    return '$method AI 解讀';
  }

  @override
  String pointsForInquiry(String method) {
    return '$method 深度分析';
  }

  @override
  String get pointsGrantDev => '開發測試贈送';

  @override
  String get pointsGrantAdmin => '管理員贈送';

  @override
  String pointsTopUpEntry(int yuan) {
    return '充值 $yuan 元（模擬）';
  }

  @override
  String get pointsBasisMeasured => '按實際用量';

  @override
  String get pointsBasisEstimate => '示範模式，按預估';

  @override
  String get pointsBasisFlat => '統一收費';

  @override
  String pointsCost(String usd) {
    return 'AI 成本 $usd 美元';
  }

  @override
  String pointsAbout(int points) {
    return '約 $points 積分';
  }

  @override
  String pointsAboutLine(int points, int available) {
    return '約 $points 積分 · 完成後按實際用量扣除 · 可用 $available';
  }

  @override
  String pointsInquiryFee(int points) {
    return '統一收費 $points 積分，不論問幾個問題；最終解讀另計';
  }

  @override
  String get pointsShortTitle => '積分不足';

  @override
  String pointsShortBody(int need, int available) {
    return '這次約需 $need 積分，你現在可用 $available 積分。充值後再試一次。';
  }

  @override
  String get pointsGoTopUp => '去充值';

  @override
  String pointsFollowUpLeft(int n, int points) {
    return '還可追問 $n 次 · 每問約 $points 積分';
  }

  @override
  String remedyConfirmPoints(String topic, int points) {
    return '「$topic」的破除運勢方案約需 $points 積分，生成後按實際用量從積分中扣除。';
  }

  @override
  String get adminDashboard => '管理後台';

  @override
  String adminDashboardOpen(String role) {
    return '以$role身份，在新分頁開啟';
  }

  @override
  String adminDashboardCopy(String role) {
    return '以$role身份：複製網址，在瀏覽器裡開啟';
  }

  @override
  String adminLinkCopied(String url) {
    return '已複製管理後台的網址：$url';
  }

  @override
  String get staffAdmin => '管理員';

  @override
  String get staffManager => '經理';

  @override
  String get staffEditor => '網站編輯';

  @override
  String get introWelcome => '歡迎來到命理大師';

  @override
  String get introJoin =>
      '加入我們：八字、塔羅、求籤、算卦與風水，東西方的智慧在這裡相會。排盤由引擎精確計算，解讀有據可查，僅供參考。';

  @override
  String get introSignIn => '登入 / 註冊';

  @override
  String get introServices => '我們的服務';

  @override
  String get introServicesHint => '點一項服務：登入後直接進入';

  @override
  String pointsRatesNote(String date, String percent) {
    return '按 $date 的匯率換算，另加 $percent% 換算服務費';
  }

  @override
  String pointsRatesStale(String date, String percent) {
    return '匯率服務暫時連不上，用的是 $date 的匯率，另加 $percent% 換算服務費';
  }

  @override
  String get pointsViewReceipt => '查看收據';

  @override
  String get pointsEmailNeededTitle => '先填寫電子郵件';

  @override
  String get pointsEmailNeededBody => '充值的收據上會寫你的電子郵件。請先在「設定」裡填寫電子郵件，再來充值。';

  @override
  String get pointsGoToSettings => '去設定';

  @override
  String get receiptsTitle => '收據';

  @override
  String get receiptsAbout => '每次充值的收據：付了多少、用的匯率和服務費、得到多少積分，可以列印。';

  @override
  String get receiptsEmpty => '還沒有收據：充值後會有。';

  @override
  String receiptTitle(String number) {
    return '收據 $number';
  }

  @override
  String get receiptNumber => '收據編號';

  @override
  String get receiptDate => '日期';

  @override
  String get receiptEmail => '電子郵件';

  @override
  String get receiptPack => '充值';

  @override
  String receiptPackLine(int yuan, int points) {
    return '$yuan 元檔，$points 積分';
  }

  @override
  String get receiptPaid => '支付';

  @override
  String get receiptRate => '匯率';

  @override
  String receiptRateLine(String rate, String currency) {
    return '1 元 = $rate $currency';
  }

  @override
  String get receiptCharge => '換算服務費';

  @override
  String receiptChargeLine(String percent) {
    return '$percent%，已含在支付金額裡';
  }

  @override
  String get receiptSimulated => '模擬充值：沒有實際收款。';

  @override
  String get receiptPrint => '列印';
}
