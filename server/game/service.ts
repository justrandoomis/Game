/**
 * Game service — load, resolve, mutate, save.
 *
 * Every request follows the same shape: read the save, replay everything that
 * fell due while the player was away, apply the requested intent, persist,
 * and hand back a fresh snapshot with the server's own clock. The client never
 * supplies a timestamp and never supplies an amount.
 */

import { DEFAULT_CONFIG, mergeConfig, type GameConfig } from '../../shared/config/gameConfig';
import type { AwayReport, FarmState, FarmSnapshot } from '../../shared/types';
import { createInitialState, migrateState, summarize } from '../../shared/engines/state';
import { resolveFarm } from '../../shared/engines/resolve';
import * as intents from '../../shared/engines/intents';
import { getStore, type GameStore } from '../store';

let cachedConfig: { at: number; config: GameConfig } | null = null;
const CONFIG_TTL_MS = 30_000;

/** Defaults with the admin's balancing overrides merged on top. */
export async function loadConfig(force = false): Promise<GameConfig> {
  const now = Date.now();
  if (!force && cachedConfig && now - cachedConfig.at < CONFIG_TTL_MS) return cachedConfig.config;
  const store = await getStore();
  const overrides = await store.getConfigOverrides();
  const config = mergeConfig(DEFAULT_CONFIG, overrides);
  cachedConfig = { at: now, config };
  return config;
}

export function invalidateConfig() {
  cachedConfig = null;
}

async function persist(store: GameStore, config: GameConfig, userId: string, state: FarmState) {
  const summary = summarize(config, state);
  await store.saveFarm({
    userId,
    state: JSON.stringify(state),
    level: summary.level,
    coins: Math.round(summary.coins),
    reputation: summary.reputation,
    farmValue: summary.farmValue,
    ordersCompleted: summary.ordersCompleted,
    updatedAt: Date.now(),
  });
}

/** Load (or create) a farm and bring it up to date. */
export async function loadFarm(userId: string): Promise<{ config: GameConfig; state: FarmState; report: AwayReport; created: boolean }> {
  const store = await getStore();
  const config = await loadConfig();
  const now = Date.now();

  const row = await store.getFarm(userId);
  let state: FarmState;
  let created = false;

  if (row) {
    try {
      state = migrateState(config, JSON.parse(row.state) as FarmState);
    } catch {
      state = createInitialState(config, now, hashUser(userId));
      created = true;
    }
  } else {
    state = createInitialState(config, now, hashUser(userId));
    created = true;
  }

  const { report } = resolveFarm(config, state, now);
  await persist(store, config, userId, state);
  return { config, state, report, created };
}

function hashUser(userId: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < userId.length; i++) {
    h ^= userId.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

export function snapshot(state: FarmState, report?: AwayReport): FarmSnapshot {
  return { state, serverNow: Date.now(), report };
}

export type IntentName =
  | 'accept_order'
  | 'reject_order'
  | 'assign_order'
  | 'collect_order'
  | 'start_store_job'
  | 'cancel_job'
  | 'reorder_queue'
  | 'clear_failure'
  | 'service_printer'
  | 'repair_printer'
  | 'buy_spool'
  | 'buy_part'
  | 'buy_printer'
  | 'sell_printer'
  | 'move_printer'
  | 'buy_upgrade'
  | 'unlock_slot'
  | 'expand_workshop'
  | 'advance_tutorial';

const str = (v: unknown, fallback = ''): string => (typeof v === 'string' ? v : fallback);
const num = (v: unknown, fallback = 0): number => (typeof v === 'number' && Number.isFinite(v) ? v : fallback);
const strArray = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : []);

/**
 * Apply one intent. Returns the fresh snapshot on success so the client can
 * replace its whole model rather than patching it locally.
 */
export async function applyIntent(
  userId: string,
  intent: IntentName,
  payload: Record<string, unknown>,
): Promise<{ ok: boolean; error?: string; fx?: unknown; snapshot?: FarmSnapshot }> {
  const store = await getStore();
  const { config, state } = await loadFarm(userId);
  const now = Date.now();
  let result: intents.IntentResult;

  switch (intent) {
    case 'accept_order':
      result = intents.acceptOrder(config, state, now, str(payload.orderId));
      break;
    case 'reject_order':
      result = intents.rejectOrder(config, state, str(payload.orderId));
      break;
    case 'assign_order':
      result = intents.assignOrder(config, state, now, str(payload.orderId), strArray(payload.printerIds));
      break;
    case 'collect_order':
      result = intents.collectOrder(config, state, now, str(payload.orderId));
      break;
    case 'start_store_job':
      result = intents.startStoreJob(
        config, state, now,
        str(payload.printerId), str(payload.productId), num(payload.qty, 1),
        str(payload.materialId), str(payload.colorId),
      );
      break;
    case 'cancel_job':
      result = intents.cancelJob(config, state, now, str(payload.jobId));
      break;
    case 'reorder_queue':
      result = intents.reorderQueue(state, str(payload.printerId), strArray(payload.jobIds));
      break;
    case 'clear_failure':
      result = intents.clearFailure(config, state, now, str(payload.printerId));
      break;
    case 'service_printer':
      result = intents.serviceprinter(config, state, now, str(payload.printerId), str(payload.actionId));
      break;
    case 'repair_printer':
      result = intents.repairPrinter(config, state, now, str(payload.printerId));
      break;
    case 'buy_spool':
      result = intents.buySpool(config, state, now, str(payload.materialId), str(payload.colorId), num(payload.count, 1));
      break;
    case 'buy_part':
      result = intents.buyPart(config, state, str(payload.partId), num(payload.count, 1));
      break;
    case 'buy_printer':
      result = intents.buyPrinter(config, state, now, str(payload.modelId), str(payload.slotId));
      break;
    case 'sell_printer':
      result = intents.sellPrinter(config, state, now, str(payload.printerId));
      break;
    case 'move_printer':
      result = intents.movePrinter(config, state, str(payload.printerId), str(payload.slotId));
      break;
    case 'buy_upgrade':
      result = intents.buyUpgrade(config, state, now, str(payload.printerId), str(payload.upgradeId));
      break;
    case 'unlock_slot':
      result = intents.unlockSlot(config, state, now, str(payload.slotId));
      break;
    case 'expand_workshop':
      result = intents.expandWorkshop(config, state, now);
      break;
    case 'advance_tutorial':
      result = intents.advanceTutorial(state, num(payload.step, 0));
      break;
    default:
      result = { ok: false, error: 'unknown_intent' };
  }

  await store.logIntent(userId, intent, payload, result.ok, now);

  if (!result.ok) {
    return { ok: false, error: result.error, fx: result.fx };
  }

  // Re-resolve so anything the intent set in motion (a queue head starting,
  // an order becoming ready) is reflected before the snapshot goes out.
  resolveFarm(config, state, Date.now());
  await persist(store, config, userId, state);
  return { ok: true, fx: result.fx, snapshot: snapshot(state) };
}
