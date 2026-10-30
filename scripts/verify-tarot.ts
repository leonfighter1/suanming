/**
 * 塔羅 technical verification: statistical battery on the draw.
 *   npm run verify:tarot            # 100 000 draws per spread
 *   npm run verify:tarot -- 300000
 * Writes docs/verification/tarot-results.json; exit 1 if any check fails.
 */
import { tarotBattery } from "../test/oracle/tarot-stats.js";
import { runVerification } from "./verify-run.js";

runVerification("tarot", tarotBattery);
