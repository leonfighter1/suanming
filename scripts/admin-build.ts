/**
 * npm run admin:build → the 管理后台 (admin/, tech plan S22) built for the web into admin/build/served, which the API
 * serves at /admin/ (npm run api). Its API is the page's own server then, so nothing needs configuring.
 *
 * - Its own folder: the harness's check builds admin/build/web for "/", which would not run at /admin/.
 * - Flutter tooling needs an ASCII path on this machine (CLAUDE.md rule 7): the build runs through a junction to the
 *   repository root (the dashboard needs ../app beside it), removed afterwards. Flutter records a build's files by
 *   the path it used and deletes them as stale from a later build through another path: through a junction still
 *   there, those are this build's own files (MISTAKES rule 23). So the record goes first and the junction after.
 * - CanvasKit comes from the build itself, not Google's CDN, so the dashboard also opens without the internet.
 */
import { execFileSync } from "node:child_process";
import { existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const win = process.platform === "win32";
const out = join(root, "admin", "build", "served");

// Real paths only: never delete through a junction.
rmSync(join(root, "admin", ".dart_tool", "flutter_build"), { recursive: true, force: true });
rmSync(out, { recursive: true, force: true });

let base = root;
let junction: string | undefined;
if (win && /[^\x00-\x7F]/.test(root)) {
  junction = join(tmpdir(), `mingli-admin-${process.pid}`);
  execFileSync("cmd.exe", ["/d", "/c", "mklink", "/J", junction, root], { stdio: "ignore" });
  base = junction;
}
const flutter = win ? "flutter.bat" : "flutter";
const run = (args: string[]) =>
  execFileSync(flutter, args, { cwd: join(base, "admin"), stdio: "inherit", shell: win });

console.log("building the 管理后台 for /admin/ …");
try {
  run(["pub", "get"]);
  run([
    "build",
    "web",
    "--release",
    "--base-href",
    "/admin/",
    "--no-web-resources-cdn",
    "--output",
    join(base, "admin", "build", "served"),
  ]);
} finally {
  // rmdir takes the link only, never what it points at.
  if (junction) execFileSync("cmd.exe", ["/d", "/c", "rmdir", junction]);
}

const missing = [
  "index.html",
  "main.dart.js",
  "flutter.js",
  "flutter_bootstrap.js",
  "favicon.png",
  "manifest.json",
  join("canvaskit", "canvaskit.wasm"),
].filter((f) => !existsSync(join(out, f)));
if (missing.length) {
  console.error(`the build lacks ${missing.join(", ")}: run npm run admin:build again`);
  process.exit(1);
}
console.log(`built ${out}: npm run api serves it at http://127.0.0.1:8787/admin/`);
