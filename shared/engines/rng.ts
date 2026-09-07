/**
 * Deterministic RNG.
 *
 * Every random outcome the game commits to is derived from a stable seed
 * (usually the entity's id), never from Math.random(). Resolving the same
 * farm state twice therefore produces exactly the same result, which is what
 * lets the server recompute offline progress idempotently.
 */

/** FNV-1a. Turns an id into a 32-bit seed. */
export function hashSeed(input: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < input.length; i++) {
    h ^= input.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

export interface Rng {
  /** Uniform [0, 1). */
  next(): number;
  /** Uniform integer in [min, max]. */
  int(min: number, max: number): number;
  /** Uniform float in [min, max). */
  float(min: number, max: number): number;
  pick<T>(items: readonly T[]): T;
  /** Current internal state — persist it to continue the stream later. */
  state(): number;
}

/** mulberry32 — small, fast, good enough for gameplay. */
export function createRng(seed: number): Rng {
  let a = seed >>> 0;
  const next = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  return {
    next,
    int: (min, max) => min + Math.floor(next() * (max - min + 1)),
    float: (min, max) => min + next() * (max - min),
    pick: (items) => items[Math.floor(next() * items.length)],
    state: () => a >>> 0,
  };
}

/** A one-shot stream keyed to a stable string — reproducible per entity. */
export function rngFor(...parts: Array<string | number>): Rng {
  return createRng(hashSeed(parts.join('|')));
}
