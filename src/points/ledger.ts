/**
 * 积分 (v11.0.0, tech plan S20): each account's balance, every change to it, and what running AI jobs hold. A job
 * holds what it may cost before it starts, so two requests can't spend the same 积分; when it ends, what it is
 * charged leaves the balance and the rest of the hold is free again. Both stores keep it (memory, and PGlite since
 * migration 010); account deletion takes it with everything else (simulated 积分 only: real payments keep their
 * records as the law asks, Phase 4).
 */
import { randomUUID } from "node:crypto";
import type { ChargeKind, Pack, PointsBasis, PointsCharge } from "./pricing.js";

/** What a charge paid for. */
export interface PointsFor {
  kind: ChargeKind;
  id: string;
  /** The method of the chart it was on. */
  system?: string;
}

export type PointsEntryKind = "grant" | "topup" | "charge";

/** One change to a balance. */
export interface PointsEntry {
  id: string;
  owner: string;
  kind: PointsEntryKind;
  /** Signed: more for a grant or a top-up, less for a charge. */
  points: number;
  /** The balance after it. */
  balance: number;
  created_at: string;
  for?: PointsFor;
  /** How a charge was priced: its measured tokens, its estimate (no tokens reported: the mock), or a flat fee. */
  basis?: PointsBasis;
  /** A measured charge's cost, in US dollars at list price. */
  usd?: number;
  /** A top-up's pack. */
  pack?: Pack;
  /** A grant's reason: "dev" for the dev accounts' start, "admin:<id>" for an admin's (v11.2.0). */
  reason?: string;
  /** What an admin wrote with a grant (v11.2.0). */
  note?: string;
}

/** What a running job holds: at most it is charged `points`; `quote` is its estimate. */
export interface PointsHold {
  id: string;
  owner: string;
  points: number;
  quote: number;
  for: PointsFor;
  created_at: string;
}

export type PointsCredit =
  { kind: "topup"; pack: Pack } | { kind: "grant"; reason: string; note?: string };

export interface PointsBalance {
  balance: number;
  /** What running jobs hold of it. */
  held: number;
}

export interface PointsLedger {
  pointsOf(owner: string): Promise<PointsBalance>;
  /**
   * Holds what a request may cost when what is available (the balance less what is held) covers `need`: `want`, or
   * all that is available when that is less. Undefined when it doesn't cover `need`. Atomic: two requests at once
   * never hold the same 积分.
   */
  holdPoints(
    owner: string,
    need: number,
    want: number,
    what: PointsFor,
    at: string,
  ): Promise<PointsHold | undefined>;
  /**
   * Ends a hold: `charge` leaves the balance (never below nothing) and the rest is free; without one all of it is.
   * Nothing happens when the hold is gone (settled already, or its account deleted).
   */
  settlePoints(
    hold: PointsHold,
    charge: PointsCharge | undefined,
    at: string,
  ): Promise<PointsEntry | undefined>;
  /** Adds 积分: a top-up, or a grant, which an account gets once per reason (undefined when it had it). */
  creditPoints(
    owner: string,
    points: number,
    credit: PointsCredit,
    at: string,
  ): Promise<PointsEntry | undefined>;
  /** Newest first. */
  listPoints(owner: string, limit: number): Promise<PointsEntry[]>;
  listHolds(owner: string): Promise<PointsHold[]>;
  /** 管理后台 (v11.2.0): every account's changes since `since` (all without it), oldest first. */
  allPoints(since?: string): Promise<PointsEntry[]>;
  /** 管理后台 (v11.2.0): every account's balance and what its running jobs hold. */
  allBalances(): Promise<Map<string, PointsBalance>>;
}

/** The ledger in memory. Each call reads and writes without awaiting in between, so it is atomic. */
/**
 * A hold for a request quoted at [need] points, asking up to [want], with [available] free (S28: both stores wrote
 * this rule): none when the quote is under 1 or more than is free, else the larger of the two, no more than is free.
 */
export function newHold(
  owner: string,
  available: number,
  need: number,
  want: number,
  what: PointsFor,
  at: string,
): PointsHold | undefined {
  if (need < 1 || available < need) return undefined;
  return {
    id: randomUUID(),
    owner,
    points: Math.min(Math.max(want, need), available),
    quote: need,
    for: { ...what },
    created_at: at,
  };
}

/** The entry a credit makes, leaving [balance]: a top-up's pack, or a grant's reason and note (S28: both stores). */
export function creditEntry(
  owner: string,
  credit: PointsCredit,
  points: number,
  balance: number,
  at: string,
): PointsEntry {
  return {
    id: randomUUID(),
    owner,
    kind: credit.kind,
    points,
    balance,
    created_at: at,
    ...(credit.kind === "topup"
      ? { pack: { ...credit.pack } }
      : { reason: credit.reason, ...(credit.note && { note: credit.note }) }),
  };
}

export class InMemoryLedger implements PointsLedger {
  private readonly balances = new Map<string, number>();
  private entries: PointsEntry[] = [];
  private readonly holds = new Map<string, PointsHold>();

  private heldBy(owner: string) {
    let n = 0;
    for (const h of this.holds.values()) if (h.owner === owner) n += h.points;
    return n;
  }

  async pointsOf(owner: string) {
    return { balance: this.balances.get(owner) ?? 0, held: this.heldBy(owner) };
  }

  async holdPoints(owner: string, need: number, want: number, what: PointsFor, at: string) {
    const hold = newHold(
      owner,
      (this.balances.get(owner) ?? 0) - this.heldBy(owner),
      need,
      want,
      what,
      at,
    );
    if (!hold) return undefined;
    this.holds.set(hold.id, hold);
    return structuredClone(hold);
  }

  async settlePoints(hold: PointsHold, charge: PointsCharge | undefined, at: string) {
    if (!this.holds.delete(hold.id) || !charge || charge.points < 1) return undefined;
    const before = this.balances.get(hold.owner) ?? 0;
    const taken = Math.min(charge.points, before);
    this.balances.set(hold.owner, before - taken);
    return this.add({
      id: randomUUID(),
      owner: hold.owner,
      kind: "charge",
      points: -taken,
      balance: before - taken,
      created_at: at,
      for: { ...hold.for },
      basis: charge.basis,
      ...(charge.usd !== undefined && { usd: charge.usd }),
    });
  }

  async creditPoints(owner: string, points: number, credit: PointsCredit, at: string) {
    if (
      credit.kind === "grant" &&
      this.entries.some(
        (e) => e.owner === owner && e.kind === "grant" && e.reason === credit.reason,
      )
    ) {
      return undefined;
    }
    const balance = (this.balances.get(owner) ?? 0) + points;
    this.balances.set(owner, balance);
    return this.add(creditEntry(owner, credit, points, balance, at));
  }

  private add(e: PointsEntry) {
    this.entries.push(e);
    return structuredClone(e);
  }

  async listPoints(owner: string, limit: number) {
    // Written in time order: the newest last, also among entries made in the same millisecond.
    return this.entries
      .filter((e) => e.owner === owner)
      .reverse()
      .sort((a, b) => (a.created_at < b.created_at ? 1 : a.created_at > b.created_at ? -1 : 0))
      .slice(0, limit)
      .map((e) => structuredClone(e));
  }

  async listHolds(owner: string) {
    return [...this.holds.values()].filter((h) => h.owner === owner).map((h) => structuredClone(h));
  }

  async allPoints(since?: string) {
    // Written in time order; a stable sort keeps that order among entries of the same millisecond.
    return this.entries
      .filter((e) => !since || e.created_at >= since)
      .sort((a, b) => (a.created_at < b.created_at ? -1 : a.created_at > b.created_at ? 1 : 0))
      .map((e) => structuredClone(e));
  }

  async allBalances() {
    const all = new Map<string, PointsBalance>();
    for (const [owner, balance] of this.balances) all.set(owner, { balance, held: 0 });
    for (const h of this.holds.values()) {
      const b = all.get(h.owner) ?? { balance: 0, held: 0 };
      all.set(h.owner, { ...b, held: b.held + h.points });
    }
    return all;
  }

  /** Account deletion: everything of the owner's; the number of entries it had. */
  deleteOwner(owner: string): number {
    const before = this.entries.length;
    this.entries = this.entries.filter((e) => e.owner !== owner);
    this.balances.delete(owner);
    for (const [id, h] of this.holds) if (h.owner === owner) this.holds.delete(id);
    return before - this.entries.length;
  }
}
