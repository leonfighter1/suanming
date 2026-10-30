import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { MockProvider } from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import { buildAuth } from "../src/service/runtime.js";
import { DRAW_KEY, PEPPER } from "./helpers.js";

// Guard verdicts in call order: the narrative report is held, the second passes.
const held = {
  kind: "ok" as const,
  data: {
    pass: false,
    violations: [{ quote: "你今年一定发财。", category: "fatalism", reason: "certainty" }],
  },
};
// A narrative that the rule layer blocks twice (G003: 注定…失去).
const blocking = {
  kind: "ok" as const,
  data: {
    sections: [
      {
        topic: "tarot_advice",
        summary: "x",
        paragraphs: [
          { text: "你注定会失去健康。", source_level: "derived", fact_refs: ["/cards/0"] },
        ],
      },
    ],
  },
};

const secrets = { digestPepper: PEPPER, drawKey: DRAW_KEY };
const mock = new MockProvider({ guard: [held], narrative: [] });
const auth = buildAuth({ ...secrets, ephemeral: true } as never, true);
const api = createApiServer({
  secrets,
  providers: { deepseek: mock, anthropic: mock },
  auth,
  devMode: true,
  devHeaders: false,
  preloadRemedies: false,
  admins: ["boss"],
  log: () => {},
});
let base = "";
const tokens: Record<string, string> = {};
beforeAll(async () => {
  for (const login of ["boss", "user1"]) {
    await auth.seedDevUser({ login, password: login, country: "HK", locale: "zh-Hans" });
  }
  await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
  base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
  for (const login of ["boss", "user1"]) {
    const t = await (
      await fetch(base + "/v1/auth/login", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email: login, password: login }),
      })
    ).json();
    tokens[login] = t.access_token;
  }
});
afterAll(() => new Promise<void>((r) => api.close(() => r())));

const call = (who: string, path: string, body?: unknown) =>
  fetch(base + path, {
    method: body === undefined ? "GET" : "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${tokens[who]}` },
    body: body === undefined ? undefined : JSON.stringify(body),
  });

async function tarotReport(who: string) {
  const { chart_id } = await (
    await call(who, "/v1/charts", {
      system: "tarot",
      spread: "three_card",
      question: "最近的工作会顺利吗？",
    })
  ).json();
  const r = await (
    await call(who, "/v1/reports", { chart_id, locale: "zh-Hans", topics: ["tarot_advice"] })
  ).json();
  await api.drain();
  return r.report_id as string;
}

describe("内容审核 (review console)", () => {
  it("/v1/me tells the app who reviews", async () => {
    expect((await (await call("boss", "/v1/me")).json()).role).toBe("admin");
    expect((await (await call("user1", "/v1/me")).json()).role).toBe("user");
  });

  it("only reviewers may open the console", async () => {
    expect((await call("user1", "/v1/admin/reviews")).status).toBe(403);
  });

  it("a held report: the user sees the hold message; the reviewer sees why and the content, then releases it", async () => {
    const id = await tarotReport("user1");
    const mine = await (await call("user1", `/v1/reports/${id}`)).json();
    expect(mine.status).toBe("manual_review");
    expect(mine.layers).toBeUndefined();

    const list = await (await call("boss", "/v1/admin/reviews")).json();
    const item = list.items.find((x: { id: string }) => x.id === id);
    expect(item).toMatchObject({
      kind: "report",
      status: "manual_review",
      topics: ["tarot_advice"],
    });
    expect(item.guard).toEqual([
      { quote: "你今年一定发财。", category: "fatalism", reason: "certainty" },
    ]);
    expect(item.owner).toHaveLength(8); // a short id, never the account

    const detail = await (await call("boss", `/v1/admin/reviews/report/${id}`)).json();
    expect(detail.content.interpretation[0].topic).toBe("tarot_advice");

    const released = await call("boss", `/v1/admin/reviews/report/${id}`, {
      decision: "approve",
      note: "表述可接受",
    });
    expect(released.status).toBe(200);
    expect((await released.json()).decision).toMatchObject({
      decision: "approve",
      by: "boss",
      note: "表述可接受",
    });

    const now = await (await call("user1", `/v1/reports/${id}`)).json();
    expect(now.status).toBe("passed");
    expect(now.layers.interpretation[0].topic).toBe("tarot_advice");
    // Released items leave the queue.
    expect(
      (await (await call("boss", "/v1/admin/reviews")).json()).items.some(
        (x: { id: string }) => x.id === id,
      ),
    ).toBe(false);
  });

  it("a rule-layer block can be read and rejected, never released", async () => {
    // Narrative blocked twice by G003; the guard is never called.
    (mock as unknown as { script: Record<string, unknown[]> }).script.narrative = [
      blocking,
      blocking,
    ];
    const id = await tarotReport("user1");
    const detail = await (await call("boss", `/v1/admin/reviews/report/${id}`)).json();
    expect(detail.status).toBe("blocked");
    expect(detail.rule_hits.map((h: { rule_id: string }) => h.rule_id)).toContain("G003");
    expect(detail.content.interpretation[0].paragraphs[0].text).toBe("你注定会失去健康。");

    expect(
      (await call("boss", `/v1/admin/reviews/report/${id}`, { decision: "approve" })).status,
    ).toBe(409);
    const rej = await call("boss", `/v1/admin/reviews/report/${id}`, {
      decision: "reject",
      note: "宿命论",
    });
    expect((await rej.json()).decision.decision).toBe("reject");
    expect((await (await call("user1", `/v1/reports/${id}`)).json()).layers).toBeUndefined();
  });

  it("a held 追问: the user sees the hold message; the reviewer reads it and releases it (v7.0.0)", async () => {
    const id = await tarotReport("user1"); // the guard queue is empty: the reading passes
    expect((await (await call("user1", `/v1/reports/${id}`)).json()).status).toBe("passed");
    (mock as unknown as { script: Record<string, unknown[]> }).script.guard = [held];
    const asked = await (
      await call("user1", `/v1/reports/${id}/followups`, {
        question: "这组牌对我的工作意味着什么？",
      })
    ).json();
    await api.drain();
    const mine = await (await call("user1", `/v1/followups/${asked.followup_id}`)).json();
    expect(mine.status).toBe("manual_review");
    expect(mine).not.toHaveProperty("answer");

    const list = await (await call("boss", "/v1/admin/reviews")).json();
    expect(list.items.find((x: { id: string }) => x.id === asked.followup_id)).toMatchObject({
      kind: "followup",
      status: "manual_review",
      parent: { kind: "report", id },
    });
    const path = `/v1/admin/reviews/followup/${asked.followup_id}`;
    const detail = await (await call("boss", path)).json();
    expect(detail.content.paragraphs.length).toBeGreaterThan(0);
    expect((await call("boss", path, { decision: "approve" })).status).toBe(200);
    const now = await (await call("user1", `/v1/followups/${asked.followup_id}`)).json();
    expect(now.status).toBe("passed");
    expect(now.answer.paragraphs).toEqual(detail.content.paragraphs);
  });
});
