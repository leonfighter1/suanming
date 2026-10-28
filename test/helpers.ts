import { readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

export const PEPPER = Buffer.alloc(32, 7);
export const DRAW_KEY = Buffer.alloc(32, 9);
export const FIXED_NOW = () => new Date("2026-10-25T00:00:00.000Z");

/**
 * Runs [work] with 起名 switched on: the geo matrix ships it off until the owner has checked its 字义库, so
 * tests point MINGLI_GEO_MATRIX at a copy with naming available, and restore it afterwards.
 */
export function withNamingOn<T>(work: () => Promise<T>): Promise<T> {
  return withNaming(true, work);
}

/** Runs [work] with 起名 on or off by default, whatever the shipped matrix says (see [withNamingOn]). */
export async function withNaming<T>(available: boolean, work: () => Promise<T>): Promise<T> {
  const matrix = JSON.parse(readFileSync("compliance/geo_rule_matrix.json", "utf8"));
  matrix.defaults.systems.naming.available = available;
  const file = join(tmpdir(), `mingli-geo-naming-${available ? "on" : "off"}-${process.pid}.json`);
  writeFileSync(file, JSON.stringify(matrix));
  const before = process.env.MINGLI_GEO_MATRIX;
  process.env.MINGLI_GEO_MATRIX = file;
  try {
    return await work();
  } finally {
    if (before === undefined) delete process.env.MINGLI_GEO_MATRIX;
    else process.env.MINGLI_GEO_MATRIX = before;
  }
}
