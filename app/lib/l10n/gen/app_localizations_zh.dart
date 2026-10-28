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
    return '$ages 岁';
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
  String get tarotQuestion => '你想问的问题（可选）';

  @override
  String get tarotQuestionHint => '抽牌前先在心里想好一个问题，解读会围绕它展开。';

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
    return '$ages 歲';
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
  String get tarotQuestion => '你想問的問題（可選）';

  @override
  String get tarotQuestionHint => '抽牌前先在心裡想好一個問題，解讀會圍繞它展開。';

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
}
