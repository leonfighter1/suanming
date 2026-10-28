/**
 * Envelope encryption for the database store (tech plan WP5.1; db/schema_v0.sql; docs/data-retention.md).
 * Every user has a data key (DEK) that is stored only wrapped by the key-encryption key (KEK):
 * MINGLI_DATA_KEY here, a KMS in production. A body is sealed with AES-256-GCM under its owner's DEK,
 * with the table and row id as associated data, so a ciphertext copied into another row won't open.
 * Destroying a user's wrapped DEK makes everything sealed under it unreadable (crypto-shredding).
 */
import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";

const ALG = "aes-256-gcm";
/** The first byte of every sealed value, so the format can change later. */
const FORMAT = 1;
const NONCE = 12;
const TAG = 16;

/** The KEK from its setting: 32 bytes in base64, or an error that says what to set. */
export function parseKek(b64: string | undefined): Buffer {
  if (!b64?.trim()) {
    throw new Error(
      "MINGLI_DATA_KEY is not set: 32 random bytes in base64 (npm run keygen prints one)",
    );
  }
  const key = Buffer.from(b64.trim(), "base64");
  if (key.length !== 32) {
    throw new Error(`MINGLI_DATA_KEY must be 32 bytes in base64, not ${key.length}`);
  }
  return key;
}

/** format (1) | nonce (12) | tag (16) | ciphertext. */
export function seal(key: Buffer, plaintext: Buffer, aad: string): Buffer {
  const nonce = randomBytes(NONCE);
  const cipher = createCipheriv(ALG, key, nonce);
  cipher.setAAD(Buffer.from(aad, "utf8"));
  const body = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  return Buffer.concat([Buffer.from([FORMAT]), nonce, cipher.getAuthTag(), body]);
}

/** Opens a sealed value; throws if the key, the associated data or a single byte is wrong. */
export function open(key: Buffer, sealed: Buffer, aad: string): Buffer {
  if (sealed.length < 1 + NONCE + TAG || sealed[0] !== FORMAT)
    throw new Error("not a sealed value");
  const decipher = createDecipheriv(ALG, key, sealed.subarray(1, 1 + NONCE));
  decipher.setAAD(Buffer.from(aad, "utf8"));
  decipher.setAuthTag(sealed.subarray(1 + NONCE, 1 + NONCE + TAG));
  return Buffer.concat([decipher.update(sealed.subarray(1 + NONCE + TAG)), decipher.final()]);
}

export const sealJson = (key: Buffer, value: unknown, aad: string) =>
  seal(key, Buffer.from(JSON.stringify(value), "utf8"), aad);

export const openJson = <T>(key: Buffer, sealed: Buffer, aad: string): T =>
  JSON.parse(open(key, sealed, aad).toString("utf8")) as T;

/** A new DEK for a user, and the form it is stored in: sealed under the KEK, bound to the user. */
export function newDataKey(kek: Buffer, userId: string): { dek: Buffer; wrapped: Buffer } {
  const dek = randomBytes(32);
  return { dek, wrapped: seal(kek, dek, `dek:${userId}`) };
}

export const unwrapDataKey = (kek: Buffer, wrapped: Buffer, userId: string) =>
  open(kek, wrapped, `dek:${userId}`);
