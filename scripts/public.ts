/**
 * npm run public  → the app on a public https URL, for testing from anywhere.
 *
 *   1. builds the web app with API_BASE_URL=origin (app and API share the URL);
 *   2. starts the API in --public mode on 127.0.0.1:8787 (serves the app too);
 *   3. opens a Cloudflare quick tunnel to it and prints https://….trycloudflare.com.
 *
 * Runs on this computer: testers reach it while this command runs. The URL changes
 * each time. Flags: --skip-build (reuse app/build/web). See docs/web-test.md.
 */
import { execFileSync, spawn, type ChildProcess } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const win = process.platform === "win32";
const port = Number(process.env.PORT ?? 8787);

/** Flutter tooling needs an ASCII path on this machine (CLAUDE.md rule 7). */
function buildWeb() {
  let appDir = join(root, "app");
  let junction: string | undefined;
  if (win && /[^\x00-\x7F]/.test(root)) {
    junction = join(tmpdir(), "mingli-public");
    if (!existsSync(junction))
      execFileSync("cmd.exe", ["/d", "/c", "mklink", "/J", junction, root]);
    appDir = join(junction, "app");
  }
  const flutter = win ? "flutter.bat" : "flutter";
  const run = (args: string[]) =>
    execFileSync(flutter, args, { cwd: appDir, stdio: "inherit", shell: win });
  console.log("building the web app (API_BASE_URL=origin)…");
  run(["build", "web", "--release", "--dart-define=API_BASE_URL=origin"]);
  // Building through a second path deletes committed gen-l10n output (global rule 17).
  if (junction) run(["gen-l10n"]);
}

async function cloudflared(): Promise<string> {
  const onPath = (() => {
    try {
      execFileSync(win ? "where" : "which", ["cloudflared"], { stdio: "ignore" });
      return "cloudflared";
    } catch {
      return undefined;
    }
  })();
  if (onPath) return onPath;
  const dir = join(root, ".cache", "bin");
  const bin = join(dir, win ? "cloudflared.exe" : "cloudflared");
  if (existsSync(bin)) return bin;
  const asset = win
    ? "cloudflared-windows-amd64.exe"
    : process.platform === "darwin"
      ? "cloudflared-darwin-arm64.tgz"
      : "cloudflared-linux-amd64";
  if (asset.endsWith(".tgz"))
    throw new Error("install cloudflared (brew install cloudflared) and retry");
  const url = `https://github.com/cloudflare/cloudflared/releases/latest/download/${asset}`;
  console.log(`downloading cloudflared (official release): ${url}`);
  const res = await fetch(url);
  if (!res.ok) throw new Error(`cloudflared download failed: HTTP ${res.status}`);
  mkdirSync(dir, { recursive: true });
  writeFileSync(bin, Buffer.from(await res.arrayBuffer()));
  if (!win) chmodSync(bin, 0o755);
  return bin;
}

const children: ChildProcess[] = [];
function stopAll(code = 0) {
  for (const c of children) c.kill();
  process.exit(code);
}
process.on("SIGINT", () => stopAll());
process.on("SIGTERM", () => stopAll());

if (!process.argv.includes("--skip-build")) buildWeb();

const api = spawn(
  process.execPath,
  ["--import", "tsx", join(root, "scripts", "api-server.ts"), "--public"],
  {
    cwd: root,
    env: { ...process.env, PORT: String(port) },
    stdio: ["ignore", "pipe", "inherit"],
  },
);
children.push(api);
await new Promise<void>((ready, fail) => {
  api.stdout!.on("data", (d: Buffer) => {
    process.stdout.write(d);
    if (d.toString().includes("API v1")) ready();
  });
  api.on("exit", (code) => fail(new Error(`API exited (${code})`)));
});

const tunnel = spawn(
  await cloudflared(),
  ["tunnel", "--no-autoupdate", "--url", `http://127.0.0.1:${port}`],
  {
    stdio: ["ignore", "pipe", "pipe"],
  },
);
children.push(tunnel);
let announced = false;
const scan = (d: Buffer) => {
  const m = /https:\/\/[a-z0-9-]+\.trycloudflare\.com/.exec(d.toString());
  if (m && !announced) {
    announced = true;
    console.log("\n================================================================");
    console.log(`  Public test URL: ${m[0]}`);
    console.log("  Open it on any phone or computer. Keep this window running.");
    console.log("  Ctrl+C stops the API and the tunnel.");
    console.log("================================================================\n");
  }
};
tunnel.stdout!.on("data", scan);
tunnel.stderr!.on("data", scan);
tunnel.on("exit", (code) => {
  console.error(`tunnel exited (${code})`);
  stopAll(1);
});
