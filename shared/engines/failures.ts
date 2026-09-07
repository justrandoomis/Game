/**
 * Failure model.
 *
 * Failures are never a coin flip. Probability is driven by machine health,
 * the machine's own reliability, material difficulty, part complexity, spool
 * quality and installed upgrades — so looking after the farm visibly pays off.
 */

import type { GameConfig } from '../config/gameConfig';
import type { FailureKind, Printer, Spool } from '../types';
import { effectiveStats, material, product, printerModel } from './derive';
import { rngFor } from './rng';

export interface FailureContext {
  printer: Printer;
  productId: string;
  materialId: string;
  spoolQuality: number;
}

/** Probability in [0, 0.85] that a given print fails. */
export function failureProbability(config: GameConfig, ctx: FailureContext): number {
  const eff = effectiveStats(config, ctx.printer);
  const model = printerModel(config, ctx.printer.modelId);
  const mat = material(config, ctx.materialId);
  const prod = product(config, ctx.productId);
  const f = config.failures;

  // Health is the dominant term: a neglected machine fails often.
  const healthDeficit = 1 - Math.max(0, Math.min(100, ctx.printer.health)) / 100;
  const reliability = 1 - model.reliability / 200; // 0.5 .. 1.0

  let p = eff.failureBase * f.globalFactor * reliability;
  p += healthDeficit * healthDeficit * f.healthWeight;
  p += (prod.complexity - 1) * f.complexityWeight;
  p += mat.difficulty;

  // Better machines and better filament pull it back down.
  const qualityGuard = (eff.quality / 100) * 0.35 + (ctx.spoolQuality / 100) * 0.15;
  p *= Math.max(0.25, 1 - qualityGuard);

  return Math.max(0, Math.min(0.85, p));
}

const RUNTIME_KINDS: FailureKind[] = [
  'spaghetti',
  'clogged_nozzle',
  'part_detached',
  'ams_jam',
  'mechanical',
];

/**
 * Deterministic outcome for one job. Keyed by job id, so re-resolving the
 * same state always yields the same verdict.
 */
export function rollFailure(
  config: GameConfig,
  jobId: string,
  ctx: FailureContext,
): { failed: boolean; kind?: FailureKind; at?: number } {
  const p = failureProbability(config, ctx);
  const rng = rngFor('fail', jobId);
  if (rng.next() >= p) return { failed: false };

  // Where in the print it went wrong shapes which failure it reads as.
  const at = rng.float(0.02, 0.95);
  let kind: FailureKind;
  if (at < 0.12) {
    kind = 'first_layer';
  } else if (ctx.printer.health < config.maintenance.thresholds.warning && rng.next() < 0.5) {
    kind = 'mechanical';
  } else {
    kind = rng.pick(RUNTIME_KINDS);
  }
  return { failed: true, kind, at };
}

/** Whether a spool can even cover the job — runouts are checked, not rolled. */
export function willRunOut(spool: Spool | undefined, grams: number): boolean {
  return !spool || spool.grams < grams;
}
