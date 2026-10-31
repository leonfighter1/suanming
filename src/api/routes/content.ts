/**
 * 内容管理 (S29): what staff changed of the app's texts and images, for everyone, signed in or not (the introduction and
 * sign-in pages read it too). Only the changes go out: the app has its own texts and pictures for everything else.
 */
import type { IncomingMessage, ServerResponse } from "node:http";
import {
  CONTENT_LOCALES,
  contentImageUrl,
  contentText,
  isContentImage,
  type ContentLocale,
} from "../../content/catalog.js";
import { HttpError, send } from "../../http/util.js";
import { InputError } from "../../service/charts.js";
import type { ApiContext } from "../context.js";

/** A language's changed texts and the images put in; one image's bytes. False for any other path. */
export async function contentRoute(
  ctx: ApiContext,
  req: IncomingMessage,
  res: ServerResponse,
  path: string,
): Promise<boolean> {
  if (req.method !== "GET") return false;
  if (path === "/v1/content") {
    const locale = new URL(req.url ?? "/", "http://localhost").searchParams.get("locale") ?? "";
    if (!(CONTENT_LOCALES as readonly string[]).includes(locale)) {
      throw new InputError(`locale must be one of ${CONTENT_LOCALES.join(", ")}`);
    }
    const texts = Object.fromEntries(
      (await ctx.store.listContentTexts())
        .filter((t) => t.locale === (locale as ContentLocale) && contentText(t.key))
        .map((t) => [t.key, t.text]),
    );
    const images = Object.fromEntries(
      (await ctx.store.listContentImages())
        .filter((i) => isContentImage(i.key))
        .map((i) => [i.key, contentImageUrl(i.key, i.updated_at)]),
    );
    send(res, 200, { texts, images }, { "cache-control": "no-cache" });
    return true;
  }
  const m = /^\/v1\/content\/images\/([a-z]+)$/.exec(path);
  if (m) {
    const image = isContentImage(m[1]!) ? await ctx.store.getContentImage(m[1]!) : undefined;
    if (!image) throw new HttpError(404, "no such image");
    res.writeHead(200, {
      "content-type": image.type,
      "content-length": String(image.data.length),
      "x-content-type-options": "nosniff",
      // Each version has its own address (?v=), so this one never changes.
      "cache-control": "public, max-age=31536000, immutable",
    });
    res.end(image.data);
    return true;
  }
  return false;
}
