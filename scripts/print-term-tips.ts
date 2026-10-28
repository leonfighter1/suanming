// Prints every term tip's 繁體 next to its 简体, for the G18 review (rule G18): npx tsx scripts/print-term-tips.ts
import { TERM_TIPS, tipHant } from "../src/ai/term-tips.js";

for (const [key, v] of Object.entries(TERM_TIPS)) {
  console.log(`${key}\n  ${v["zh-Hans"]}\n  ${tipHant(v["zh-Hans"])}`);
}
