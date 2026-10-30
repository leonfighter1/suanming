/**
 * 管理后台 (v11.2.0, tech plan S22): what every AI job used. One row per step (an agent's call, with its retries): who
 * asked, what for, which model, its tokens and its cost at list price, and whether the job delivered. Numbers only,
 * never a text; the rows outlive a deleted account, without its owner, so the totals stay.
 */
import { costUsd, type AgentTrace } from "../ai/index.js";
import type { ChargeKind } from "../points/index.js";

export interface UsageRow {
  job_id: string;
  /** Absent once the account is deleted. */
  owner?: string;
  kind: ChargeKind;
  /** The method of the chart the job was on. */
  system?: string;
  agent: string;
  model: string;
  input_tokens: number;
  output_tokens: number;
  cache_read_tokens: number;
  cache_write_tokens: number;
  /** At the model's list price; a model without one at the reference model's; the mock's none. */
  usd: number;
  /** The job gave its user something (passed): failed and held jobs cost without delivering. */
  delivered: boolean;
  demo?: boolean;
  created_at: string;
}

/** A job's rows, one per step it ran. */
export function usageRows(
  job: { kind: ChargeKind; id: string; owner: string; system?: string; demo?: boolean },
  agents: readonly AgentTrace[],
  delivered: boolean,
  at: string,
  referenceModel: string,
): UsageRow[] {
  return agents.map((a) => {
    const u = a.usage;
    return {
      job_id: job.id,
      owner: job.owner,
      kind: job.kind,
      ...(job.system && { system: job.system }),
      agent: a.agent,
      model: a.model,
      input_tokens: u.input_tokens,
      output_tokens: u.output_tokens,
      cache_read_tokens: u.cache_read_input_tokens ?? 0,
      cache_write_tokens: u.cache_creation_input_tokens ?? 0,
      usd: costUsd(a.model, u) ?? costUsd(referenceModel, u) ?? 0,
      delivered,
      ...(job.demo && { demo: true }),
      created_at: at,
    };
  });
}
