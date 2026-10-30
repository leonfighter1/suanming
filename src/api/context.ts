/**
 * What the API's route groups share (S28 Phase D; docs/refactor-plan.md F1): the server's options and store, and the
 * state and rules createApiServer keeps across requests. The server builds it once and hands the same objects to each
 * group (routes/*.ts), never copies, so a quota or a hold is counted in one place.
 */
import type { IncomingMessage } from "node:http";
import type { AccountService } from "../auth/account.js";
import type { AccountPermissions, AuthService } from "../auth/service.js";
import type { Dispatcher, MailTransport } from "../notify/index.js";
import type { ChargeKind, PointsConfig, Quote, QuoteFor } from "../points/index.js";
import type { ApiOptions } from "./server.js";
import type { Store } from "./store.js";

/** Who is asking: the account, and the region stored on it at sign-up (Geo-Rule). */
export interface Caller {
  user: string;
  country: string;
}

export interface ApiContext {
  opts: ApiOptions;
  store: Store;
  now: () => Date;
  /** The server's log: never an address or a message's content. */
  log: (msg: string, err?: unknown) => void;
  /** Absent only in devMode. */
  auth?: AuthService;
  /** The account's own logins and settings (v8.2.0); absent without auth. */
  account?: AccountService;
  /** The reviewers' logins (ApiOptions.admins), in lower case. */
  admins: Set<string>;
  /** The answers kept for an Idempotency-Key, by user, path and key. */
  idempotency: Map<string, { status: number; body: unknown; headers: Record<string, string> }>;
  /** How mail and text messages leave here, by the transports' names. */
  delivery: () => { mail: string; sms: string };
  /** The mail transport ("off" until one is set up). */
  mail: MailTransport;
  /** Every message's way out (S25): its template, its channel, its note. */
  messages: Dispatcher;
  /** Counts a 发到邮箱 message against the account's day; 429 `too_many` past MAIL_PER_DAY. */
  takeMailQuota: (user: string) => void;
  /** The reviewer's login when the caller is a reviewer, else undefined. */
  reviewer: (c: Caller) => Promise<string | undefined>;
  /** The client's address, for the sign-in limits: behind a trusted proxy, the one it names. */
  clientIp: (req: IncomingMessage) => string;
  /** 积分 (v11.0.0): their prices and packs; absent while they are off. */
  pointsConfig?: PointsConfig;
  /** 充值 adds a pack's 积分 without payment (development, until Phase 4). */
  simulatedTopUp: boolean;
  /** What an AI request costs now; undefined while 积分 are off. */
  priceOf: (kind: ChargeKind, about?: QuoteFor) => Quote | undefined;
  /** What an admin allows this account; 403 `ai_not_allowed` / `top_up_not_allowed` when not. */
  assertAllowed: (c: Caller, what: keyof AccountPermissions) => Promise<void>;
  /** Geo-Rule: refuses (451) before anything is computed for a region, or a method, not served. */
  assertServed: (country: string, system?: string) => void;
}
