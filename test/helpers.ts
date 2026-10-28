import { readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { GeoRuleMatrix } from "../src/compliance/geo.js";

export const PEPPER = Buffer.alloc(32, 7);
export const DRAW_KEY = Buffer.alloc(32, 9);
export const FIXED_NOW = () => new Date("2026-10-25T00:00:00.000Z");

let matrixFiles = 0;

/**
 * Runs [work] against a copy of the shipped geo matrix that [edit] changes, through MINGLI_GEO_MATRIX, and
 * restores it afterwards: a test that needs a switch on or off sets it here instead of relying on the
 * shipped value, which the owner may flip (MISTAKES rule 42). Calls don't nest: make every change in one.
 */
export async function withMatrix<T>(
  edit: (matrix: GeoRuleMatrix) => void,
  work: () => Promise<T>,
): Promise<T> {
  const matrix = JSON.parse(
    readFileSync("compliance/geo_rule_matrix.json", "utf8"),
  ) as GeoRuleMatrix;
  edit(matrix);
  const file = join(tmpdir(), `mingli-geo-${process.pid}-${++matrixFiles}.json`);
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

/**
 * Runs [work] with 起名 switched on: the geo matrix ships it off until the owner has checked its 字义库.
 */
export function withNamingOn<T>(work: () => Promise<T>): Promise<T> {
  return withNaming(true, work);
}

/** Runs [work] with 起名 on or off by default, whatever the shipped matrix says (see [withMatrix]). */
export function withNaming<T>(available: boolean, work: () => Promise<T>): Promise<T> {
  return withMatrix((m) => {
    m.defaults.systems.naming!.available = available;
  }, work);
}

/** Runs [work] with Indonesia served, as after the owner's sign-off (WP8.1; the matrix ships it off). */
export function withIndonesiaOn<T>(work: () => Promise<T>): Promise<T> {
  return withMatrix((m) => {
    m.regions.ID!.service_available = true;
    m.regions.ID!.legal_review = "provisional";
  }, work);
}
