// 内容 by page (S33 WP33.2; the owner, 2026-10-31: 「以页面为基础展开所有当前页面用到的resource，这样integrator能够迅速查找
// 相关的页面进行更改 … 如果有显示是共同分享页，那么就展示多个逻辑同时用到的这个页面的方式 … 最终目的就是要明白自己改动的地方
// 到底改在哪里」): where each text and image shows, read from the app's code.
import { describe, expect, it } from "vitest";
import { contentTexts } from "../src/content/catalog.js";
import { PAGES, PARTS, partName } from "../src/content/pages.js";
import { appSources, declarationsOf, stripComments, usageOf } from "../src/content/usage.js";

const keys = new Set(contentTexts().map((t) => t.key));
const sources = appSources();
const usage = usageOf(sources, keys);
const pagesOf = (resource: string) => [...new Set(usage.places.get(resource)!.map((p) => p.page))];

describe("reading the app's code", () => {
  it("leaves strings alone when it takes the comments out, nested ones and ${…} too", () => {
    const src = [
      "// gone-1",
      "/// gone-2",
      "final a = 'http://x'; // gone-3",
      "/* gone-4 /* gone-5 */ gone-6 */ final b = 1;",
      "final c = '${l10n.homeTarot} // kept';",
      "final d = r'C:\\\\x' + '''three // quotes''';",
    ].join("\n");
    const out = stripComments(src);
    expect(out).not.toMatch(/gone/);
    expect(out).toContain("final a = 'http://x';");
    expect(out).toContain("final b = 1;");
    expect(out).toContain("'${l10n.homeTarot} // kept'");
    expect(out).toContain("'''three // quotes'''");
  });

  it("follows each page to what it uses, stops at other pages, and names the parts on the way", () => {
    const files = [
      {
        file: "presentation/a_page.dart",
        source: [
          "class APage extends StatelessWidget {",
          "  Widget build(BuildContext context) => Column(children: [Shared(), _Own(), Text(l10n.alpha)]);",
          "  void open() => push(BPage());",
          "}",
          "class _Own extends StatelessWidget {",
          "  Widget build(BuildContext context) => Text(l10n.topic('x'));",
          "}",
        ].join("\n"),
      },
      {
        file: "presentation/b_page.dart",
        source: [
          "class BPage extends StatelessWidget {",
          "  Widget build(BuildContext context) => Shared();",
          "}",
          "class _Own extends StatelessWidget {",
          "  Widget build(BuildContext context) => Text(l10n.gamma);",
          "}",
        ].join("\n"),
      },
      {
        file: "presentation/widgets/shared.dart",
        source: [
          "class Shared extends StatelessWidget {",
          "  Widget build(BuildContext context) => Text(l10n.beta);",
          "}",
        ].join("\n"),
      },
      {
        file: "presentation/labels.dart",
        source: [
          "extension ApiLabels on AppLocalizations {",
          "  String topic(String t) => switch (t) { 'x' => delta, _ => t };",
          "}",
        ].join("\n"),
      },
    ];
    const names: Record<string, string> = { Shared: "共用部件", ".topic": "名称" };
    const v = usageOf(
      files,
      new Set(["alpha", "beta", "gamma", "delta", "unused"]),
      (code) => names[code],
      { APage: "A", BPage: "B" },
    );
    expect(v.places.get("alpha")).toEqual([{ page: "APage", parts: [] }]);
    // A shared part: on both pages, by its name.
    expect(v.places.get("beta")).toEqual([
      { page: "APage", parts: ["共用部件"] },
      { page: "BPage", parts: ["共用部件"] },
    ]);
    // B's own _Own is not A's (a private name is its file's), and B's page is not walked from A.
    expect(v.places.get("gamma")).toEqual([]);
    // Bare inside the extension on AppLocalizations, reached through l10n.topic(…).
    expect(v.places.get("delta")).toEqual([{ page: "APage", parts: ["名称"] }]);
    expect(v.places.get("unused")).toEqual([]);
  });
});

describe("the app's own map", () => {
  it("names every page of the app, and every part it names is still in the code", () => {
    const classes = new Set(
      sources.flatMap((s) => [...s.source.matchAll(/^class ([A-Z]\w*Page)\b/gm)].map((m) => m[1]!)),
    );
    expect(
      [...classes].filter((c) => !(c in PAGES)),
      "pages without a name in pages.ts",
    ).toEqual([]);
    expect(Object.keys(PAGES).filter((p) => p !== "MingliApp" && !classes.has(p))).toEqual([]);
    const declared = new Set<string>();
    for (const { file, source } of sources) {
      for (const d of declarationsOf(source)) {
        declared.add(d.name).add(`${file.split("/").at(-1)}#${d.name}`);
      }
    }
    expect(
      Object.keys(PARTS).filter((p) => !declared.has(p)),
      "names in pages.ts the code no longer has",
    ).toEqual([]);
  });

  it("places every text the code uses: none is said to be unused when a page shows it", () => {
    const used = new Set(
      sources
        .flatMap((s) => [...s.source.matchAll(/\bl10n\.(\w+)/g)].map((m) => m[1]!))
        .filter((k) => keys.has(k)),
    );
    expect(used.size).toBeGreaterThan(600);
    expect([...used].filter((k) => usage.places.get(k)!.length === 0)).toEqual([]);
  });

  it("finds the pages a text shows on, and each way it gets there", () => {
    expect(pagesOf("introJoin")).toEqual(["IntroPage"]);
    expect(pagesOf("captchaRequired")).toEqual(["SignInPage"]);
    // The ☰ menu's texts on 首页, by the menu.
    expect(usage.places.get("adminDashboard")).toContainEqual({
      page: "HomePage",
      parts: ["☰ 菜单"],
    });
    // A shared part: the AI button's texts on every method's page.
    const methods = pagesOf("topicTarotCards");
    for (const page of ["TarotPage", "LiuyaoPage", "QiuqianPage", "ReportPage", "HistoryPage"]) {
      expect(methods, page).toContain(page);
    }
    expect(usage.places.get("topicTarotCards")).toContainEqual({
      page: "LiuyaoPage",
      parts: ["AI 解读按钮", "解读各部分的名称"],
    });
  });

  it("finds the images: the banner on the pages with one, the mark on 欢迎页", () => {
    expect(pagesOf("image:logo")).toEqual(["IntroPage"]);
    expect(pagesOf("image:banner")).toEqual(
      expect.arrayContaining(["HomePage", "SignInPage", "LiuyaoPage"]),
    );
    expect(partName("HeroBanner")).toBe("横幅");
  });
});
