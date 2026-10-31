// HTML and CSS in 内容 (S33 WP33.4; the owner, 2026-10-31: 「同时可以让当前的改动支持HTML和CSS，不仅仅只是resource」): the
// subset a text may hold where the app shows it as content, checked in the panel's words.
import { describe, expect, it } from "vitest";
import { contentTexts } from "../src/content/catalog.js";
import { hasMarkup, richProblem } from "../src/content/rich.js";
import { appSources, usageOf } from "../src/content/usage.js";

describe("the subset", () => {
  it("takes the tags, the theme's colours and the styles the app shows", () => {
    for (const ok of [
      "<b>八字</b>排盘",
      "<strong>粗</strong><i>斜</i><em>强调</em><u>下划线</u><s>删除</s><small>小字</small>",
      "第一行<br>第二行<br/>",
      "<p>一段</p><p>两段</p>",
      "<ul><li>一</li><li>二</li></ul><ol><li>甲</li></ol>",
      '<span style="color: var(--accent); background-color: var(--accent-soft)">主题色</span>',
      '<span style="font-weight: 700; font-style: italic; font-size: 18px; text-decoration: underline">样式</span>',
      '<a href="https://example.com">链接</a> 和 <a href="mailto:a@example.com">邮件</a>',
      "余额 {balance} 积分 &amp; &lt;说明&gt; &#21313;",
    ]) {
      expect(richProblem(ok), ok).toBeUndefined();
    }
  });

  it("says what is wrong, in the panel's words", () => {
    expect(richProblem("<script>x</script>")).toMatch(/^不支持的标签：<script>/);
    expect(richProblem("<div>x</div>")).toMatch(/^不支持的标签：<div>/);
    expect(richProblem('<span style="color: #ff0000">红</span>')).toMatch(/^color 要用主题色/);
    expect(richProblem('<span style="color: var(--purple)">紫</span>')).toMatch(
      /^color 要用主题色/,
    );
    expect(richProblem('<span style="font-size: 64px">大</span>')).toBe(
      "font-size 要在 11px 到 32px 之间",
    );
    expect(richProblem('<span style="position: fixed">x</span>')).toMatch(
      /^不支持的样式：position/,
    );
    expect(richProblem('<span onclick="x()">x</span>')).toBe(
      "<span> 不能有 onclick（只能有 style）",
    );
    expect(richProblem('<a href="javascript:alert(1)">x</a>')).toBe(
      "链接要以 https://、http:// 或 mailto: 开头",
    );
    expect(richProblem("<a>x</a>")).toBe("<a> 要有 href");
    expect(richProblem("<b><i>x</b></i>")).toBe("</b> 之前要先关上 <i>");
    expect(richProblem("<b>x")).toBe("<b> 没有关上");
    expect(richProblem("x</b>")).toBe("</b> 没有对应的 <b>");
    expect(richProblem("<b>1 < 2</b>")).toBe("「<」要写成 &lt;");
    expect(richProblem("<b>x</b>&copy;")).toBe("不认识的字符代码：&copy;");
  });

  it("tells HTML from words: a tag or an entity", () => {
    expect([
      hasMarkup("1 < 2 > 0"),
      hasMarkup("A & B"),
      hasMarkup("<b>x</b>"),
      hasMarkup("&amp;"),
    ]).toEqual([false, false, true, true]);
  });

  it("is where the app shows a text as content: every ContentText name", () => {
    const keys = new Set(contentTexts().map((t) => t.key));
    expect([...usageOf(appSources(), keys).rich].sort()).toEqual(
      [
        "introJoin",
        "introServicesHint",
        "homeBaziDesc",
        "homeTarotDesc",
        "homeFengshuiDesc",
        "homeQiuqianDesc",
        "homeLiuyaoDesc",
        "pointsHow",
        "pointsTopUpSimulated",
        "pointsTopUpUnavailable",
        "historyEmpty",
        "receiptsEmpty",
        "reviewEmpty",
        // S34: the notes, hints and descriptions shown in a body or reading style.
        "dayunTapHint",
        "profileHint",
        "inquiryAskingNote",
        "lifeTook",
        "lifeHint",
        "liuyaoQuestionMissing",
        "liuyaoTimeMissing",
        "placeSource",
        "receiptsAbout",
        "receiptSimulated",
        "qiuqianHowTo",
        "qiuqianQuestionMissing",
        "qiuqianTextNote",
        "generatingHint",
        "reviewHint",
        "tarotQuestionMissing",
        "shichenNote",
        "outboxNotice",
        "followUpIntro",
        "fengshuiNote",
        "remedyDesc",
        "tarotSections",
        "qiuqianSections",
        "fengshuiSections",
        "liuyaoSections",
        "namingSections",
        "disclaimerShort",
        "trendTapHint",
      ].sort(),
    );
  });
});
