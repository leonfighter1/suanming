/**
 * 收据 (S31; the owner, 2026-10-31: 「Generate a purchase receipt for user. user is able to view and print the money
 * spent and points they purchased. (need to have an email address.). Admin's adding points shouldn't reflect on the
 * money print」): one for each 充值, kept with the account: what was paid, in which currency at which rate and charge,
 * the 积分 it brought, and the account's email. An admin's 增加积分 is no purchase and makes none. 充值 is simulated until
 * the owner's Phase 4 payments, and its receipt says so.
 */

export interface Receipt {
  id: string;
  /** MLDS-<year>-<sequence>: the store gives it, one after another. */
  number: string;
  owner: string;
  /** The 积分 entry the 充值 made. */
  entry_id: string;
  created_at: string;
  /** The account's email address at the time. */
  email: string;
  pack: { yuan: number; points: number };
  /** What was paid, in [currency]. */
  currency: string;
  amount: number;
  /** 1 元 = rate of [currency] (1 for 元), from the day's table of [rates_date]. */
  rate: number;
  rates_date?: string;
  /** The service charge in [amount] (none for 元). */
  service_charge_percent: number;
  /** No payment was taken: 充值 is simulated until Phase 4. */
  simulated: boolean;
}

/** Where receipts are kept: the database (migration 017, sealed), or the memory store. */
export interface ReceiptStore {
  /** Keeps [r] and gives it its number. */
  putReceipt(r: Omit<Receipt, "number">): Promise<Receipt>;
  /** The account's, newest first. */
  listReceipts(owner: string, limit: number): Promise<Receipt[]>;
  getReceipt(id: string): Promise<Receipt | undefined>;
}

/** The [seq]th receipt's number, in its year. */
export const receiptNumber = (seq: number, createdAt: string) =>
  `MLDS-${createdAt.slice(0, 4)}-${String(seq).padStart(6, "0")}`;
