/**
 * 内容 by page (S33 WP33.2): what the 内容 page calls the app's pages and the parts on the way to a text, by the name
 * of the code that makes them (usage.ts reads where each text is used). A page is every `…Page` class, and the app
 * around them; a new page without a name here fails test/content-pages.test.ts. A part without a name is passed over:
 * the way to a text names only what an editor (网站编辑) would know on screen.
 */

/** The pages, in the order the 内容 page lists them. */
export const PAGES: Record<string, string> = {
  MingliApp: "整个应用",
  IntroPage: "欢迎页（登录前）",
  SignInPage: "登录 / 注册",
  MaintenancePage: "维护中（登录后）",
  HomePage: "首页",
  BaziFormPage: "八字 · 填资料",
  BaziChartPage: "八字 · 命盘",
  LifeReportPage: "八字 · 一生运势报告",
  TarotPage: "塔罗",
  TarotGlossaryPage: "塔罗 · 图鉴",
  DailyCardPage: "今日一牌",
  QiuqianPage: "求签",
  LiuyaoPage: "算卦",
  EastDailyPage: "今日一卦 / 今日一签",
  FengshuiPage: "风水",
  NamingPage: "起名",
  InquiryPage: "深度分析",
  ReportPage: "解读",
  HistoryPage: "以往记录",
  PointsPage: "我的积分",
  ReceiptsPage: "收据",
  ReceiptPage: "收据 · 一张",
  SettingsPage: "设置",
  ProfilesPage: "为谁排盘",
  ProfileEditPage: "为谁排盘 · 编辑",
  PlacePickerPage: "选出生地",
  ReviewPage: "内容审核",
  ReviewDetailPage: "内容审核 · 详情",
};

/**
 * The parts on the way to a text: widgets, dialogs and steps, as they show on screen. A private one (`_Tosses`) is
 * named by its file too (`liuyao_page.dart#_Tosses`): the same private name may be another part elsewhere. A member of
 * the labels extension starts with a dot (`.topic`).
 */
export const PARTS: Record<string, string> = {
  // On many pages.
  AppMenu: "菜单",
  "app_menu.dart#_Header": "菜单顶部（账户）",
  pickTheme: "外观",
  ShortcutList: "键盘快捷键",
  LanguageMenu: "语言",
  AppTitle: "标题",
  HeroBanner: "横幅",
  LeaveGuard: "离开前的确认",
  confirmRecalc: "同名重算的提示",
  showPointsShort: "积分不够时",
  PriceLine: "价格",
  ReportRequest: "AI 解读按钮",
  askInquiryGoal: "深度分析：想了解什么",
  VoiceInputButton: "语音输入",
  TermTipButton: "术语说明",
  ".topic": "解读各部分的名称",
  ".methodLabel": "方法的名称",
  ".tarotFocusLabel": "塔罗：看哪方面",
  ".pillar": "四柱的名称",
  ".conclusionPart": "总结各部分的名称",
  ".followUpStarters": "追问：建议的问题",
  topicLabel: "解读各部分的名称",
  relationLabel: "家人关系的名称",
  // 首页 and 欢迎页.
  MethodEntry: "方法入口",
  RecentHistory: "最近的记录",
  HistoryTile: "一条记录",
  DailyCard: "今日一牌卡片",
  EastDailyCard: "今日一卦 / 今日一签卡片",
  IntroLogo: "标志",
  // A reading and its parts.
  FourLayerReport: "解读正文",
  FollowUpCard: "追问",
  "follow_up.dart#_Turn": "一问一答",
  RemedyButton: "破除运势方案",
  RemedyDialog: "方案弹窗",
  "remedy.dart#_Actions": "方案的按钮",
  "report_page.dart#_header": "页头",
  ReadingChart: "命盘 / 牌 / 卦",
  "report_page.dart#_Generating": "生成中",
  "report_page.dart#_ReadingPillars": "四柱",
  HexagramCard: "卦象",
  TarotSpread: "牌阵",
  "tarot_spread.dart#_CardDialog": "放大的牌",
  TarotRitualSteps: "抽牌仪式",
  "tarot_glossary_page.dart#_CardMeaning": "牌义",
  LotCard: "签文",
  NamesCard: "候选名字",
  PrinciplesCard: "风水原则",
  "liuyao_page.dart#_Tosses": "摇卦",
  "liuyao_page.dart#_CoinGrid": "铜钱",
  "qiuqian_page.dart#_Rounds": "掷筊",
  JiaobeiBlocks: "筊杯",
  "inquiry_page.dart#_MasterBubble": "大师的问题",
  // 八字.
  "bazi_chart_page.dart#_PillarGrid": "四柱",
  "bazi_chart_page.dart#_DayunCard": "大运",
  "bazi_chart_page.dart#_yearStep": "流年",
  BirthFields: "出生资料",
  PlaceField: "出生地",
  LunarDatePicker: "农历日期",
  LunarPreview: "农历对照",
  ShichenPicker: "时辰",
  LifeContextFields: "个人背景",
  ProfileDialog: "存为谁排盘",
  startLifeReport: "一生运势报告",
  LifeHeader: "报告抬头",
  MeihuaTable: "梅花易数表",
  "life_report_page.dart#_Pending": "生成中",
  // Downloads, mail and print.
  recordDocument: "下载 / 发到邮箱的文件",
  readingDocumentOf: "解读的文件",
  readingHeadings: "文件里的标题",
  lifeReportDocument: "一生运势报告的文件",
  lifeReportHtml: "打印 / 网页版",
  lifeReportMarkdown: "Markdown 版",
  chooseFiling: "归类到…",
  confirmDelete: "删除前的确认",
  // 我的积分 and 收据.
  "points_page.dart#_EntryRow": "积分记录",
  pointsWhat: "记录的说明",
  "points_page.dart#_PackButton": "充值套餐",
  receiptLines: "收据明细",
  // 设置.
  accountProblem: "账号的错误提示",
  ContactDialog: "绑定邮箱 / 手机号",
  "settings_page.dart#_EmailReportsTile": "测算完成后发到邮箱",
  "contact_dialog.dart#_UsernameDialog": "改用户名",
  // 内容审核.
  "review_page.dart#_ReviewTile": "一条待审内容",
  kindLabel: "内容的类型",
};

/** A part's name: by its file and name first, then by its name if public; undefined for one passed over. */
export function partName(code: string, file = ""): string | undefined {
  const own = PARTS[`${file.split("/").at(-1)}#${code}`];
  return own ?? (code.startsWith("_") ? undefined : PARTS[code]);
}
