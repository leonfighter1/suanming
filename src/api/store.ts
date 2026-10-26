/**
 * Persistence boundary for the v1 API. In-memory for now; a PostgreSQL store
 * (db/schema_v0.sql + migrations, encrypted facts/report bodies) implements the
 * same interface later.
 */
import type { Report } from "../ai/index.js";
import type { ChartFact } from "../chart-fact/index.js";
import type { Locale } from "../ai/terms.js";
import type { Topic } from "../ai/types.js";

export interface ChartRecord {
  id: string;
  owner: string;
  fact: ChartFact;
  created_at: string;
}

export type ReportRecordStatus = "pending" | "passed" | "blocked" | "manual_review" | "failed";

export interface ReportRecord {
  id: string;
  owner: string;
  chart_id: string;
  status: ReportRecordStatus;
  locale: Locale;
  topics: Topic[];
  created_at: string;
  updated_at: string;
  report?: Report;
  error?: string;
}

export interface Store {
  putChart(c: ChartRecord): Promise<void>;
  getChart(id: string): Promise<ChartRecord | undefined>;
  putReport(r: ReportRecord): Promise<void>;
  getReport(id: string): Promise<ReportRecord | undefined>;
  /** Account deletion: remove everything the user owns. Returns counts for the receipt. */
  deleteOwnerData(owner: string): Promise<{ charts: number; reports: number }>;
}

export class InMemoryStore implements Store {
  private charts = new Map<string, ChartRecord>();
  private reports = new Map<string, ReportRecord>();
  async putChart(c: ChartRecord) {
    this.charts.set(c.id, structuredClone(c));
  }
  async getChart(id: string) {
    const c = this.charts.get(id);
    return c && structuredClone(c);
  }
  async putReport(r: ReportRecord) {
    this.reports.set(r.id, structuredClone(r));
  }
  async getReport(id: string) {
    const r = this.reports.get(id);
    return r && structuredClone(r);
  }
  async deleteOwnerData(owner: string) {
    let charts = 0;
    let reports = 0;
    for (const [id, c] of this.charts) if (c.owner === owner && this.charts.delete(id)) charts++;
    for (const [id, r] of this.reports) if (r.owner === owner && this.reports.delete(id)) reports++;
    return { charts, reports };
  }
}
