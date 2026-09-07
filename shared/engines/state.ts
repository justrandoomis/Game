/** Creating a brand-new farm, and forward-migrating older saves. */

import type { GameConfig } from '../config/gameConfig';
import type { FarmState, Printer, Spool } from '../types';
import { buildRoomSlots } from '../grid';
import { farmValue } from './derive';

export const SAVE_VERSION = 1;

/** Sequential, collision-free entity id. */
export function nextId(state: FarmState, prefix: string): string {
  state.idSeq += 1;
  return `${prefix}_${state.idSeq.toString(36)}`;
}

/** The starting workshop: one A1 mini, one spool of PLA, one open station. */
export function createInitialState(config: GameConfig, now: number, seed: number): FarmState {
  const tier = config.workshop.tiers[0];
  const slots = buildRoomSlots({ rows: tier.rows, cols: tier.cols });
  const unlocked = slots.slice(0, Math.max(1, config.start.unlockedSlots)).map((s) => s.id);

  const state: FarmState = {
    v: SAVE_VERSION,
    createdAt: now,
    lastResolvedAt: now,
    tier: 0,
    level: config.start.level,
    xp: config.start.xp,
    coins: config.start.coins,
    reputation: config.start.reputation,
    unlockedSlots: unlocked,
    printers: [],
    spools: [],
    jobs: [],
    orders: [],
    storeStock: {},
    demand: {},
    parts: {},
    stats: {
      ordersCompleted: 0,
      ordersFailed: 0,
      ordersLate: 0,
      printsCompleted: 0,
      printsFailed: 0,
      coinsEarned: 0,
      coinsSpent: 0,
      gramsPrinted: 0,
      storeSales: 0,
    },
    achievements: [],
    seed,
    idSeq: 0,
    lastOrderSpawnAt: now,
    lastDemandShiftAt: now,
    lastStoreSaleAt: now,
    tutorialStep: 0,
    log: [],
  };

  const printer: Printer = {
    id: nextId(state, 'pr'),
    modelId: config.start.printerModelId,
    slotId: unlocked[0] ?? null,
    health: 100,
    status: 'idle',
    queue: [],
    hours: 0,
    prints: 0,
    upgrades: [],
    purchasedAt: now,
  };
  state.printers.push(printer);

  for (const s of config.start.spools) {
    const mat = config.catalogs.materials.find((m) => m.id === s.materialId);
    const spool: Spool = {
      id: nextId(state, 'sp'),
      materialId: s.materialId,
      colorId: s.colorId,
      grams: s.grams,
      capacity: s.grams,
      quality: mat?.baseQuality ?? 70,
    };
    state.spools.push(spool);
  }

  for (const p of config.catalogs.products) state.demand[p.id] = 1;

  return state;
}

/** Bring an older save forward. Called on every load. */
export function migrateState(config: GameConfig, raw: FarmState): FarmState {
  const state = raw as FarmState;
  if (typeof state.idSeq !== 'number') {
    state.idSeq = state.printers.length + state.spools.length + state.jobs.length + state.orders.length + 10;
  }
  if (!state.demand) state.demand = {};
  for (const p of config.catalogs.products) {
    if (state.demand[p.id] == null) state.demand[p.id] = 1;
  }
  if (!state.storeStock) state.storeStock = {};
  if (!state.parts) state.parts = {};
  if (!state.achievements) state.achievements = [];
  if (!state.log) state.log = [];
  if (typeof state.tutorialStep !== 'number') state.tutorialStep = 0;
  state.v = SAVE_VERSION;
  return state;
}

/** Aggregates the leaderboard and the HUD read. */
export function summarize(config: GameConfig, state: FarmState) {
  return {
    level: state.level,
    xp: state.xp,
    coins: state.coins,
    reputation: state.reputation,
    printers: state.printers.length,
    ordersCompleted: state.stats.ordersCompleted,
    farmValue: farmValue(config, state.printers, state.spools, state.coins),
    failureRate:
      state.stats.printsCompleted + state.stats.printsFailed > 0
        ? state.stats.printsFailed / (state.stats.printsCompleted + state.stats.printsFailed)
        : 0,
  };
}
