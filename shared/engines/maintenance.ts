/** Machine health: how it wears down and how the bench brings it back. */

import type { GameConfig } from '../config/gameConfig';
import type { FarmState, Printer } from '../types';
import { effectiveStats, printerModel } from './derive';

export type HealthBand = 'good' | 'service' | 'warning' | 'critical';

export function healthBand(config: GameConfig, health: number): HealthBand {
  const t = config.maintenance.thresholds;
  if (health <= t.critical) return 'critical';
  if (health <= t.warning) return 'warning';
  if (health <= t.service) return 'service';
  return 'good';
}

/**
 * Health lost by running for `printMs`. Reliable machines and the service-kit
 * upgrade slow this down; it is the only thing that consumes health passively.
 */
export function decayForRuntime(config: GameConfig, printer: Printer, printMs: number): number {
  const model = printerModel(config, printer.modelId);
  const eff = effectiveStats(config, printer);
  const hours = printMs / 3_600_000;
  const reliabilityFactor = 1.4 - model.reliability / 100; // 0.44 .. 1.4
  return hours * config.maintenance.healthDecayPerHour * reliabilityFactor * eff.healthDecay;
}

export function applyDecay(config: GameConfig, printer: Printer, printMs: number): void {
  printer.hours += printMs / 3_600_000;
  printer.health = Math.max(0, Math.round((printer.health - decayForRuntime(config, printer, printMs)) * 10) / 10);
}

/** Service actions the player has unlocked. */
export function availableActions(config: GameConfig, level: number) {
  return config.maintenance.actions.filter((a) => level >= a.minLevel);
}

/** True once the machine has run past its recommended service interval. */
export function needsService(config: GameConfig, printer: Printer): boolean {
  const model = printerModel(config, printer.modelId);
  return printer.health <= config.maintenance.thresholds.service || printer.hours >= model.maintenanceHours;
}

/** Machines a technician (or the player) should look at, worst first. */
export function serviceQueue(config: GameConfig, state: FarmState): Printer[] {
  return state.printers
    .filter((p) => needsService(config, p) || p.status === 'failed')
    .sort((a, b) => a.health - b.health);
}
