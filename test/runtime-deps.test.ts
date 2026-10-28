// The API server loads only runtime dependencies (v4.1.0). v3.2.0 exported the term tips from the
// ai index, and with them OpenCC, a dev tool, into every server process: a production install
// without devDependencies would not have started. This walks the server's import graph instead.
import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { expect, it } from "vitest";

const root = fileURLToPath(new URL("../", import.meta.url));
const pkg = JSON.parse(readFileSync(resolve(root, "package.json"), "utf8")) as {
  devDependencies: Record<string, string>;
};

/** Runtime imports of a file: `import … from` and `export … from`, not `import type`. */
function imports(file: string): string[] {
  const text = readFileSync(file, "utf8");
  return [...text.matchAll(/^(?:import|export)\s+(?!type\b)[^;]*?from\s+"([^"]+)"/gms)].map(
    (m) => m[1]!,
  );
}

/** The package an import names (@scope/name or name), or undefined for a relative or node: one. */
const packageOf = (spec: string) =>
  spec.startsWith(".") || spec.startsWith("node:")
    ? undefined
    : spec
        .split("/")
        .slice(0, spec.startsWith("@") ? 2 : 1)
        .join("/");

it("nothing the API server loads imports a devDependency", () => {
  const seen = new Set<string>();
  const packages = new Map<string, string>(); // package → first file that imports it
  const walk = (file: string) => {
    if (seen.has(file)) return;
    seen.add(file);
    for (const spec of imports(file)) {
      const name = packageOf(spec);
      if (name) {
        if (!packages.has(name)) packages.set(name, file.slice(root.length));
        continue;
      }
      if (spec.startsWith("node:")) continue;
      const target = resolve(dirname(file), spec.replace(/\.js$/, ".ts"));
      if (existsSync(target)) walk(target);
    }
  };
  walk(resolve(root, "scripts/api-server.ts"));
  expect(seen.size).toBeGreaterThan(30); // the walk reached the server, the engines and the AI
  const dev = [...packages].filter(([name]) => name in pkg.devDependencies);
  expect(dev).toEqual([]);
});
