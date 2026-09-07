/**
 * Derived stats.
 *
 * Anything the UI shows about "how fast is this machine" or "how long will
 * this take" is computed here so the client and server never disagree.
 */

import type { GameConfig } from '../config/gameConfig';
import type { Job, Printer, Spool } from '../types';
import type { PrinterModel } from '../config/printers';
import type { Material } from '../config/materials';
import type { Product } from '../config/products';

export function printerModel(config: GameConfig, modelId: string): PrinterModel {
  const m = config.catalogs.printers.find((p) => p.id === modelId);
  if (!m) throw new Error(`Unknown printer model: ${modelId}`);
  return m;
}

export function material(config: GameConfig, id: string): Material {
  const m = config.catalogs.materials.find((x) => x.id === id);
  if (!m) throw new Error(`Unknown material: ${id}`);
  return m;
}

export function product(config: GameConfig, id: string): Product {
  const p = config.catalogs.products.find((x) => x.id === id);
  if (!p) throw new Error(`Unknown product: ${id}`);
  return p;
}

export interface EffectiveStats {
  speed: number;
  quality: number;
  failureBase: number;
  healthDecay: number;
  queueCapacity: number;
  materialWaste: number;
  energy: number;
}

/** Printer stats after installed upgrades. */
export function effectiveStats(config: GameConfig, printer: Printer): EffectiveStats {
  const model = printerModel(config, printer.modelId);
  const out: EffectiveStats = {
    speed: model.speed,
    quality: model.quality,
    failureBase: model.failureBase,
    healthDecay: 1,
    queueCapacity: model.queueCapacity,
    materialWaste: config.materials.wasteFactor,
    energy: model.energy,
  };
  for (const id of printer.upgrades) {
    const up = config.upgrades.find((u) => u.id === id);
    if (!up) continue;
    const e = up.effects;
    if (e.speed) out.speed *= 1 + e.speed;
    if (e.quality) out.quality += e.quality;
    if (e.failure) out.failureBase *= 1 + e.failure;
    if (e.healthDecay) out.healthDecay *= 1 + e.healthDecay;
    if (e.queueCapacity) out.queueCapacity += e.queueCapacity;
    if (e.materialWaste) out.materialWaste *= 1 + e.materialWaste;
  }
  out.speed = Math.max(0.15, out.speed);
  out.failureBase = Math.max(0, out.failureBase);
  out.materialWaste = Math.max(0, out.materialWaste);
  return out;
}

/** Milliseconds to print `qty` units of `productId` on this machine. */
export function estimateDuration(
  config: GameConfig,
  printer: Printer,
  productId: string,
  qty: number,
  materialId: string,
): number {
  const p = product(config, productId);
  const m = material(config, materialId);
  const eff = effectiveStats(config, printer);
  return Math.max(1000, Math.round(p.minutes * 60_000 * qty * eff.speed * m.timeFactor));
}

/** Grams consumed for `qty` units, including purge waste. */
export function estimateGrams(
  config: GameConfig,
  printer: Printer,
  productId: string,
  qty: number,
): number {
  const p = product(config, productId);
  const eff = effectiveStats(config, printer);
  return Math.ceil(p.grams * qty * (1 + eff.materialWaste));
}

/** Grams of a given material+colour on hand across every spool. */
export function availableGrams(spools: Spool[], materialId: string, colorId?: string): number {
  return spools
    .filter((s) => s.materialId === materialId && (!colorId || s.colorId === colorId))
    .reduce((sum, s) => sum + s.grams, 0);
}

/** 0..1 progress of a running job at time `now`. */
export function jobProgress(job: Job, now: number): number {
  if (job.status === 'done' || job.status === 'collected') return 1;
  if (job.startedAt == null) return 0;
  if (job.durationMs <= 0) return 1;
  if (job.status === 'failed') return job.failedAt ?? 0;
  return Math.max(0, Math.min(1, (now - job.startedAt) / job.durationMs));
}

/** Milliseconds left on a running job, floored at zero. */
export function jobRemaining(job: Job, now: number): number {
  if (job.startedAt == null) return job.durationMs;
  return Math.max(0, job.startedAt + job.durationMs - now);
}

/** Total resale/rebuild value of the farm — the leaderboard's "Farm Value". */
export function farmValue(config: GameConfig, printers: Printer[], spools: Spool[], coins: number): number {
  let value = coins;
  for (const p of printers) {
    const model = printerModel(config, p.modelId);
    value += Math.round(model.price * model.resaleFactor * (0.5 + (p.health / 100) * 0.5));
  }
  for (const s of spools) {
    const m = config.catalogs.materials.find((x) => x.id === s.materialId);
    if (m) value += Math.round((s.grams / m.spoolSize) * m.pricePerSpool * 0.6);
  }
  return Math.round(value);
}
