import { describe, expect, it } from 'vitest';
import { DEFAULT_CONFIG, mergeConfig, xpForLevel } from '../shared/config/gameConfig';
import { createInitialState, nextId } from '../shared/engines/state';
import { resolveFarm } from '../shared/engines/resolve';
import * as intents from '../shared/engines/intents';
import { estimateDuration, estimateGrams, jobProgress } from '../shared/engines/derive';
import { failureProbability } from '../shared/engines/failures';
import { generateOrder } from '../shared/engines/jobEngine';
import { slotCost } from '../shared/engines/economy';
import type { FarmState } from '../shared/types';

const T0 = 1_700_000_000_000;
const config = DEFAULT_CONFIG;

function newFarm(now = T0): FarmState {
  return createInitialState(config, now, 12345);
}

/** Give the farm an order it can actually print, and start it. */
function startFirstJob(state: FarmState, now = T0) {
  resolveFarm(config, state, now);
  const offer = state.orders.find((o) => o.status === 'offered')!;
  expect(intents.acceptOrder(config, state, now, offer.id).ok).toBe(true);
  const printer = state.printers[0];
  const result = intents.assignOrder(config, state, now, offer.id, [printer.id]);
  return { offer, printer, result };
}

describe('starting state', () => {
  it('gives a new player one machine, one spool and one open station', () => {
    const state = newFarm();
    expect(state.printers).toHaveLength(1);
    expect(state.printers[0].modelId).toBe('a1_mini');
    expect(state.spools).toHaveLength(1);
    expect(state.unlockedSlots).toEqual(['s_0_0']);
    expect(state.coins).toBe(config.start.coins);
  });

  it('puts an order on the board straight away', () => {
    const state = newFarm();
    const { report } = resolveFarm(config, state, T0);
    expect(state.orders.filter((o) => o.status === 'offered').length).toBeGreaterThan(0);
    expect(report.newOrders).toBeGreaterThan(0);
  });

  it('only asks a new player for filament they already own', () => {
    // A first order in a colour the player has never bought would be a dead
    // end rather than a decision.
    for (let seed = 0; seed < 40; seed++) {
      const state = createInitialState(config, T0, seed * 7919);
      const order = generateOrder(config, state, T0, `probe_${seed}`)!;
      expect(order).not.toBeNull();
      const stocked = state.spools.some(
        (s) => s.materialId === order.materialId && s.colorId === order.colorId,
      );
      expect(stocked).toBe(true);
    }
  });
});

describe('the first playable loop', () => {
  it('accepts an order, reserves filament and starts printing', () => {
    const state = newFarm();
    const { offer, printer, result } = startFirstJob(state);
    expect(result.ok).toBe(true);

    const job = state.jobs.find((j) => j.orderId === offer.id)!;
    expect(job.status).toBe('printing');
    expect(job.startedAt).toBe(T0);
    expect(state.printers[0].status).toBe('printing');
    expect(state.printers[0].queue).toContain(job.id);
    // Filament is taken up front, so two orders cannot spend the same grams.
    expect(state.spools[0].grams).toBe(1000 - job.grams);
    void printer;
  });

  it('refuses work the workshop has no filament for', () => {
    const state = newFarm();
    resolveFarm(config, state, T0);
    state.spools[0].grams = 1;
    const offer = state.orders.find((o) => o.status === 'offered')!;
    intents.acceptOrder(config, state, T0, offer.id);
    const result = intents.assignOrder(config, state, T0, offer.id, [state.printers[0].id]);
    expect(result.ok).toBe(false);
    expect(result.error).toBe('not_enough_filament');
    expect(result.fx?.value).toBeGreaterThan(0);
    // Nothing is half-committed on a refusal.
    expect(state.jobs).toHaveLength(0);
  });

  it('finishes the print, readies the order and pays on delivery', () => {
    const state = newFarm();
    const { offer } = startFirstJob(state);
    const job = state.jobs.find((j) => j.orderId === offer.id)!;
    // Make this print certain to succeed so the test is about the loop.
    state.printers[0].health = 100;

    const after = T0 + job.durationMs + 1000;
    resolveFarm(config, state, after);

    const order = state.orders.find((o) => o.id === offer.id)!;
    if (order.status === 'ready') {
      const before = state.coins;
      expect(intents.collectOrder(config, state, after, offer.id).ok).toBe(true);
      expect(state.coins).toBe(before + order.reward);
      expect(state.stats.ordersCompleted).toBe(1);
      expect(state.reputation).toBeGreaterThan(0);
    } else {
      // The other legitimate outcome is a failed print, which must leave the
      // machine flagged rather than silently losing the order.
      expect(state.printers[0].status).toBe('failed');
    }
  });
});

describe('authoritative resolution', () => {
  it('is idempotent: resolving twice changes nothing', () => {
    const state = newFarm();
    startFirstJob(state);
    const at = T0 + 3 * 3600_000;

    resolveFarm(config, state, at);
    const first = JSON.stringify(state);
    resolveFarm(config, state, at);
    expect(JSON.stringify(state)).toBe(first);
  });

  it('produces the same outcome for the same elapsed time, in one step or many', () => {
    const a = newFarm();
    const b = newFarm();
    startFirstJob(a);
    startFirstJob(b);
    const end = T0 + 6 * 3600_000;

    resolveFarm(config, a, end);
    for (let t = T0; t <= end; t += 30 * 60_000) resolveFarm(config, b, t);

    expect(a.coins).toBe(b.coins);
    expect(a.stats.printsCompleted).toBe(b.stats.printsCompleted);
    expect(a.stats.printsFailed).toBe(b.stats.printsFailed);
  });

  it('survives a long absence without running away', () => {
    const state = newFarm();
    startFirstJob(state);
    const month = T0 + 30 * 86_400_000;
    const start = Date.now();
    const { report } = resolveFarm(config, state, month);
    expect(Date.now() - start).toBeLessThan(2000);
    expect(state.lastResolvedAt).toBe(month);
    expect(report.elapsedMs).toBe(month - T0);
    // The board is capped, not filled with a month of offers.
    expect(state.orders.filter((o) => o.status === 'offered').length)
      .toBeLessThanOrEqual(config.orders.maxOffered);
  });

  it('reports what happened while the player was away', () => {
    const state = newFarm();
    const { offer } = startFirstJob(state);
    const job = state.jobs.find((j) => j.orderId === offer.id)!;
    const { report } = resolveFarm(config, state, T0 + job.durationMs + config.economy.autoDeliverMs + 60_000);
    expect(report.printsCompleted + report.printsFailed).toBeGreaterThan(0);
  });

  it('lets an accepted order fail when its deadline passes', () => {
    const state = newFarm();
    resolveFarm(config, state, T0);
    const offer = state.orders.find((o) => o.status === 'offered')!;
    intents.acceptOrder(config, state, T0, offer.id);
    // Never assigned it to a machine: the deadline should catch up.
    resolveFarm(config, state, T0 + offer.deadlineMs + 60_000);
    const order = state.orders.find((o) => o.id === offer.id)!;
    expect(order.status).toBe('failed');
    expect(state.stats.ordersFailed).toBe(1);
  });
});

describe('server authority', () => {
  it('refuses a purchase the player cannot afford', () => {
    const state = newFarm();
    state.coins = 10;
    expect(intents.buySpool(config, state, T0, 'pla', 'red').error).toBe('not_enough_coins');
    expect(state.spools).toHaveLength(1);
  });

  it('refuses machines and materials above the player level', () => {
    const state = newFarm();
    state.coins = 10_000_000;
    expect(intents.buyPrinter(config, state, T0, 'h2c', 's_0_0').error).toBe('level_too_low');
    expect(intents.buySpool(config, state, T0, 'cf', 'red').error).toBe('level_too_low');
  });

  it('unlocks stations only in grid order', () => {
    const state = newFarm();
    state.coins = 100_000;
    expect(intents.unlockSlot(config, state, T0, 's_1_1').error).toBe('unlock_in_order');
    expect(intents.unlockSlot(config, state, T0, 's_0_1').ok).toBe(true);
    expect(state.unlockedSlots).toEqual(['s_0_0', 's_0_1']);
  });

  it('will not put two machines on one station', () => {
    const state = newFarm();
    state.coins = 100_000;
    expect(intents.buyPrinter(config, state, T0, 'a1_mini', 's_0_0').error).toBe('slot_occupied');
  });

  it('will not expand the workshop before the current room is full', () => {
    const state = newFarm();
    state.coins = 1_000_000;
    state.level = 40;
    expect(intents.expandWorkshop(config, state, T0).error).toBe('fill_current_room');
  });

  it('caps how much work a player can hold at once', () => {
    const state = newFarm();
    let accepted = 0;
    for (let i = 0; i < 12; i++) {
      const order = generateOrder(config, state, T0, `bulk_${i}`);
      if (!order) continue;
      state.orders.push(order);
      if (intents.acceptOrder(config, state, T0, order.id).ok) accepted++;
    }
    expect(accepted).toBeLessThanOrEqual(
      Math.floor(config.orders.maxAcceptedBase + state.level * config.orders.maxAcceptedPerLevel),
    );
  });
});

describe('economy and progression', () => {
  it('charges for a station and takes the coins', () => {
    const state = newFarm();
    state.coins = 100_000;
    const before = state.coins;
    const cost = intents.unlockSlotCost(config, state);
    intents.unlockSlot(config, state, T0, 's_0_1');
    expect(state.coins).toBe(before - cost);
    expect(state.stats.coinsSpent).toBe(cost);
  });

  it('makes each successive station cost more', () => {
    for (let owned = 1; owned < 8; owned++) {
      expect(slotCost(config, owned + 1)).toBeGreaterThan(slotCost(config, owned));
    }
  });

  it('stops selling stations once the room is full', () => {
    // The tiny workshop holds two machines. The third is not a price problem,
    // it is a space problem, and the answer is to expand the workshop.
    const state = newFarm();
    state.coins = 10_000_000;
    state.level = 50;
    const first = intents.unlockSlotCost(config, state);
    expect(intents.unlockSlot(config, state, T0, 's_0_1').ok).toBe(true);
    expect(intents.unlockSlotCost(config, state)).toBeGreaterThan(first);
    expect(intents.unlockSlot(config, state, T0, 's_1_0').error).toBe('workshop_full');

    // With the room full, expansion opens up and the new room is bigger.
    const before = config.workshop.tiers[state.tier];
    expect(intents.expandWorkshop(config, state, T0).ok).toBe(true);
    const after = config.workshop.tiers[state.tier];
    expect(after.rows * after.cols).toBeGreaterThan(before.rows * before.cols);
    expect(after.slots).toBeGreaterThan(before.slots);
  });

  it('needs more XP for every level', () => {
    for (let level = 1; level < 20; level++) {
      expect(xpForLevel(config, level + 1)).toBeGreaterThan(xpForLevel(config, level));
    }
  });

  it('gates features behind levels rather than showing everything at once', () => {
    const state = newFarm();
    expect(state.level).toBe(1);
    expect(config.progression.unlocks[1]).toContain('farm');
    expect(config.progression.unlocks[3]).toContain('store');
    expect(config.progression.unlocks[15]).toContain('upgrades');
  });
});

describe('machine condition', () => {
  it('makes a neglected machine fail far more often', () => {
    const state = newFarm();
    const printer = state.printers[0];
    const context = { printer, productId: 'mini_dino', materialId: 'pla', spoolQuality: 70 };

    printer.health = 100;
    const healthy = failureProbability(config, context);
    printer.health = 10;
    const neglected = failureProbability(config, context);

    expect(neglected).toBeGreaterThan(healthy * 2);
    expect(healthy).toBeLessThan(0.25);
  });

  it('wears the machine down as it runs', () => {
    const state = newFarm();
    startFirstJob(state);
    const job = state.jobs[0];
    resolveFarm(config, state, T0 + job.durationMs + 1000);
    expect(state.printers[0].health).toBeLessThan(100);
    expect(state.printers[0].hours).toBeGreaterThan(0);
  });

  it('blocks the queue until a failed print is cleared', () => {
    const state = newFarm();
    startFirstJob(state);
    const job = state.jobs[0];
    // Force the failure path rather than waiting for an unlucky roll.
    job.status = 'failed';
    job.failure = 'spaghetti';
    job.failedAt = 0.5;
    state.printers[0].status = 'failed';

    expect(intents.startStoreJob(config, state, T0, state.printers[0].id, 'keychain', 1, 'pla', 'green').error)
      .toBe('printer_unavailable');
    expect(intents.clearFailure(config, state, T0, state.printers[0].id).ok).toBe(true);
    expect(state.printers[0].status).toBe('idle');
  });
});

describe('multi-printer jobs', () => {
  it('splits an order so the machines finish together', () => {
    const state = newFarm();
    state.coins = 100_000;
    state.level = 30;
    intents.unlockSlot(config, state, T0, 's_0_1');
    intents.buyPrinter(config, state, T0, 'a1', 's_0_1');
    intents.buySpool(config, state, T0, 'pla', 'green', 5);

    const order = generateOrder(config, state, T0, 'split');
    expect(order).not.toBeNull();
    order!.qty = 20;
    order!.materialId = 'pla';
    order!.colorId = 'green';
    order!.grams = 20 * 26;
    state.orders.push(order!);
    intents.acceptOrder(config, state, T0, order!.id);

    const ids = state.printers.map((p) => p.id);
    const result = intents.assignOrder(config, state, T0, order!.id, ids);
    expect(result.ok).toBe(true);

    const jobs = state.jobs.filter((j) => j.orderId === order!.id);
    expect(jobs.length).toBe(2);
    expect(jobs.reduce((sum, j) => sum + j.qty, 0)).toBe(20);
    // The faster machine takes more units, so neither sits idle waiting.
    const durations = jobs.map((j) => j.durationMs).sort((a, b) => a - b);
    expect(durations[1] / durations[0]).toBeLessThan(1.6);
  });
});

describe('estimates match what the server does', () => {
  it('scales print time with quantity, machine speed and material', () => {
    const state = newFarm();
    const printer = state.printers[0];
    const one = estimateDuration(config, printer, 'mini_dino', 1, 'pla');
    const four = estimateDuration(config, printer, 'mini_dino', 4, 'pla');
    expect(four).toBe(one * 4);
    // PETG prints slower than PLA, by the material's own time factor.
    expect(estimateDuration(config, printer, 'mini_dino', 1, 'petg')).toBeGreaterThan(one);
  });

  it('includes purge waste in the filament estimate', () => {
    const state = newFarm();
    const grams = estimateGrams(config, state.printers[0], 'mini_dino', 1);
    expect(grams).toBeGreaterThan(26);
  });

  it('reports progress from server timestamps only', () => {
    const job = { startedAt: T0, durationMs: 1000, status: 'printing' } as never;
    expect(jobProgress(job, T0)).toBe(0);
    expect(jobProgress(job, T0 + 500)).toBeCloseTo(0.5);
    expect(jobProgress(job, T0 + 5000)).toBe(1);
  });
});

describe('admin balancing', () => {
  it('lets an override change the economy without touching code', () => {
    const tuned = mergeConfig(config, { start: { coins: 5000 }, economy: { coinPerGram: 9 } });
    expect(tuned.start.coins).toBe(5000);
    expect(tuned.economy.coinPerGram).toBe(9);
    // Untouched values still come from the defaults.
    expect(tuned.start.printerModelId).toBe(config.start.printerModelId);
    expect(config.start.coins).toBe(650);
  });

  it('lets an override replace a whole catalog', () => {
    const tuned = mergeConfig(config, {
      catalogs: { materials: [{ id: 'pla', name: 'Recycled PLA', pricePerSpool: 40 }] },
    });
    expect(tuned.catalogs.materials).toHaveLength(1);
    expect(tuned.catalogs.printers.length).toBeGreaterThan(1);
  });

  it('keeps Levonis Points conversion off and capped by default', () => {
    expect(config.levonis.enabled).toBe(false);
    expect(config.levonis.weeklyPointCap).toBeGreaterThan(0);
    expect(config.levonis.minLevel).toBeGreaterThan(1);
  });
});

describe('entity ids', () => {
  it('never repeats an id', () => {
    const state = newFarm();
    const ids = new Set<string>();
    for (let i = 0; i < 500; i++) {
      const id = nextId(state, 'job');
      expect(ids.has(id)).toBe(false);
      ids.add(id);
    }
  });
});
