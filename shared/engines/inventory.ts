/** Filament stock: reserving grams for a print and giving some back on failure. */

import type { FarmState, Spool } from '../types';

export interface Reservation {
  spoolId: string;
  grams: number;
}

/** The spool best able to cover a job: right material+colour, most grams left. */
export function pickSpool(
  spools: Spool[],
  materialId: string,
  colorId: string,
  grams: number,
): Spool | undefined {
  const exact = spools
    .filter((s) => s.materialId === materialId && s.colorId === colorId && s.grams >= grams)
    .sort((a, b) => b.grams - a.grams);
  return exact[0];
}

/** Grams of the right material+colour on hand, and how many are missing. */
export function stockCheck(
  spools: Spool[],
  materialId: string,
  colorId: string,
  grams: number,
): { available: number; missing: number; ok: boolean } {
  const available = spools
    .filter((s) => s.materialId === materialId && s.colorId === colorId)
    .reduce((sum, s) => sum + s.grams, 0);
  return { available, missing: Math.max(0, grams - available), ok: available >= grams };
}

/** Take grams off a spool. Returns false and changes nothing if it can't cover it. */
export function reserve(state: FarmState, spoolId: string, grams: number): boolean {
  const spool = state.spools.find((s) => s.id === spoolId);
  if (!spool || spool.grams < grams) return false;
  spool.grams = Math.round((spool.grams - grams) * 100) / 100;
  return true;
}

/** Put unused grams back after a failure. Empty spools are discarded. */
export function refund(state: FarmState, spoolId: string, grams: number): void {
  const spool = state.spools.find((s) => s.id === spoolId);
  if (!spool || grams <= 0) return;
  spool.grams = Math.round(Math.min(spool.capacity, spool.grams + grams) * 100) / 100;
}

/** Drop spools that have nothing left, so the rack shows real stock. */
export function pruneEmptySpools(state: FarmState): void {
  state.spools = state.spools.filter((s) => s.grams > 0.5);
}

/** Add a fresh spool to the rack. */
export function addSpool(
  state: FarmState,
  id: string,
  materialId: string,
  colorId: string,
  grams: number,
  quality: number,
): Spool {
  const spool: Spool = { id, materialId, colorId, grams, capacity: grams, quality };
  state.spools.push(spool);
  return spool;
}
