/** Reputation — the gate on which customers will talk to the player. */

import type { GameConfig } from '../config/gameConfig';
import type { CustomerTier, FarmState } from '../types';

export function applyReputation(config: GameConfig, state: FarmState, delta: number): number {
  const next = Math.max(0, Math.min(config.reputation.max, state.reputation + delta));
  state.reputation = Math.round(next * 10) / 10;
  return state.reputation;
}

/** Passive drift back toward the middle so a single bad week isn't permanent. */
export function decayReputation(config: GameConfig, state: FarmState, elapsedMs: number): void {
  const days = elapsedMs / 86_400_000;
  if (days <= 0) return;
  const pull = config.reputation.decayPerDay * days;
  const midpoint = config.reputation.max / 2;
  if (state.reputation > midpoint) {
    applyReputation(config, state, -Math.min(pull, state.reputation - midpoint));
  }
}

/** Star rating out of 5, which is how the HUD shows reputation. */
export function reputationStars(config: GameConfig, reputation: number): number {
  return Math.round((reputation / config.reputation.max) * 5 * 10) / 10;
}

/** Customer tiers currently willing to order from this workshop. */
export function availableTiers(config: GameConfig, state: FarmState): CustomerTier[] {
  return config.orders.tiers
    .filter((t) => state.reputation >= t.minReputation && state.level >= t.minLevel)
    .map((t) => t.id);
}
