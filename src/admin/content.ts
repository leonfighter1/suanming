/**
 * 内容管理 (S29) for staff with the content capability (roles.ts: admin and integrator): every text the app shows, with
 * the pages it shows on (S33, read from the app's code: usage.ts), its defaults and any change; a text changed
 * (keeping its placeholders) or put back to its default; an image put in or taken out. The app reads the changes
 * through /v1/content (src/api/routes/content.ts).
 */
import type { IncomingMessage, ServerResponse } from "node:http";
import type { UserRecord } from "../auth/service.js";
import {
  CONTENT_IMAGE_TYPES,
  CONTENT_IMAGES,
  CONTENT_LOCALES,
  contentImageUrl,
  contentText,
  contentTexts,
  isContentImage,
  looksLike,
  placeholdersOf,
  type ContentLocale,
} from "../content/catalog.js";
import { PAGES } from "../content/pages.js";
import { hasMarkup, richProblem } from "../content/rich.js";
import { appUsage } from "../content/usage.js";
import { HttpError, readBody, readJson, send } from "../http/util.js";
import type { AdminContext } from "./routes.js";
import { loginOf } from "./stats.js";

/** What 内容管理 takes now (设置, S32): a text's characters, an image's bytes. */
const limits = (ctx: AdminContext) => ({
  text: ctx.settings.number("content.text_max"),
  imageBytes: Math.round(ctx.settings.number("content.image_max_mb") * 1024 * 1024),
});

/** The CMS's routes; false for any other path. */
export async function contentAdminRoute(
  ctx: AdminContext,
  req: IncomingMessage,
  res: ServerResponse,
  path: string,
  me: UserRecord,
): Promise<boolean> {
  if (path === "/v1/admin/content" && req.method === "GET") {
    const changed = await ctx.store.listContentTexts();
    const images = await ctx.store.listContentImages();
    const texts = contentTexts();
    // Where each shows (S33): the pages that reach it in the app's code, and the parts on the way; and the texts that
    // may hold HTML (shown through ContentText).
    const { places, rich } = appUsage(new Set(texts.map((t) => t.key)));
    send(res, 200, {
      locales: CONTENT_LOCALES,
      // What an image may be, for the dashboard to say before one is picked.
      image_types: CONTENT_IMAGE_TYPES,
      image_max_bytes: limits(ctx).imageBytes,
      pages: Object.entries(PAGES).map(([id, name]) => ({ id, name })),
      texts: texts.map((t) => ({
        ...t,
        places: places.get(t.key) ?? [],
        ...(rich.has(t.key) && { rich: true }),
        changed: Object.fromEntries(
          changed
            .filter((c) => c.key === t.key)
            .map((c) => [c.locale, { text: c.text, updated_at: c.updated_at }]),
        ),
      })),
      images: CONTENT_IMAGES.map((i) => {
        const put = images.find((x) => x.key === i.key);
        return {
          ...i,
          places: places.get(`image:${i.key}`) ?? [],
          ...(put && { url: contentImageUrl(i.key, put.updated_at), updated_at: put.updated_at }),
        };
      }),
    });
    return true;
  }

  const text = /^\/v1\/admin\/content\/texts\/([A-Za-z0-9_]+)\/(zh-Hans|zh-Hant)$/.exec(path);
  if (text) {
    const key = text[1]!;
    const locale = text[2] as ContentLocale;
    const known = contentText(key);
    if (!known) throw new HttpError(404, "no such text", "unknown_text");
    if (req.method === "PUT") {
      const body = (await readJson(req)) as Record<string, unknown>;
      const value = typeof body.text === "string" ? body.text.trim() : "";
      if (!value) throw new HttpError(400, "text is required");
      const most = limits(ctx).text;
      if ([...value].length > most) {
        throw new HttpError(400, `text must be at most ${most} characters`);
      }
      // The app fills its placeholders in: a text without one, or with one it doesn't know, would show wrong.
      const want = [...known.placeholders].sort().join();
      if (placeholdersOf(value).sort().join() !== want) {
        throw new HttpError(
          400,
          `the text must keep its placeholders and add none: ${known.placeholders.map((p) => `{${p}}`).join(" ") || "none"}`,
          "placeholders_mismatch",
          { placeholders: known.placeholders },
        );
      }
      // HTML and CSS (S33) where the app shows the text as content; elsewhere words alone.
      if (hasMarkup(value)) {
        const keys = new Set(contentTexts().map((t) => t.key));
        if (!appUsage(keys).rich.has(key)) {
          throw new HttpError(400, "这段文字在应用里只显示纯文字，不能用 HTML", "rich_unsupported");
        }
        const problem = richProblem(value);
        if (problem) throw new HttpError(400, problem, "rich_invalid");
      }
      const at = ctx.now().toISOString();
      await ctx.store.putContentText({ key, locale, text: value, updated_at: at, updated_by: me.id });
      ctx.log(`content text ${key} (${locale}) changed by ${loginOf(me)}`);
      send(res, 200, { key, locale, text: value, updated_at: at });
      return true;
    }
    if (req.method === "DELETE") {
      await ctx.store.deleteContentText(key, locale);
      ctx.log(`content text ${key} (${locale}) put back by ${loginOf(me)}`);
      send(res, 200, { key, locale, text: known.defaults[locale] });
      return true;
    }
    throw new HttpError(405, "method not allowed");
  }

  const image = /^\/v1\/admin\/content\/images\/([a-z]+)$/.exec(path);
  if (image) {
    const key = image[1]!;
    if (!isContentImage(key)) throw new HttpError(404, "no such image", "unknown_image");
    if (req.method === "PUT") {
      const type = String(req.headers["content-type"] ?? "")
        .split(";")[0]!
        .trim()
        .toLowerCase();
      if (!(CONTENT_IMAGE_TYPES as readonly string[]).includes(type)) {
        throw new HttpError(415, `an image is ${CONTENT_IMAGE_TYPES.join(", ")}`, "image_type");
      }
      const data = await readBody(req, limits(ctx).imageBytes);
      if (!looksLike(type, data)) throw new HttpError(400, `this is not a ${type} picture`, "image_type");
      const at = ctx.now().toISOString();
      await ctx.store.putContentImage({ key, type, data, updated_at: at, updated_by: me.id });
      ctx.log(`content image ${key} put in by ${loginOf(me)}`);
      send(res, 200, { key, url: contentImageUrl(key, at), updated_at: at });
      return true;
    }
    if (req.method === "DELETE") {
      await ctx.store.deleteContentImage(key);
      ctx.log(`content image ${key} taken out by ${loginOf(me)}`);
      send(res, 200, { key });
      return true;
    }
    throw new HttpError(405, "method not allowed");
  }
  return false;
}
