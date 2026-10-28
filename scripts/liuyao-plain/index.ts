/**
 * 算卦's 直說 source (tech plan WP10.2): the 64 hexagrams in King Wen order, each with its 卦辭 and 爻辭 said
 * straight out in 繁體. Only `npm run build:liuyao` reads it; the server reads data/liuyao/plain.json.
 */
import { PART_1 } from "./1.js";
import { PART_2 } from "./2.js";
import { PART_3 } from "./3.js";
import { PART_4 } from "./4.js";

export interface PlainSource {
  /** Six lines, 初爻 first, 1 = yang: checked against data/yijing at the same place in the order */
  id: string;
  /** The 卦辭, said straight out */
  gua: string;
  /** Each 爻辭 初 to 上, then 用九 / 用六 for 乾 and 坤 */
  lines: string[];
}

export const PLAIN: PlainSource[] = [...PART_1, ...PART_2, ...PART_3, ...PART_4];
