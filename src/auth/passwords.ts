import { Algorithm, hash, verify } from "@node-rs/argon2";

/** OWASP Password Storage Cheat Sheet (2025) minimum for Argon2id. */
const PARAMS = { algorithm: Algorithm.Argon2id, memoryCost: 19456, timeCost: 2, parallelism: 1 };

export const PASSWORD_MIN = 10;
export const PASSWORD_MAX = 256;

/** Returns a reason the password is unacceptable, or null. */
export function passwordProblem(pw: unknown): string | null {
  if (typeof pw !== "string") return "password is required";
  if ([...pw].length < PASSWORD_MIN) return `password must be at least ${PASSWORD_MIN} characters`;
  if (pw.length > PASSWORD_MAX) return `password must be at most ${PASSWORD_MAX} characters`;
  return null;
}

export const hashPassword = (pw: string) => hash(pw, PARAMS);

export async function verifyPassword(stored: string, pw: string): Promise<boolean> {
  try {
    return await verify(stored, pw);
  } catch {
    return false;
  }
}

/** A real hash to verify against when the account doesn't exist, so timing doesn't reveal it. */
let dummy: Promise<string> | undefined;
export const dummyHash = () => (dummy ??= hashPassword("dummy-password-for-timing"));
