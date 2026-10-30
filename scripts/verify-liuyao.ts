/**
 * 算卦 technical verification: statistical battery on the coins (auto casts and pick layouts).
 *   npm run verify:liuyao            # 100 000 casts
 *   npm run verify:liuyao -- 300000
 * Writes docs/verification/liuyao-results.json; exit 1 if any check fails.
 */
import { liuyaoBattery } from "../test/oracle/liuyao-stats.js";
import { runVerification } from "./verify-run.js";

runVerification("liuyao", liuyaoBattery);
