/**
 * Copies single-source data from the server into the Flutter app, so the app
 * never keeps its own copy:
 *   app/assets/i18n/terms.json      ← i18n/terms.json (protected terms)
 *   app/assets/i18n/tarot_deck.json ← src/engines/tarot/deck.ts (78 card names)
 *   app/assets/i18n/term_tips.json  ← src/ai/term-tips.ts (what each 八字 term means)
 *   app/assets/i18n/qiuqian_lots.json ← data/qiuqian (求籤's lot set, v4.3.0)
 *   app/assets/i18n/fengshui.json   ← src/engines/fengshui/principles.ts (风水's rooms, v4.4.0)
 *   app/test/fixtures/*.json        ← real engine + pipeline (mock provider) outputs
 * test/app-assets.test.ts fails when these are stale. Run: npm run sync:app
 * (this module only builds; scripts/sync-app-assets.ts writes).
 */
import { readFileSync } from "node:fs";
import {
  generateLifeReport,
  generateRemedy,
  generateReport,
  MockProvider,
  NO_PLAN_TOPICS,
  TAROT_FOCUS,
  TOPICS_BY_SYSTEM,
} from "../src/ai/index.js";
import { lotTitle } from "../src/ai/qiuqian.js";
// Not through the ai index: the tips need OpenCC (a dev tool), which the server must not load.
import { termTips } from "../src/ai/term-tips.js";
import { LOCALES } from "../src/ai/terms.js";
import {
  publicLifeReport,
  publicRemedy,
  publicReport,
  REMEDY_PRICE,
  reviewSummary,
} from "../src/api/server.js";
import {
  computeBazi,
  lunarDate,
  lunarMonths,
  lunarToSolar,
  shichenOptions,
} from "../src/engines/bazi/index.js";
import {
  DECK,
  DECK_ID,
  POSITION_LABELS,
  POSITION_MEANINGS,
  SPREADS,
} from "../src/engines/tarot/deck.js";
import { KEYWORDS } from "../src/engines/tarot/keywords.js";
import { placeCountry, placeIndex } from "../src/places/index.js";
import { computeFengshui, PRINCIPLES_VERSION } from "../src/engines/fengshui/index.js";
import { DIRECTIONS, FACINGS, ROOM_IDS, ROOMS } from "../src/engines/fengshui/principles.js";
import { computeQiuqian } from "../src/engines/qiuqian/index.js";
import { lotSet } from "../src/engines/qiuqian/lots.js";
import { computeTarot } from "../src/engines/tarot/index.js";

const root = new URL("../", import.meta.url);
export const at = (p: string) => new URL(p, root);

/** Strings (generated source) are written as-is; everything else as pretty JSON. */
export const serialize = (data: unknown) =>
  typeof data === "string" ? data : JSON.stringify(data, null, 2) + "\n";

export async function buildAppAssets(): Promise<Record<string, unknown>> {
  const now = () => new Date("2026-10-25T00:00:00.000Z");
  const secrets = { digestPepper: Buffer.alloc(32, 7), drawKey: Buffer.alloc(32, 9) };
  const bazi = computeBazi(
    {
      local: "1990-03-15T14:30",
      timezone: "Asia/Hong_Kong",
      longitude: 114.17,
      gender: "male",
      options: { liunianFrom: 2026 },
    },
    // tzdb pinned: CI runners ship a different Node tzdb, which would change the digest.
    { digestPepper: secrets.digestPepper, now, tzdb: "fixture" },
  );
  const tarot = computeTarot(
    { spread: "three_card" },
    { ...secrets, now, newDrawId: () => "00000000-0000-4000-8000-000000000001" },
  );
  // The other two spreads, for the app's layout tests (Celtic Cross: cross + staff).
  const celtic = computeTarot(
    { spread: "celtic_cross" },
    { ...secrets, now, newDrawId: () => "00000000-0000-4000-8000-000000000002" },
  );
  const single = computeTarot(
    { spread: "single" },
    { ...secrets, now, newDrawId: () => "00000000-0000-4000-8000-000000000003" },
  );
  // The two spreads of v2.8.0, for their layout tests.
  const twoPaths = computeTarot(
    { spread: "two_paths" },
    { ...secrets, now, newDrawId: () => "00000000-0000-4000-8000-000000000004" },
  );
  const relationship = computeTarot(
    { spread: "relationship" },
    { ...secrets, now, newDrawId: () => "00000000-0000-4000-8000-000000000005" },
  );
  const mock = new MockProvider();
  const report = await generateReport(
    bazi,
    { locale: "zh-Hant", country: "HK" },
    {
      providers: { deepseek: mock, anthropic: mock },
      now,
      newId: () => "11111111-1111-4111-8111-111111111111",
    },
  );
  const ts = now().toISOString();
  const view = publicReport({
    id: report.report_id,
    owner: "fixture",
    chart_id: "22222222-2222-4222-8222-222222222222",
    status: report.status,
    locale: report.locale,
    topics: report.topics,
    created_at: ts,
    updated_at: ts,
    report,
  });
  // A tarot reading (v2.3.0): card by card, the whole spread and the advice, with a focus.
  const tarotReport = await generateReport(
    tarot,
    { locale: "zh-Hant", country: "HK", question: "這份工作還要繼續嗎？", focus: "career_wealth" },
    {
      providers: { deepseek: mock, anthropic: mock },
      now,
      newId: () => "55555555-5555-4555-8555-555555555555",
    },
  );
  const tarotView = publicReport({
    id: tarotReport.report_id,
    owner: "fixture",
    chart_id: "33333333-3333-4333-8333-333333333333", // chart_tarot.json, the draw it reads
    status: tarotReport.status,
    locale: tarotReport.locale,
    topics: tarotReport.topics,
    created_at: ts,
    updated_at: ts,
    report: tarotReport,
  });

  // A 求籤 draw and its reading (v4.3.0).
  const qiuqian = computeQiuqian(
    {},
    { ...secrets, now, newDrawId: () => "00000000-0000-4000-8000-000000000006" },
  );
  const qiuqianReport = await generateReport(
    qiuqian,
    { locale: "zh-Hant", country: "TW", question: "今年適合換工作嗎？" },
    {
      providers: { deepseek: mock, anthropic: mock },
      now,
      newId: () => "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
    },
  );
  const qiuqianView = publicReport({
    id: qiuqianReport.report_id,
    owner: "fixture",
    chart_id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd", // chart_qiuqian.json, the draw it reads
    status: qiuqianReport.status,
    locale: qiuqianReport.locale,
    topics: qiuqianReport.topics,
    created_at: ts,
    updated_at: ts,
    report: qiuqianReport,
  });
  const lots = lotSet("guandi_100");

  // A 风水 room and its reading (v4.4.0).
  const fengshui = computeFengshui(
    { room: "bedroom", facing: "east" },
    { digestPepper: secrets.digestPepper, now },
  );
  const fengshuiReport = await generateReport(
    fengshui,
    { locale: "zh-Hant", country: "MY", question: "床在窗下，門在床的左邊。" },
    {
      providers: { deepseek: mock, anthropic: mock },
      now,
      newId: () => "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee",
    },
  );
  const fengshuiView = publicReport({
    id: fengshuiReport.report_id,
    owner: "fixture",
    chart_id: "ffffffff-ffff-4fff-8fff-ffffffffffff", // chart_fengshui.json, the room it reads
    status: fengshuiReport.status,
    locale: fengshuiReport.locale,
    topics: fengshuiReport.topics,
    created_at: ts,
    updated_at: ts,
    report: fengshuiReport,
  });

  const remedy = await generateRemedy(
    bazi,
    report,
    "career_wealth",
    { country: "HK" },
    { providers: { deepseek: mock, anthropic: mock }, now },
  );
  const remedyView = publicRemedy({
    id: "44444444-4444-4444-8444-444444444444",
    owner: "fixture",
    report_id: report.report_id,
    topic: "career_wealth",
    status: remedy.status,
    created_at: ts,
    updated_at: ts,
    unlocked: true,
    payment: { status: "placeholder", ...REMEDY_PRICE },
    remedy,
  });

  // The owner's sample (吴勇, 1987-11-23 03:30, 靖江) as a 一生运势报告.
  const lifeChart = computeBazi(
    { local: "1987-11-23T03:30", timezone: "Asia/Shanghai", longitude: 120.2625, gender: "male" },
    { digestPepper: secrets.digestPepper, now, tzdb: "fixture" },
  );
  const life = await generateLifeReport(
    lifeChart,
    { locale: "zh-Hans", country: "HK" },
    { providers: { deepseek: mock, anthropic: mock }, now },
  );
  const lifeView = publicLifeReport({
    id: "55555555-5555-4555-8555-555555555555",
    owner: "fixture",
    chart_id: "66666666-6666-4666-8666-666666666666",
    status: life.status,
    locale: "zh-Hans",
    created_at: ts,
    updated_at: ts,
    life,
  });

  // A report the guard held, as the review console shows it (GET /v1/admin/reviews/report/{id}).
  const heldMock = new MockProvider({
    guard: [
      {
        kind: "ok",
        data: {
          pass: false,
          violations: [
            { quote: "（示範）月柱的十神常被用來談工作方式", category: "other", reason: "fixture" },
          ],
        },
      },
    ],
  });
  const held = await generateReport(
    bazi,
    { locale: "zh-Hant", country: "HK", topics: ["career_wealth"] },
    {
      providers: { deepseek: heldMock, anthropic: heldMock },
      now,
      newId: () => "77777777-7777-4777-8777-777777777777",
    },
  );
  const heldRecord = {
    id: held.report_id,
    owner: "fixture-owner",
    status: held.status,
    created_at: ts,
    updated_at: ts,
  };
  const reviewView = {
    ...reviewSummary("report", heldRecord, held, { locale: "zh-Hant", topics: held.topics }),
    content: held.held_layers,
  };

  return {
    "app/assets/i18n/terms.json": JSON.parse(readFileSync(at("i18n/terms.json"), "utf8")),
    "app/assets/i18n/tarot_deck.json": {
      deck_id: DECK_ID,
      cards: Object.fromEntries(DECK.map((c) => [c.id, c.name])),
      positions: POSITION_LABELS,
      position_meanings: POSITION_MEANINGS,
      // Each spread's positions in dealing order, so the picker can show them before a draw.
      spreads: SPREADS,
      // Each card's three keywords, as painted on the art (牌义图鉴, v2.7.0).
      keywords: KEYWORDS,
    },
    // Tapping a term on the 命盘 opens its plain explanation (v3.2.0).
    "app/assets/i18n/term_tips.json": { tips: termTips() },
    // 求籤's lot set (v4.3.0): every lot's title, label and poem in both scripts, for the lot card.
    "app/assets/i18n/qiuqian_lots.json": {
      id: lots.id,
      version: lots.version,
      name: lots.name,
      lots: lots.lots.map((l) => ({
        n: l.n,
        title: Object.fromEntries(LOCALES.map((loc) => [loc, lotTitle(l.n, loc)])),
        ganzhi: l.ganzhi,
        poem: l.poem,
      })),
    },
    "app/test/fixtures/chart_bazi.json": {
      chart_id: "22222222-2222-4222-8222-222222222222",
      chart_fact: bazi,
    },
    "app/test/fixtures/chart_tarot.json": {
      chart_id: "33333333-3333-4333-8333-333333333333",
      chart_fact: tarot,
    },
    "app/test/fixtures/chart_tarot_celtic.json": {
      chart_id: "88888888-8888-4888-8888-888888888888",
      chart_fact: celtic,
    },
    "app/test/fixtures/chart_tarot_single.json": {
      chart_id: "99999999-9999-4999-8999-999999999999",
      chart_fact: single,
    },
    "app/test/fixtures/chart_tarot_two_paths.json": {
      chart_id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      chart_fact: twoPaths,
    },
    "app/test/fixtures/chart_tarot_relationship.json": {
      chart_id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      chart_fact: relationship,
    },
    // 风水's rooms, principles and facings (v4.4.0), for the room page and the reading.
    "app/assets/i18n/fengshui.json": {
      version: PRINCIPLES_VERSION,
      rooms: Object.fromEntries(ROOM_IDS.map((id) => [id, ROOMS[id]])),
      facings: Object.fromEntries(FACINGS.map((f) => [f, DIRECTIONS[f]])),
    },
    "app/test/fixtures/chart_fengshui.json": {
      chart_id: "ffffffff-ffff-4fff-8fff-ffffffffffff",
      chart_fact: fengshui,
    },
    "app/test/fixtures/report_fengshui_passed.json": fengshuiView,
    "app/test/fixtures/chart_qiuqian.json": {
      chart_id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
      chart_fact: qiuqian,
    },
    "app/test/fixtures/report_passed.json": view,
    "app/test/fixtures/report_tarot_passed.json": tarotView,
    "app/test/fixtures/report_qiuqian_passed.json": qiuqianView,
    "app/test/fixtures/remedy_passed.json": remedyView,
    "app/test/fixtures/life_passed.json": lifeView,
    "app/test/fixtures/review_report.json": reviewView,
    "app/test/fixtures/chart_life.json": {
      chart_id: "66666666-6666-4666-8666-666666666666",
      chart_fact: lifeChart,
    },
    // Birthplace data for the fake API: four countries; CN trimmed to 廣東.
    "app/test/fixtures/places.json": {
      index: {
        ...placeIndex(),
        countries: placeIndex().countries.filter((c) => ["CN", "HK", "TW", "US"].includes(c.code)),
      },
      countries: {
        CN: {
          country: "CN",
          regions: placeCountry("CN")!
            .regions.filter((r) => r.names.en === "Guangdong")
            .map((r) => ({ ...r, cities: r.cities.slice(0, 8) })),
        },
        HK: placeCountry("HK"),
      },
    },
    // Real calendar data for the fake API: one day, its 農曆 year, and 農曆 → 公曆 lookups.
    "app/test/fixtures/calendar.json": {
      day: { lunar: lunarDate(1990, 3, 15), shichen: shichenOptions(1990, 3, 15) },
      months: { "1990": lunarMonths(1990), "2023": lunarMonths(2023) },
      solar: Object.fromEntries(
        [1990, 2023].flatMap((y) =>
          lunarMonths(y).flatMap((m) =>
            [1, 19].map((d) => [
              `${y}-${m.month}-${d}-${m.is_leap}`,
              lunarToSolar(y, m.month, d, m.is_leap),
            ]),
          ),
        ),
      ),
    },
    "app/lib/generated/contract.g.dart": [
      "// GENERATED by `npm run sync:app` from src/ai/types.ts. Do not edit.",
      "",
      "/// Topics each chart system supports (TOPICS_BY_SYSTEM on the server).",
      "const topicsBySystem = <String, List<String>>{",
      ...Object.entries(TOPICS_BY_SYSTEM).map(
        ([sys, ts]) => `  '${sys}': [${ts.map((t) => `'${t}'`).join(", ")}],`,
      ),
      "};",
      "",
      "/// Sections that get no 破除運勢 plan (NO_PLAN_TOPICS on the server).",
      `const noPlanTopics = <String>{${NO_PLAN_TOPICS.map((t) => `'${t}'`).join(", ")}};`,
      "",
      "/// The areas of life a tarot reading may focus on (TAROT_FOCUS on the server).",
      `const tarotFocus = <String>[${TAROT_FOCUS.map((t) => `'${t}'`).join(", ")}];`,
      "",
    ].join("\n"),
  };
}
