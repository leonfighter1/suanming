// 内容管理 (S29; owner, 2026-10-30: 「create a CMS system, that can modify the resources of context for different places of
// the text, images; store the values of the resources into database; autherize the roles to be able to update the
// context of the page; extract as much text as possible into the content integration pages」).
import { randomBytes } from "node:crypto";
import { beforeAll, describe, expect, it } from "vitest";
import { InMemoryStore } from "../src/api/store.js";
import { contentTexts, looksLike, placeholdersOf } from "../src/content/catalog.js";
import { PgStore } from "../src/db/pg-store.js";
import { buildAuth } from "../src/service/runtime.js";
import { staffApi } from "./api.js";
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

const auth = buildAuth({ digestPepper: PEPPER, drawKey: DRAW_KEY, ephemeral: true } as never, true);
// The server and its sign-ins start right before the tests that call it (rule 81).
const { start, call } = staffApi(
  {
    auth,
    store: new InMemoryStore(),
    admins: ["boss"],
    now: () => new Date("2026-10-30T12:00:00.000Z"),
  },
  ["boss", "integ", "mgr", "alice"],
  { integ: "integrator", mgr: "manager" },
);

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
      image_types: string[];
      image_max_bytes: number;
      texts: { key: string; area: string; defaults: Record<string, string>; changed: object }[];
      images: { key: string }[];
    };
    expect(all.locales).toEqual(["zh-Hans", "zh-Hant"]);
    expect([all.image_types, all.image_max_bytes]).toEqual([
      ["image/png", "image/jpeg", "image/webp"],
      2 * 1024 * 1024,
    ]);
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
    const tooLarge = await call(
      "integ",
      "/v1/admin/content/images/banner",
      "PUT",
      big,
      "image/png",
    );
    expect(tooLarge.status).toBe(413);
    // The rest of the body is left unread: the connection closes, so no later request waits behind it.
    expect(tooLarge.headers.get("connection")).toBe("close");
    expect(
      (await call("integ", "/v1/admin/content/images/poster", "PUT", PNG, "image/png")).status,
    ).toBe(404);
  });

  it("takes a text's length and an image's size from 设置, from the next request (S32 WP32.4)", async () => {
    const put = (key: string, value: number) =>
      call("boss", `/v1/admin/settings/${key}`, "PUT", { value });
    await put("content.text_max", 50);
    await put("content.image_max_mb", 0.1);
    try {
      const listing = (await (await call("integ", "/v1/admin/content")).json()) as {
        image_max_bytes: number;
      };
      expect(listing.image_max_bytes).toBe(Math.round(0.1 * 1024 * 1024));
      const text = (n: number) =>
        call("integ", "/v1/admin/content/texts/homeTarot/zh-Hans", "PUT", { text: "塔".repeat(n) });
      expect((await text(51)).status).toBe(400);
      expect((await text(50)).status).toBe(200);
      const image = (bytes: number) =>
        call(
          "integ",
          "/v1/admin/content/images/banner",
          "PUT",
          Buffer.concat([PNG, Buffer.alloc(bytes)]),
          "image/png",
        );
      expect((await image(200 * 1024)).status).toBe(413);
      expect((await image(50 * 1024)).status).toBe(200);
    } finally {
      for (const key of ["content.text_max", "content.image_max_mb"])
        await call("boss", `/v1/admin/settings/${key}`, "DELETE");
      await call("integ", "/v1/admin/content/texts/homeTarot/zh-Hans", "DELETE");
      await call("integ", "/v1/admin/content/images/banner", "DELETE");
    }
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
