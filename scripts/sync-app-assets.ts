/** npm run sync:app — writes the app's server-sourced assets and fixtures (see scripts/app-assets.ts). */
import { mkdirSync, writeFileSync } from "node:fs";
import { at, buildAppAssets, serialize } from "./app-assets.js";

for (const [p, data] of Object.entries(await buildAppAssets())) {
  mkdirSync(new URL(".", at(p)), { recursive: true });
  writeFileSync(at(p), serialize(data));
  console.log(`wrote ${p}`);
}
