/**
 * 风水 (tech plan WP6.3, the owner's Phase 3 spec): the general principles of direction and space for one
 * room, from its use and, optionally, the way its main window faces. Never a 吉凶 judgement of a home, and
 * every fact a simplified_rule. Its own method (rule 8): nothing here is used by any other.
 *
 * Deterministic: the same room and facing give the same facts. The input is anonymous (no address, no
 * floor plan, no birth data); a description of the room goes with the reading, like a question.
 */
import { inputDigest, SCHEMA_VERSION, type ChartFact } from "../../chart-fact/index.js";
import { FACINGS, ROOM_IDS, ROOMS, type Area, type Facing, type RoomId } from "./principles.js";

export const FENGSHUI_ENGINE_VERSION = "0.1.0";
/** The principles table's version: bump it whenever a principle or its wording changes. */
export const PRINCIPLES_VERSION = "1.0.0";

/** 後天八卦方位: trigram and 五行 ids per facing (names in principles.ts DIRECTIONS). */
const DIRECTION: Record<Facing, { trigram: string; element: string }> = {
  north: { trigram: "kan", element: "water" },
  northeast: { trigram: "gen", element: "earth" },
  east: { trigram: "zhen", element: "wood" },
  southeast: { trigram: "xun", element: "wood" },
  south: { trigram: "li", element: "fire" },
  southwest: { trigram: "kun", element: "earth" },
  west: { trigram: "dui", element: "metal" },
  northwest: { trigram: "qian", element: "metal" },
};

export interface FengshuiFacts {
  room: RoomId;
  facing?: Facing;
  direction?: { trigram: string; element: string };
  principles: { id: string; area: Area }[];
}

export function computeFengshui(
  input: { room: RoomId; facing?: Facing },
  ctx: { digestPepper: Buffer; now?: () => Date },
): ChartFact {
  if (!ROOM_IDS.includes(input.room)) throw new Error(`unknown room ${input.room}`);
  if (input.facing !== undefined && !FACINGS.includes(input.facing)) {
    throw new Error(`unknown facing ${input.facing}`);
  }
  const rule_versions = { principles: `fengshui-principles@${PRINCIPLES_VERSION}` };
  const normalized = { room: input.room, ...(input.facing && { facing: input.facing }) };
  return {
    schema_version: SCHEMA_VERSION,
    engine: { name: "fengshui", version: FENGSHUI_ENGINE_VERSION },
    system: "fengshui",
    input_digest: inputDigest(
      { input: normalized, engine_version: FENGSHUI_ENGINE_VERSION, rule_versions },
      ctx.digestPepper,
    ),
    rule_versions,
    computed_at: (ctx.now?.() ?? new Date()).toISOString(),
    facts: {
      ...normalized,
      ...(input.facing && { direction: DIRECTION[input.facing] }),
      principles: ROOMS[input.room].principles.map((p) => ({ id: p.id, area: p.area })),
    } satisfies FengshuiFacts,
    provenance: [
      {
        path: "/principles",
        source_level: "simplified_rule",
        note: "通用的方位與空間原則（採光、通風、動線、安全），不是住宅吉凶的判斷",
      },
      ...(input.facing
        ? [
            {
              path: "/direction",
              source_level: "simplified_rule" as const,
              note: "後天八卦方位與五行的傳統對應",
            },
          ]
        : []),
    ],
  };
}
