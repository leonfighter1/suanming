/**
 * 内容管理 (S29): where staff's changes to the app's texts and images are kept, the memory store's and the database's
 * alike (src/api/store.ts, src/db/pg-store.ts). Without a record the app shows its own.
 */
import type { ContentLocale } from "./catalog.js";

export interface ContentTextRecord {
  key: string;
  locale: ContentLocale;
  text: string;
  updated_at: string;
  /** The staff account that changed it. */
  updated_by?: string;
}

export interface ContentImageRecord {
  key: string;
  /** Its media type: image/png, image/jpeg or image/webp. */
  type: string;
  data: Buffer;
  updated_at: string;
  updated_by?: string;
}

export type ContentImageInfo = Omit<ContentImageRecord, "data">;

export interface ContentStore {
  listContentTexts(): Promise<ContentTextRecord[]>;
  putContentText(r: ContentTextRecord): Promise<void>;
  /** True when there was one. */
  deleteContentText(key: string, locale: ContentLocale): Promise<boolean>;
  /** Every image staff put in, without its bytes. */
  listContentImages(): Promise<ContentImageInfo[]>;
  getContentImage(key: string): Promise<ContentImageRecord | undefined>;
  putContentImage(r: ContentImageRecord): Promise<void>;
  /** True when there was one. */
  deleteContentImage(key: string): Promise<boolean>;
}
