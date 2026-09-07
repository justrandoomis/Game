/**
 * PLAYER INTENTS.
 *
 * The client never sends amounts, prices or outcomes — only what it wants to
 * do. Every function here re-derives the cost from config, checks the player
 * can afford and is allowed it, then mutates state. The server is the only
 * caller; the client uses the same `can*` predicates purely to grey out
 * buttons.
 */

import type { GameConfig } from '../config/gameConfig';
import type { FarmState, Job, Order, Printer } from '../types';
import { buildRoomSlots, type SlotDef } from '../grid';
import {
  effectiveStats,
  estimateDuration,
  estimateGrams,
  material,
  printerModel,
  product,
} from './derive';
import { printerResale, slotCost, slotLevel, spoolPrice } from './economy';
import { pickSpool, refund, reserve, stockCheck, addSpool } from './inventory';
import { planAssignment, acceptedCapacity, orderDeadlineMs } from './jobEngine';
import { applyReputation } from './reputation';
import { availableActions } from './maintenance';
import { nextId } from './state';
import { appendLog, deliverOrder, startNextJob } from './resolve';

export interface IntentResult {
  ok: boolean;
  error?: string;
  /** Small hints the client turns into toasts and FX. */
  fx?: { kind: string; value?: number; at?: string };
}

const fail = (error: string): IntentResult => ({ ok: false, error });
const done = (fx?: IntentResult['fx']): IntentResult => ({ ok: true, fx });

/* ------------------------------------------------------------------ slots */

export function currentRoom(config: GameConfig, state: FarmState) {
  const tier = config.workshop.tiers[Math.min(state.tier, config.workshop.tiers.length - 1)];
  return { tier, rows: tier.rows, cols: tier.cols };
}

export function roomSlots(config: GameConfig, state: FarmState): SlotDef[] {
  const { rows, cols } = currentRoom(config, state);
  return buildRoomSlots({ rows, cols });
}

/** The next slot the player may buy, or null when the room is full. */
export function nextLockedSlot(config: GameConfig, state: FarmState): SlotDef | null {
  const slots = roomSlots(config, state);
  const { tier } = currentRoom(config, state);
  if (state.unlockedSlots.length >= tier.slots) return null;
  return slots.find((s) => !state.unlockedSlots.includes(s.id)) ?? null;
}

export function unlockSlotCost(config: GameConfig, state: FarmState): number {
  return slotCost(config, state.unlockedSlots.length);
}

export function unlockSlotLevel(config: GameConfig, state: FarmState): number {
  return slotLevel(config, state.unlockedSlots.length);
}

export function unlockSlot(config: GameConfig, state: FarmState, now: number, slotId: string): IntentResult {
  const target = nextLockedSlot(config, state);
  if (!target) return fail('workshop_full');
  if (target.id !== slotId) return fail('unlock_in_order');
  const cost = unlockSlotCost(config, state);
  const level = unlockSlotLevel(config, state);
  if (state.level < level) return fail('level_too_low');
  if (state.coins < cost) return fail('not_enough_coins');

  state.coins -= cost;
  state.stats.coinsSpent += cost;
  state.unlockedSlots.push(target.id);
  appendLog(state, now, 'slot_unlocked', 'slotUnlocked', { slot: target.id });
  return done({ kind: 'slot_unlocked', at: target.id });
}

export function nextTier(config: GameConfig, state: FarmState) {
  return config.workshop.tiers[state.tier + 1] ?? null;
}

export function expandWorkshop(config: GameConfig, state: FarmState, now: number): IntentResult {
  const tier = nextTier(config, state);
  if (!tier) return fail('max_tier');
  const current = config.workshop.tiers[state.tier];
  if (state.unlockedSlots.length < current.slots) return fail('fill_current_room');
  if (state.level < tier.unlockLevel) return fail('level_too_low');
  if (state.coins < tier.cost) return fail('not_enough_coins');

  state.coins -= tier.cost;
  state.stats.coinsSpent += tier.cost;
  state.tier += 1;
  appendLog(state, now, 'workshop_expanded', 'workshopExpanded', { tier: tier.name });
  return done({ kind: 'workshop_expanded' });
}

/* --------------------------------------------------------------- printers */

export function buyPrinter(
  config: GameConfig,
  state: FarmState,
  now: number,
  modelId: string,
  slotId: string,
): IntentResult {
  const model = config.catalogs.printers.find((p) => p.id === modelId);
  if (!model) return fail('unknown_model');
  if (state.level < model.unlockLevel) return fail('level_too_low');
  if (state.coins < model.price) return fail('not_enough_coins');
  if (!state.unlockedSlots.includes(slotId)) return fail('slot_locked');
  if (state.printers.some((p) => p.slotId === slotId)) return fail('slot_occupied');

  // A multi-cell machine needs its whole footprint unlocked and clear.
  const slots = roomSlots(config, state);
  const base = slots.find((s) => s.id === slotId);
  if (!base) return fail('unknown_slot');
  const { cols, rows } = currentRoom(config, state);
  if (base.col + model.footprint.w > cols || base.row + model.footprint.h > rows) {
    return fail('no_room_for_machine');
  }
  for (let r = base.row; r < base.row + model.footprint.h; r++) {
    for (let c = base.col; c < base.col + model.footprint.w; c++) {
      const id = `s_${r}_${c}`;
      if (!state.unlockedSlots.includes(id)) return fail('footprint_locked');
      if (state.printers.some((p) => p.slotId === id)) return fail('footprint_occupied');
    }
  }

  state.coins -= model.price;
  state.stats.coinsSpent += model.price;
  const printer: Printer = {
    id: nextId(state, 'pr'),
    modelId,
    slotId,
    health: 100,
    status: 'idle',
    queue: [],
    hours: 0,
    prints: 0,
    upgrades: [],
    purchasedAt: now,
  };
  state.printers.push(printer);
  appendLog(state, now, 'printer_bought', 'printerBought', { model: model.name });
  return done({ kind: 'printer_delivered', at: slotId });
}

export function sellPrinter(config: GameConfig, state: FarmState, now: number, printerId: string): IntentResult {
  const printer = state.printers.find((p) => p.id === printerId);
  if (!printer) return fail('unknown_printer');
  if (state.printers.length <= 1) return fail('last_printer');
  if (printer.queue.length) return fail('printer_busy');

  const value = printerResale(config, printer);
  state.coins += value;
  state.printers = state.printers.filter((p) => p.id !== printerId);
  appendLog(state, now, 'printer_sold', 'printerSold', { coins: value });
  return done({ kind: 'coins', value });
}

export function movePrinter(config: GameConfig, state: FarmState, printerId: string, slotId: string): IntentResult {
  const printer = state.printers.find((p) => p.id === printerId);
  if (!printer) return fail('unknown_printer');
  if (!state.unlockedSlots.includes(slotId)) return fail('slot_locked');
  if (state.printers.some((p) => p.slotId === slotId)) return fail('slot_occupied');
  if (printer.status === 'printing') return fail('printer_busy');
  printer.slotId = slotId;
  return done();
}

export function buyUpgrade(
  config: GameConfig,
  state: FarmState,
  now: number,
  printerId: string,
  upgradeId: string,
): IntentResult {
  const printer = state.printers.find((p) => p.id === printerId);
  if (!printer) return fail('unknown_printer');
  const upgrade = config.upgrades.find((u) => u.id === upgradeId);
  if (!upgrade) return fail('unknown_upgrade');
  if (state.level < upgrade.unlockLevel) return fail('level_too_low');
  if (printer.upgrades.includes(upgradeId)) return fail('already_installed');
  const model = printerModel(config, printer.modelId);
  if (printer.upgrades.length >= model.upgradeSlots) return fail('no_upgrade_slots');
  if (state.coins < upgrade.price) return fail('not_enough_coins');

  state.coins -= upgrade.price;
  state.stats.coinsSpent += upgrade.price;
  printer.upgrades.push(upgradeId);
  appendLog(state, now, 'upgrade_installed', 'upgradeInstalled', { name: upgrade.name });
  return done({ kind: 'upgrade', at: printer.id });
}

/* ------------------------------------------------------------- filament */

export function buySpool(
  config: GameConfig,
  state: FarmState,
  now: number,
  materialId: string,
  colorId: string,
  count = 1,
): IntentResult {
  const mat = config.catalogs.materials.find((m) => m.id === materialId);
  if (!mat) return fail('unknown_material');
  if (state.level < mat.unlockLevel) return fail('level_too_low');
  if (!config.catalogs.colors.some((c) => c.id === colorId)) return fail('unknown_color');
  const qty = Math.max(1, Math.min(10, Math.floor(count)));
  const cost = spoolPrice(config, materialId) * qty;
  if (state.coins < cost) return fail('not_enough_coins');

  state.coins -= cost;
  state.stats.coinsSpent += cost;
  for (let i = 0; i < qty; i++) {
    addSpool(state, nextId(state, 'sp'), materialId, colorId, mat.spoolSize, mat.baseQuality);
  }
  appendLog(state, now, 'spool_bought', 'spoolBought', { material: mat.name, qty });
  return done({ kind: 'spool_added' });
}

export function buyPart(config: GameConfig, state: FarmState, partId: string, count = 1): IntentResult {
  const part = config.maintenance.parts.find((p) => p.id === partId);
  if (!part) return fail('unknown_part');
  if (state.level < part.unlockLevel) return fail('level_too_low');
  const qty = Math.max(1, Math.min(20, Math.floor(count)));
  const cost = part.price * qty;
  if (state.coins < cost) return fail('not_enough_coins');
  state.coins -= cost;
  state.stats.coinsSpent += cost;
  state.parts[partId] = (state.parts[partId] ?? 0) + qty;
  return done();
}

/* ---------------------------------------------------------------- orders */

export function acceptOrder(config: GameConfig, state: FarmState, now: number, orderId: string): IntentResult {
  const order = state.orders.find((o) => o.id === orderId);
  if (!order) return fail('unknown_order');
  if (order.status !== 'offered') return fail('order_unavailable');
  if (now > order.expiresAt) return fail('order_expired');

  const active = state.orders.filter((o) => ['accepted', 'in_progress', 'ready'].includes(o.status)).length;
  if (active >= acceptedCapacity(config, state)) return fail('too_many_orders');

  order.status = 'accepted';
  order.acceptedAt = now;
  order.dueAt = now + orderDeadlineMs(config, order);
  appendLog(state, now, 'order_accepted', 'orderAccepted', { customer: order.customerName });
  return done({ kind: 'order_accepted' });
}

export function rejectOrder(config: GameConfig, state: FarmState, orderId: string): IntentResult {
  const order = state.orders.find((o) => o.id === orderId);
  if (!order) return fail('unknown_order');
  if (order.status !== 'offered') return fail('order_unavailable');
  order.status = 'rejected';
  applyReputation(config, state, -config.reputation.rejectLoss);
  return done();
}

/** Printers that can take this order right now. */
export function eligiblePrinters(config: GameConfig, state: FarmState, order: Order): Printer[] {
  const prod = product(config, order.productId);
  return state.printers.filter((p) => {
    if (p.status === 'failed' || p.status === 'maintenance' || p.status === 'offline') return false;
    const model = printerModel(config, p.modelId);
    if (!model.materials.includes(order.materialId)) return false;
    if (prod.multicolor && !model.multicolor) return false;
    const eff = effectiveStats(config, p);
    return p.queue.length < eff.queueCapacity;
  });
}

/**
 * Put an accepted order into production, optionally split across machines.
 * Filament is reserved up front so two orders can't spend the same grams.
 */
export function assignOrder(
  config: GameConfig,
  state: FarmState,
  now: number,
  orderId: string,
  printerIds: string[],
): IntentResult {
  const order = state.orders.find((o) => o.id === orderId);
  if (!order) return fail('unknown_order');
  if (order.status !== 'accepted') return fail('order_not_accepted');
  if (!printerIds.length) return fail('no_printer_selected');

  const printers = printerIds
    .map((id) => state.printers.find((p) => p.id === id))
    .filter((p): p is Printer => !!p);
  if (printers.length !== printerIds.length) return fail('unknown_printer');

  const allowed = new Set(eligiblePrinters(config, state, order).map((p) => p.id));
  for (const p of printers) if (!allowed.has(p.id)) return fail('printer_unavailable');

  const plan = planAssignment(config, order, printers);
  if (!plan.length) return fail('assignment_failed');

  const totalGrams = plan.reduce((sum, a) => sum + a.grams, 0);
  const stock = stockCheck(state.spools, order.materialId, order.colorId, totalGrams);
  if (!stock.ok) return { ok: false, error: 'not_enough_filament', fx: { kind: 'missing', value: stock.missing } };

  const created: Job[] = [];
  for (const a of plan) {
    const spool = pickSpool(state.spools, order.materialId, order.colorId, a.grams);
    if (!spool) {
      // Roll back anything already reserved so a partial failure costs nothing.
      for (const j of created) refund(state, j.spoolId, j.grams);
      return { ok: false, error: 'not_enough_filament', fx: { kind: 'missing', value: a.grams } };
    }
    if (!reserve(state, spool.id, a.grams)) {
      for (const j of created) refund(state, j.spoolId, j.grams);
      return fail('reserve_failed');
    }
    const job: Job = {
      id: nextId(state, 'job'),
      orderId: order.id,
      productId: order.productId,
      qty: a.qty,
      printerId: a.printerId,
      materialId: order.materialId,
      colorId: order.colorId,
      spoolId: spool.id,
      grams: a.grams,
      durationMs: a.durationMs,
      startedAt: null,
      status: 'queued',
    };
    created.push(job);
  }

  for (const job of created) {
    state.jobs.push(job);
    order.jobIds.push(job.id);
    const printer = state.printers.find((p) => p.id === job.printerId)!;
    printer.queue.push(job.id);
    startNextJob(state, printer, now);
  }

  order.status = 'in_progress';
  appendLog(state, now, 'order_started', 'orderStarted', { customer: order.customerName });
  return done({ kind: 'job_started' });
}

export function collectOrder(config: GameConfig, state: FarmState, now: number, orderId: string): IntentResult {
  const order = state.orders.find((o) => o.id === orderId);
  if (!order) return fail('unknown_order');
  if (order.status !== 'ready') return fail('order_not_ready');
  const payout = deliverOrder(config, state, order, now);
  return done({ kind: 'coins', value: payout });
}

/* ------------------------------------------------------- store production */

export function startStoreJob(
  config: GameConfig,
  state: FarmState,
  now: number,
  printerId: string,
  productId: string,
  qty: number,
  materialId: string,
  colorId: string,
): IntentResult {
  const printer = state.printers.find((p) => p.id === printerId);
  if (!printer) return fail('unknown_printer');
  if (printer.status === 'failed' || printer.status === 'maintenance') return fail('printer_unavailable');

  const prod = config.catalogs.products.find((p) => p.id === productId);
  if (!prod) return fail('unknown_product');
  if (state.level < prod.unlockLevel) return fail('level_too_low');

  const model = printerModel(config, printer.modelId);
  if (!model.materials.includes(materialId)) return fail('material_unsupported');
  if (prod.multicolor && !model.multicolor) return fail('needs_multicolor');
  if (!prod.materials.includes(materialId)) return fail('material_unsupported');

  const eff = effectiveStats(config, printer);
  if (printer.queue.length >= eff.queueCapacity) return fail('queue_full');

  const units = Math.max(1, Math.min(200, Math.floor(qty)));
  const grams = estimateGrams(config, printer, productId, units);
  const spool = pickSpool(state.spools, materialId, colorId, grams);
  if (!spool) {
    const stock = stockCheck(state.spools, materialId, colorId, grams);
    return { ok: false, error: 'not_enough_filament', fx: { kind: 'missing', value: stock.missing } };
  }
  if (!reserve(state, spool.id, grams)) return fail('reserve_failed');

  const job: Job = {
    id: nextId(state, 'job'),
    orderId: null,
    productId,
    qty: units,
    printerId,
    materialId,
    colorId,
    spoolId: spool.id,
    grams,
    durationMs: estimateDuration(config, printer, productId, units, materialId),
    startedAt: null,
    status: 'queued',
  };
  state.jobs.push(job);
  printer.queue.push(job.id);
  startNextJob(state, printer, now);
  return done({ kind: 'job_started', at: printer.slotId ?? undefined });
}

export function cancelJob(config: GameConfig, state: FarmState, now: number, jobId: string): IntentResult {
  const job = state.jobs.find((j) => j.id === jobId);
  if (!job) return fail('unknown_job');
  if (job.status === 'done' || job.status === 'collected') return fail('job_finished');
  const printer = state.printers.find((p) => p.id === job.printerId);

  // Queued work refunds in full; a running print only gives back what is left.
  const spent = job.status === 'printing' && job.startedAt != null
    ? Math.min(1, (now - job.startedAt) / Math.max(1, job.durationMs))
    : 0;
  refund(state, job.spoolId, Math.round(job.grams * (1 - spent)));

  state.jobs = state.jobs.filter((j) => j.id !== jobId);
  if (printer) {
    printer.queue = printer.queue.filter((q) => q !== jobId);
    if (printer.status === 'printing') printer.status = 'idle';
    startNextJob(state, printer, now);
  }
  const order = job.orderId ? state.orders.find((o) => o.id === job.orderId) : null;
  if (order) order.jobIds = order.jobIds.filter((id) => id !== jobId);
  return done();
}

export function reorderQueue(state: FarmState, printerId: string, jobIds: string[]): IntentResult {
  const printer = state.printers.find((p) => p.id === printerId);
  if (!printer) return fail('unknown_printer');
  const current = new Set(printer.queue);
  if (jobIds.length !== printer.queue.length || jobIds.some((id) => !current.has(id))) {
    return fail('queue_mismatch');
  }
  // The head is already printing — it cannot be reshuffled underneath itself.
  const head = printer.queue[0];
  const activeJob = state.jobs.find((j) => j.id === head);
  if (activeJob?.status === 'printing' && jobIds[0] !== head) return fail('active_job_locked');
  printer.queue = jobIds;
  return done();
}

/* ----------------------------------------------------------- maintenance */

export function serviceprinter(
  config: GameConfig,
  state: FarmState,
  now: number,
  printerId: string,
  actionId: string,
): IntentResult {
  const printer = state.printers.find((p) => p.id === printerId);
  if (!printer) return fail('unknown_printer');
  if (printer.status === 'maintenance') return fail('already_servicing');
  if (printer.status === 'printing') return fail('printer_busy');

  const action = availableActions(config, state.level).find((a) => a.id === actionId);
  if (!action) return fail('action_locked');
  if (state.coins < action.cost) return fail('not_enough_coins');
  if (action.partId && (state.parts[action.partId] ?? 0) < 1) return fail('missing_part');

  state.coins -= action.cost;
  state.stats.coinsSpent += action.cost;
  if (action.partId) state.parts[action.partId] = (state.parts[action.partId] ?? 0) - 1;

  printer.status = 'maintenance';
  printer.maintenanceUntil = now + action.durationMs;
  printer.health = Math.min(100, printer.health + action.restores);
  if (action.id === 'overhaul') printer.hours = 0;
  appendLog(state, now, 'maintenance_started', 'maintenanceStarted', { printer: printer.id, action: action.name });
  return done({ kind: 'maintenance', at: printer.slotId ?? undefined });
}

/** Clear a failed print so the machine can work again. */
export function clearFailure(config: GameConfig, state: FarmState, now: number, printerId: string): IntentResult {
  const printer = state.printers.find((p) => p.id === printerId);
  if (!printer) return fail('unknown_printer');
  if (printer.status !== 'failed') return fail('nothing_to_clear');

  const failed = state.jobs.filter((j) => j.printerId === printerId && j.status === 'failed');
  for (const job of failed) {
    state.jobs = state.jobs.filter((j) => j.id !== job.id);
    printer.queue = printer.queue.filter((q) => q !== job.id);
    const order = job.orderId ? state.orders.find((o) => o.id === job.orderId) : null;
    if (order) {
      order.jobIds = order.jobIds.filter((id) => id !== job.id);
      // The order still stands — the player can re-assign what was lost.
      if (order.status === 'in_progress' && order.jobIds.length === 0) order.status = 'accepted';
    }
  }
  printer.status = 'idle';
  startNextJob(state, printer, now);
  return done({ kind: 'cleared', at: printer.slotId ?? undefined });
}

/** Repair a machine that has been run into the ground. */
export function repairPrinter(config: GameConfig, state: FarmState, now: number, printerId: string): IntentResult {
  const printer = state.printers.find((p) => p.id === printerId);
  if (!printer) return fail('unknown_printer');
  const model = printerModel(config, printer.modelId);
  if (state.coins < model.repairCost) return fail('not_enough_coins');
  if (printer.health >= 99) return fail('already_healthy');

  state.coins -= model.repairCost;
  state.stats.coinsSpent += model.repairCost;
  printer.health = 100;
  printer.hours = 0;
  if (printer.status === 'failed') printer.status = 'idle';
  printer.status = 'maintenance';
  printer.maintenanceUntil = now + 15 * 60_000;
  appendLog(state, now, 'printer_repaired', 'printerRepaired', { printer: printer.id });
  return done({ kind: 'maintenance', at: printer.slotId ?? undefined });
}

export function advanceTutorial(state: FarmState, step: number): IntentResult {
  state.tutorialStep = Math.max(state.tutorialStep, Math.floor(step));
  return done();
}
