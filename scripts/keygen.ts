/**
 * npm run keygen: prints fresh secrets for .env, to keep readings and accounts across restarts
 * (MINGLI_STORE=pglite, docs/web-test.md). It writes nothing: copy the lines you need into .env.
 * Keep MINGLI_DATA_KEY safe and backed up: without it the stored data can't be read.
 */
import { randomBytes } from "node:crypto";

const hex = () => randomBytes(32).toString("hex");
console.log(
  [
    "# Paste into .env (git-ignored). Never commit these.",
    "MINGLI_STORE=pglite",
    `MINGLI_DATA_KEY=${randomBytes(32).toString("base64")}`,
    `MINGLI_DIGEST_PEPPER=${hex()}`,
    `MINGLI_TAROT_DRAW_KEY=${hex()}`,
    `MINGLI_JWT_SECRET=${hex()}`,
  ].join("\n"),
);
