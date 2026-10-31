// 内容管理 (S29; owner, 2026-10-30: 「create a CMS system, that can modify the resources of context for different places of
// the text, images; store the values of the resources into database; autherize the roles to be able to update the
// context of the page; extract as much text as possible into the content integration pages」).
import { randomBytes } from "node:crypto";
import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { MockProvider } from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import { InMemoryStore } from "../src/api/store.js";
import { contentTexts, looksLike, placeholdersOf } from "../src/content/catalog.js";
import { PgStore } from "../src/db/pg-store.js";
import { buildAuth } from "../src/service/runtime.js";
import { DRAW_KEY, PEPPER } from "./helpers.js";

/** The smallest PNG there is: one transparent pixel. */
const PNG = Buffer.from(
  "89504e470d0a1a0a0000000d4948445200000001000000010806000000" +
    "1f15c4890000000d4944415478da63fcff1f00030302ef69a3c90000000049454e44ae426082",
  "hex",
);

describe("what staff can change", () => {
  it("every text of the app's message files, plain or with placeholders, by area; a plural, a select or a formatted value left out", () => {
    const texts = contentTexts();
    expect(texts.length).toBeGreaterThan(300);
    const tarot = texts.find((t) => t.key === "homeTarot")!;
    expect(tarot).toMatchObject({ area: "home", placeholders: [] });
    expect(tarot.defaults["zh-Hans"]).not.toBe("");
    expect(tarot.defaults["zh-Hant"]).not.toBe("");
    expect(texts.find((t) => t.key === "pointsBalanceLine")?.placeholders).toEqual(["balance"]);
    expect(texts.every((t) => !/\{\s*\w+\s*,\s*(plural|select)/.test(t.defaults["zh-Hans"]))).toBe(
      true,
    );
    expect(new Set(texts.map((t) => t.key)).size).toBe(texts.length);
  });

  it("knows a placeholder and an image's signature", () => {
    expect(placeholdersOf("{name} 的 {name} 与 {year}")).toEqual(["name", "year"]);
    expect(looksLike("image/png", PNG)).toBe(true);
    expect(looksLike("image/jpeg", PNG)).toBe(false);
    expect(looksLike("image/webp", Buffer.from("RIFF0000WEBPVP8 ", "latin1"))).toBe(true);
  });
});

const secrets = { digestPepper: PEPPER, drawKey: DRAW_KEY };
const mock = new MockProvider();
const auth = buildAuth({ ...secrets, ephemeral: true } as never, true);
const api = createApiServer({
  secrets,
  providers: { deepseek: mock, anthropic: mock },
  auth,
  store: new InMemoryStore(),
  devMode: true,
  devHeaders: false,
  admins: ["boss"],
  now: () => new Date("2026-10-30T12:00:00.000Z"),
  log: () => {},
});
let base = "";
const tokens: Record<string, string> = {};

// The server and its sign-ins start right before the tests that call it (rule 81).
let started: Promise<void> | undefined;
const start = () =>
  (started ??= (async () => {
    for (const login of ["boss", "integ", "mgr", "alice"]) {
      await auth.seedDevUser({ login, password: login, country: "HK", locale: "zh-Hans" });
    }
    for (const [login, role] of [
      ["integ", "integrator"],
      ["mgr", "manager"],
    ] as const) {
      const u = (await auth.findLogin("username", login))!;
      await auth.users.put({ ...u, role });
    }
    await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
    base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
    for (const login of ["boss", "integ", "mgr", "alice"]) {
      const res = await fetch(base + "/v1/auth/login", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ login, password: login }),
      });
      tokens[login] = ((await res.json()) as { access_token: string }).access_token;
    }
  })());
afterAll(() => new Promise<void>((r) => api.close(() => r())));

const call = (
  who: string | null,
  path: string,
  method = "GET",
  body?: unknown,
  type = "application/json",
) =>
  fetch(base + path, {
    method,
    headers: {
      "content-type": type,
      ...(who && { authorization: `Bearer ${tokens[who]}` }),
    },
    ...(body !== undefined && {
      body: Buffer.isBuffer(body) ? new Uint8Array(body) : JSON.stringify(body),
    }),
  });

describe("the CMS's API", () => {
  beforeAll(start);

  it("is for the roles with content: an admin and an integrator; a manager is refused, a user is no staff", async () => {
    expect((await call("boss", "/v1/admin/content")).status).toBe(200);
    expect((await call("integ", "/v1/admin/content")).status).toBe(200);
    const mgr = await call("mgr", "/v1/admin/content");
    expect([mgr.status, ((await mgr.json()) as { code: string }).code]).toEqual([
      403,
      "not_allowed",
    ]);
    const user = await call("alice", "/v1/admin/content");
    expect([user.status, ((await user.json()) as { code: string }).code]).toEqual([
      403,
      "admin_only",
    ]);
  });

  it("lists every text with its defaults by area, and the images", async () => {
    const all = (await (await call("integ", "/v1/admin/content")).json()) as {
      locales: string[];
      texts: { key: string; area: string; defaults: Record<string, string>; changed: object }[];
      images: { key: string }[];
    };
    expect(all.locales).toEqual(["zh-Hans", "zh-Hant"]);
    expect(all.texts.length).toBe(contentTexts().length);
    expect(all.texts.find((t) => t.key === "homeTarot")).toMatchObject({
      area: "home",
      changed: {},
    });
    expect(all.images.map((i) => i.key)).toEqual(["banner", "logo"]);
  });

  it("changes a text in one language for everyone, signed in or not, and puts it back", async () => {
    const put = await call("integ", "/v1/admin/content/texts/homeTarot/zh-Hans", "PUT", {
      text: "  塔罗占卜  ",
    });
    expect(put.status).toBe(200);
    expect(await put.json()).toMatchObject({
      key: "homeTarot",
      locale: "zh-Hans",
      text: "塔罗占卜",
    });
    // The public read: the changes only, no sign-in.
    expect(await (await call(null, "/v1/content?locale=zh-Hans")).json()).toMatchObject({
      texts: { homeTarot: "塔罗占卜" },
    });
    expect(
      ((await (await call(null, "/v1/content?locale=zh-Hant")).json()) as { texts: object }).texts,
    ).toEqual({});
    const back = await call("boss", "/v1/admin/content/texts/homeTarot/zh-Hans", "DELETE");
    expect(((await back.json()) as { text: string }).text).toBe(
      contentTexts().find((t) => t.key === "homeTarot")!.defaults["zh-Hans"],
    );
    expect(
      ((await (await call(null, "/v1/content?locale=zh-Hans")).json()) as { texts: object }).texts,
    ).toEqual({});
  });

  it("keeps a text's placeholders, refuses an unknown text, an empty or too long one, and an unknown language", async () => {
    const lost = await call("integ", "/v1/admin/content/texts/pointsBalanceLine/zh-Hans", "PUT", {
      text: "余额",
    });
    expect([lost.status, ((await lost.json()) as { code: string }).code]).toEqual([
      400,
      "placeholders_mismatch",
    ]);
    const extra = await call("integ", "/v1/admin/content/texts/pointsBalanceLine/zh-Hans", "PUT", {
      text: "{balance} {more}",
    });
    expect(extra.status).toBe(400);
    expect(
      (
        await call("integ", "/v1/admin/content/texts/pointsBalanceLine/zh-Hans", "PUT", {
          text: "剩余 {balance} 积分",
        })
      ).status,
    ).toBe(200);
    expect(
      (await call("integ", "/v1/admin/content/texts/noSuchKey/zh-Hans", "PUT", { text: "x" }))
        .status,
    ).toBe(404);
    expect(
      (await call("integ", "/v1/admin/content/texts/homeTarot/zh-Hans", "PUT", { text: "   " }))
        .status,
    ).toBe(400);
    expect(
      (
        await call("integ", "/v1/admin/content/texts/homeTarot/zh-Hans", "PUT", {
          text: "长".repeat(2001),
        })
      ).status,
    ).toBe(400);
    expect(
      (await call("integ", "/v1/admin/content/texts/homeTarot/en", "PUT", { text: "x" })).status,
    ).toBe(404);
    expect((await call(null, "/v1/content?locale=en")).status).toBe(400);
  });

  it("puts an image in, serves it at an address of its version, and takes it out", async () => {
    const put = await call("integ", "/v1/admin/content/images/banner", "PUT", PNG, "image/png");
    expect(put.status).toBe(200);
    const { url } = (await put.json()) as { url: string };
    expect(url).toMatch(/^\/v1\/content\/images\/banner\?v=/);
    expect(
      ((await (await call(null, "/v1/content?locale=zh-Hant")).json()) as { images: object })
        .images,
    ).toEqual({ banner: url });
    const got = await call(null, url);
    expect(got.headers.get("content-type")).toBe("image/png");
    expect(got.headers.get("x-content-type-options")).toBe("nosniff");
    expect(got.headers.get("cache-control")).toContain("immutable");
    expect(Buffer.from(await got.arrayBuffer()).equals(PNG)).toBe(true);
    expect((await call("integ", "/v1/admin/content/images/banner", "DELETE")).status).toBe(200);
    expect((await call(null, "/v1/content/images/banner")).status).toBe(404);
  });

  it("refuses an image of another type, one that isn't what it says, one too large, and an unknown image", async () => {
    expect(
      (await call("integ", "/v1/admin/content/images/banner", "PUT", PNG, "image/gif")).status,
    ).toBe(415);
    expect(
      (
        await call(
          "integ",
          "/v1/admin/content/images/banner",
          "PUT",
          Buffer.from("not a picture"),
          "image/png",
        )
      ).status,
    ).toBe(400);
    const big = Buffer.concat([PNG, Buffer.alloc(2 * 1024 * 1024)]);
    expect(
      (await call("integ", "/v1/admin/content/images/banner", "PUT", big, "image/png")).status,
    ).toBe(413);
    expect(
      (await call("integ", "/v1/admin/content/images/poster", "PUT", PNG, "image/png")).status,
    ).toBe(404);
  });
});

describe("the database keeps them", () => {
  it(
    "a text and an image round-trip through PGlite, put back and taken out",
    { timeout: 30_000 },
    async () => {
      const pg = await PgStore.open({ kek: randomBytes(32), pepper: PEPPER });
      const at = "2026-10-30T12:00:00.000Z";
      await pg.putContentText({
        key: "homeTarot",
        locale: "zh-Hant",
        text: "塔羅",
        updated_at: at,
      });
      await pg.putContentText({
        key: "homeTarot",
        locale: "zh-Hant",
        text: "塔羅占卜",
        updated_at: at,
      });
      expect(await pg.listContentTexts()).toEqual([
        { key: "homeTarot", locale: "zh-Hant", text: "塔羅占卜", updated_at: at },
      ]);
      await pg.putContentImage({ key: "logo", type: "image/png", data: PNG, updated_at: at });
      expect(await pg.listContentImages()).toEqual([
        { key: "logo", type: "image/png", updated_at: at },
      ]);
      expect((await pg.getContentImage("logo"))!.data.equals(PNG)).toBe(true);
      expect(await pg.deleteContentText("homeTarot", "zh-Hant")).toBe(true);
      expect(await pg.deleteContentImage("logo")).toBe(true);
      expect([await pg.listContentTexts(), await pg.getContentImage("logo")]).toEqual([
        [],
        undefined,
      ]);
      await pg.close();
    },
  );
});
