import { createHmac } from "node:crypto";

/**
 * Deterministic byte stream: block_i = HMAC-SHA256(seed, "tarot-drbg/v1" || u32be(i)).
 * Unpredictable without the seed; reproducible with it.
 */
export class HmacDrbg {
  private counter = 0;
  private buf = Buffer.alloc(0);
  private pos = 0;

  constructor(private readonly seed: Buffer) {
    if (seed.length < 32) throw new Error("seed must be >= 32 bytes");
  }

  private refill() {
    const ctr = Buffer.alloc(4);
    ctr.writeUInt32BE(this.counter++);
    this.buf = createHmac("sha256", this.seed)
      .update(Buffer.concat([Buffer.from("tarot-drbg/v1"), ctr]))
      .digest();
    this.pos = 0;
  }

  nextUint32(): number {
    if (this.pos + 4 > this.buf.length) this.refill();
    const v = this.buf.readUInt32BE(this.pos);
    this.pos += 4;
    return v;
  }

  /** Uniform integer in [0, n) via rejection sampling (no modulo bias). */
  nextInt(n: number): number {
    if (!Number.isInteger(n) || n <= 0 || n > 2 ** 32) throw new Error("bad range");
    const limit = 2 ** 32 - (2 ** 32 % n);
    for (;;) {
      const v = this.nextUint32();
      if (v < limit) return v % n;
    }
  }
}
