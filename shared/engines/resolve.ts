/**
 * AUTHORITATIVE SIMULATION.
 *
 * The farm is never simulated tick-by-tick. Every running thing carries a
 * server timestamp and a duration, and this module replays whatever fell due
 * between `state.lastResolvedAt` and `now` in strict event order. Running it
 * twice over the same window is a no-op, which is what makes offline
 * progression safe to recompute on every request.
 *
 * Only the server calls this. The client renders progress from the same
 * timestamps but never commits an outcome.
 */

import type { GameConfig } from '../config/gameConfig';
import type { AwayReport, FarmState, Job, Order, Printer } from '../types';
import { effectiveStats, jobProgress, product } from './derive';
import { rollFailure } from './failures';
import { applyDecay } from './maintenance';
import { grantXp, xpForJob, xpForOrder } from './progression';
import { applyReputation, decayReputation } from './reputation';
import { generateOrder, acceptedCapacity } from './jobEngine';
import { refund, pruneEmptySpools } from './inventory';
import { storePrice } from './economy';
import { rngFor } from './rng';

/** Ceiling on catch-up ticks for the periodic systems after a long absence. */
const MAX_PERIODIC_TICKS = 48;
/** Hard stop on the event loop so a corrupt state can never hang a request. */
const MAX_EVENTS = 4000;
/** Activity log length kept in the save. */
const LOG_LIMIT = 40;

type EventKind =
  | 'job_end'
  | 'order_due'
  | 'offer_expire'
  | 'auto_deliver'
  | 'maintenance_end'
  | 'spawn'
  | 'store_sale'
  | 'demand_shift';

interface PendingEvent {
  at: number;
  kind: EventKind;
  id?: string;
}

function log(state: FarmState, at: number, kind: string, msg: string, data?: Record<string, string | number>) {
  state.log.push({ at, kind, msg, data });
  if (state.log.length > LOG_LIMIT) state.log.splice(0, state.log.length - LOG_LIMIT);
}

function emptyReport(elapsedMs: number): AwayReport {
  return {
    elapsedMs,
    printsCompleted: 0,
    printsFailed: 0,
    ordersDelivered: 0,
    ordersExpired: 0,
    coinsEarned: 0,
    storeSales: 0,
    newOrders: 0,
    maintenanceNeeded: 0,
  };
}

function findJob(state: FarmState, id: string): Job | undefined {
  return state.jobs.find((j) => j.id === id);
}

function findPrinter(state: FarmState, id: string): Printer | undefined {
  return state.printers.find((p) => p.id === id);
}

/** Start the head of a printer's queue at time `t`, if it is idle and able. */
function startNextJob(state: FarmState, printer: Printer, t: number): void {
  if (printer.status === 'maintenance' || printer.status === 'failed' || printer.status === 'offline') return;
  const nextId = printer.queue[0];
  if (!nextId) {
    printer.status = 'idle';
    return;
  }
  const job = findJob(state, nextId);
  if (!job) {
    printer.queue.shift();
    startNextJob(state, printer, t);
    return;
  }
  if (job.status === 'queued') {
    job.startedAt = t;
    job.status = 'printing';
  }
  printer.status = 'printing';
}

/** Pay out a finished order. Late deliveries pay the reduced rate. */
export function deliverOrder(
  config: GameConfig,
  state: FarmState,
  order: Order,
  t: number,
  report?: AwayReport,
): number {
  const late = !!order.late || (order.dueAt != null && t > order.dueAt);
  const payout = Math.round(order.reward * (late ? config.economy.latePenalty : 1));
  state.coins += payout;
  state.stats.coinsEarned += payout;
  state.stats.ordersCompleted += 1;
  if (late) state.stats.ordersLate += 1;
  if (!late) applyReputation(config, state, order.repReward);
  grantXp(config, state, xpForOrder(order.reward, !late));
  order.status = 'delivered';
  order.late = late;
  if (report) {
    report.ordersDelivered += 1;
    report.coinsEarned += payout;
  }
  log(state, t, late ? 'order_late' : 'order_delivered', late ? 'orderLate' : 'orderDelivered', {
    customer: order.customerName,
    coins: payout,
  });
  return payout;
}

/** Cancel any still-running work for an order and return unused filament. */
function cancelOrderJobs(config: GameConfig, state: FarmState, order: Order, t: number): void {
  for (const jobId of order.jobIds) {
    const job = findJob(state, jobId);
    if (!job || job.status === 'done' || job.status === 'collected') continue;
    const printer = findPrinter(state, job.printerId);
    if (job.status === 'printing' || job.status === 'queued') {
      const done = jobProgress(job, t);
      refund(state, job.spoolId, Math.round(job.grams * (1 - done) * 0.8));
      job.status = 'failed';
      job.failure = 'part_detached';
      job.failedAt = done;
    }
    if (printer) {
      printer.queue = printer.queue.filter((q) => q !== jobId);
      if (printer.status === 'printing' && !printer.queue.length) printer.status = 'idle';
      startNextJob(state, printer, t);
    }
  }
  state.jobs = state.jobs.filter((j) => !(order.jobIds.includes(j.id) && j.status === 'failed'));
}

/** Complete one print — the single place a print outcome is decided. */
function completeJob(config: GameConfig, state: FarmState, job: Job, t: number, report: AwayReport): void {
  const printer = findPrinter(state, job.printerId);
  if (!printer) {
    job.status = 'done';
    return;
  }

  const spool = state.spools.find((s) => s.id === job.spoolId);
  const roll = rollFailure(config, job.id, {
    printer,
    productId: job.productId,
    materialId: job.materialId,
    spoolQuality: spool?.quality ?? 70,
  });

  applyDecay(config, printer, job.durationMs);

  if (roll.failed) {
    job.status = 'failed';
    job.failure = roll.kind;
    job.failedAt = roll.at;
    printer.health = Math.max(0, printer.health - config.failures.healthLossOnFail);
    printer.status = 'failed';
    state.stats.printsFailed += 1;
    report.printsFailed += 1;
    refund(state, job.spoolId, Math.round(job.grams * (1 - config.failures.materialLossOnFail) * (1 - (roll.at ?? 0))));
    log(state, t, 'print_failed', 'printFailed', { printer: printer.id, kind: roll.kind ?? 'spaghetti' });
    return;
  }

  job.status = 'done';
  printer.prints += 1;
  printer.queue = printer.queue.filter((q) => q !== job.id);
  state.stats.printsCompleted += 1;
  state.stats.gramsPrinted += job.grams;
  report.printsCompleted += 1;

  const prod = product(config, job.productId);
  grantXp(config, state, xpForJob(job.grams, prod.complexity));

  if (job.orderId) {
    const order = state.orders.find((o) => o.id === job.orderId);
    if (order) {
      const all = order.jobIds
        .map((id) => findJob(state, id))
        .filter((j): j is Job => !!j);
      if (all.length && all.every((j) => j.status === 'done' || j.status === 'collected')) {
        order.status = 'ready';
        order.readyAt = t;
        log(state, t, 'order_ready', 'orderReady', { customer: order.customerName });
      }
    }
  } else {
    state.storeStock[job.productId] = (state.storeStock[job.productId] ?? 0) + job.qty;
    log(state, t, 'stock_added', 'stockAdded', { product: job.productId, qty: job.qty });
  }

  startNextJob(state, printer, t);
}

function nextPeriodic(base: number, interval: number, now: number): number {
  return base + interval;
}

/**
 * Replay everything due between `state.lastResolvedAt` and `now`.
 * Mutates and returns `state`, plus a report of what the player missed.
 */
export function resolveFarm(
  config: GameConfig,
  state: FarmState,
  now: number,
): { state: FarmState; report: AwayReport } {
  const from = Math.min(state.lastResolvedAt, now);
  const report = emptyReport(Math.max(0, now - from));
  const levelBefore = state.level;

  // Clamp the periodic clocks so a month-long absence can't blow up the loop.
  const clamp = (last: number, interval: number) =>
    now - last > interval * MAX_PERIODIC_TICKS ? now - interval * MAX_PERIODIC_TICKS : last;
  state.lastOrderSpawnAt = clamp(state.lastOrderSpawnAt, config.orders.spawnIntervalMs);
  state.lastStoreSaleAt = clamp(state.lastStoreSaleAt, config.economy.storeSaleIntervalMs);
  state.lastDemandShiftAt = clamp(state.lastDemandShiftAt, config.demand.shiftIntervalMs);

  let cursor = from;
  let guard = 0;

  while (guard++ < MAX_EVENTS) {
    let next: PendingEvent | null = null;
    const consider = (at: number, kind: EventKind, id?: string) => {
      if (at <= cursor || at > now) return;
      if (!next || at < next.at) next = { at, kind, id };
    };

    for (const job of state.jobs) {
      if (job.status === 'printing' && job.startedAt != null) {
        consider(job.startedAt + job.durationMs, 'job_end', job.id);
      }
    }
    for (const order of state.orders) {
      if (order.status === 'offered') consider(order.expiresAt, 'offer_expire', order.id);
      if ((order.status === 'accepted' || order.status === 'in_progress' || order.status === 'ready') && order.dueAt != null && !order.late) {
        consider(order.dueAt, 'order_due', order.id);
      }
      if (order.status === 'ready' && order.readyAt != null) {
        consider(order.readyAt + config.economy.autoDeliverMs, 'auto_deliver', order.id);
      }
    }
    for (const printer of state.printers) {
      if (printer.status === 'maintenance' && printer.maintenanceUntil != null) {
        consider(printer.maintenanceUntil, 'maintenance_end', printer.id);
      }
    }
    consider(nextPeriodic(state.lastOrderSpawnAt, config.orders.spawnIntervalMs, now), 'spawn');
    consider(nextPeriodic(state.lastStoreSaleAt, config.economy.storeSaleIntervalMs, now), 'store_sale');
    consider(nextPeriodic(state.lastDemandShiftAt, config.demand.shiftIntervalMs, now), 'demand_shift');

    if (!next) break;
    const ev = next as PendingEvent;
    cursor = ev.at;

    switch (ev.kind) {
      case 'job_end': {
        const job = findJob(state, ev.id!);
        if (job && job.status === 'printing') completeJob(config, state, job, cursor, report);
        break;
      }
      case 'offer_expire': {
        const order = state.orders.find((o) => o.id === ev.id);
        if (order && order.status === 'offered') {
          order.status = 'expired';
          report.ordersExpired += 1;
        }
        break;
      }
      case 'order_due': {
        const order = state.orders.find((o) => o.id === ev.id);
        if (!order) break;
        if (order.status === 'ready') {
          // The work is done, it just wasn't collected in time.
          order.late = true;
          applyReputation(config, state, -config.reputation.lateLoss);
          log(state, cursor, 'order_overdue', 'orderOverdue', { customer: order.customerName });
        } else if (order.status === 'accepted' || order.status === 'in_progress') {
          cancelOrderJobs(config, state, order, cursor);
          order.status = 'failed';
          order.late = true;
          state.stats.ordersFailed += 1;
          applyReputation(config, state, -(config.reputation.lateLoss + config.reputation.failLoss));
          log(state, cursor, 'order_failed', 'orderFailed', { customer: order.customerName });
        }
        break;
      }
      case 'auto_deliver': {
        const order = state.orders.find((o) => o.id === ev.id);
        if (order && order.status === 'ready') deliverOrder(config, state, order, cursor, report);
        break;
      }
      case 'maintenance_end': {
        const printer = findPrinter(state, ev.id!);
        if (printer && printer.status === 'maintenance') {
          printer.status = 'idle';
          printer.maintenanceUntil = undefined;
          startNextJob(state, printer, cursor);
          log(state, cursor, 'maintenance_done', 'maintenanceDone', { printer: printer.id });
        }
        break;
      }
      case 'spawn': {
        state.lastOrderSpawnAt = cursor;
        const offered = state.orders.filter((o) => o.status === 'offered').length;
        if (offered < config.orders.maxOffered) {
          const order = generateOrder(config, state, cursor, String(cursor));
          if (order) {
            state.orders.push(order);
            report.newOrders += 1;
          }
        }
        break;
      }
      case 'store_sale': {
        state.lastStoreSaleAt = cursor;
        const rng = rngFor('sale', state.seed, cursor);
        for (const [productId, stock] of Object.entries(state.storeStock)) {
          if (stock <= 0) continue;
          const demand = state.demand[productId] ?? 1;
          if (rng.next() > Math.min(0.85, 0.22 * demand)) continue;
          const units = Math.min(stock, Math.max(1, Math.round(rng.float(0.5, 2.2) * demand)));
          const revenue = units * storePrice(config, productId, demand);
          state.storeStock[productId] = stock - units;
          state.coins += revenue;
          state.stats.coinsEarned += revenue;
          state.stats.storeSales += units;
          report.storeSales += units;
          report.coinsEarned += revenue;
        }
        break;
      }
      case 'demand_shift': {
        state.lastDemandShiftAt = cursor;
        const rng = rngFor('demand', state.seed, cursor);
        for (const p of config.catalogs.products) {
          const current = state.demand[p.id] ?? 1;
          const drift = rng.float(-config.demand.step, config.demand.step);
          state.demand[p.id] = Math.round(
            Math.max(config.demand.min, Math.min(config.demand.max, current + drift)) * 100,
          ) / 100;
        }
        break;
      }
    }
  }

  // Keep the board stocked on a cold start so a new player has work waiting.
  const offered = state.orders.filter((o) => o.status === 'offered').length;
  if (offered === 0 && state.orders.filter((o) => o.status === 'accepted' || o.status === 'in_progress').length < acceptedCapacity(config, state)) {
    const order = generateOrder(config, state, now, `boot_${now}`);
    if (order) {
      state.orders.push(order);
      report.newOrders += 1;
    }
  }

  decayReputation(config, state, Math.max(0, now - from));
  pruneEmptySpools(state);

  // Drop resolved history so the save stays small.
  state.orders = state.orders.filter(
    (o) => !['expired', 'rejected'].includes(o.status) && !(o.status === 'delivered' && (o.readyAt ?? 0) < now - 86_400_000),
  );
  state.jobs = state.jobs.filter(
    (j) => j.status !== 'collected' && !(j.status === 'done' && !j.orderId),
  );

  report.maintenanceNeeded = state.printers.filter(
    (p) => p.health <= config.maintenance.thresholds.service || p.status === 'failed',
  ).length;
  if (state.level > levelBefore) report.leveledUpTo = state.level;

  state.lastResolvedAt = now;
  return { state, report };
}

export { startNextJob, log as appendLog };
