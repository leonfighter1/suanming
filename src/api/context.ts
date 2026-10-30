/**
 * What the API's route groups share (S28 Phase D; docs/refactor-plan.md F1): the server's options and store, and the
 * state and rules createApiServer keeps across requests. The server builds it once and hands the same objects to each
 * group (routes/*.ts), never copies, so a quota or a hold is counted in one place.
 */
import type { IncomingMessage } from "node:http";
import type { AccountService } from "../auth/account.js";
import type { AuthService } from "../auth/service.js";
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
  /** The reviewer's login when the caller is a reviewer, else undefined. */
  reviewer: (c: Caller) => Promise<string | undefined>;
  /** The client's address, for the sign-in limits: behind a trusted proxy, the one it names. */
  clientIp: (req: IncomingMessage) => string;
}
