/**
 * npm run build:icons: writes the app icon in every size each platform needs (tech plan WP15.2),
 * drawn by scripts/app-icons.ts. Run it after changing the drawing; never edit the files by hand.
 */
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import { buildIcons } from "./app-icons.js";

const files = await buildIcons();
for (const [path, data] of files) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, data);
}
console.log(`wrote ${files.size} icon files`);
