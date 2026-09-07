/** XP, levels and what each level opens up. */

import type { GameConfig } from '../config/gameConfig';
import { xpForLevel } from '../config/gameConfig';
import type { FarmState } from '../types';

export interface LevelResult {
  leveledUp: boolean;
  from: number;
  to: number;
  unlocked: string[];
}

/** Grant XP and roll the level forward as far as it goes. Mutates `state`. */
export function grantXp(config: GameConfig, state: FarmState, amount: number): LevelResult {
  const from = state.level;
  state.xp += Math.max(0, Math.round(amount));

  let guard = 0;
  while (state.level < config.progression.maxLevel && guard++ < 200) {
    const need = xpForLevel(config, state.level);
    if (state.xp < need) break;
    state.xp -= need;
    state.level += 1;
  }

  const unlocked: string[] = [];
  for (let lvl = from + 1; lvl <= state.level; lvl++) {
    const keys = config.progression.unlocks[lvl];
    if (keys) unlocked.push(...keys);
  }
  return { leveledUp: state.level > from, from, to: state.level, unlocked };
}

/** Progress toward the next level, for the HUD bar. */
export function levelProgress(config: GameConfig, state: FarmState): { current: number; needed: number; pct: number } {
  const needed = xpForLevel(config, state.level);
  return {
    current: state.xp,
    needed,
    pct: needed > 0 ? Math.max(0, Math.min(1, state.xp / needed)) : 1,
  };
}

/** XP awarded for finishing a job — scales with the work actually done. */
export function xpForJob(grams: number, complexity: number): number {
  return Math.max(1, Math.round(grams * 0.35 + complexity * 4));
}

/** XP awarded for delivering an order on time. */
export function xpForOrder(reward: number, onTime: boolean): number {
  return Math.max(2, Math.round((reward / 22) * (onTime ? 1 : 0.5)));
}
