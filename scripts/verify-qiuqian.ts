/**
 * 求籤 technical verification: statistical battery on the draw (sticks and blocks).
 *   npm run verify:qiuqian            # 100 000 draws
 *   npm run verify:qiuqian -- 300000
 * Writes docs/verification/qiuqian-results.json; exit 1 if any check fails.
 */
import { qiuqianBattery } from "../test/oracle/qiuqian-stats.js";
import { runVerification } from "./verify-run.js";

runVerification("qiuqian", qiuqianBattery);
