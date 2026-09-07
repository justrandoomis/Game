/** Customer order generation and the assignment maths behind multi-printer jobs. */

import type { GameConfig, CustomerTierDef } from '../config/gameConfig';
import type { FarmState, Order, Printer } from '../types';
import { estimateDuration, estimateGrams, material, printerModel, product } from './derive';
import { orderReward } from './economy';
import { rngFor } from './rng';

const CUSTOMER_NAMES = [
  'Sara', 'Omar', 'Lina', 'Yusuf', 'Dana', 'Karim', 'Noor', 'Zaid', 'Maya', 'Hadi',
  'Rami', 'Leen', 'Tariq', 'Jana', 'Adam', 'Rana', 'Sami', 'Hana', 'Basil', 'Nada',
];

const BUSINESS_NAMES = [
  'Cedar Studio', 'Blue Gear Co.', 'Maker Corner', 'Atlas Prints', 'Riverside Cafe',
  'Northwind Labs', 'Bright Desk', 'Orbit Robotics', 'Green Leaf Shop', 'Iron Fox Tools',
];

function tierDef(config: GameConfig, id: string): CustomerTierDef {
  const t = config.orders.tiers.find((x) => x.id === id);
  if (!t) throw new Error(`Unknown customer tier: ${id}`);
  return t;
}

/** Customer tiers this workshop currently qualifies for. */
export function eligibleTiers(config: GameConfig, state: FarmState): CustomerTierDef[] {
  const list = config.orders.tiers.filter(
    (t) => state.reputation >= t.minReputation && state.level >= t.minLevel,
  );
  return list.length ? list : [config.orders.tiers[0]];
}

/** Products the player has unlocked and can actually print with what they own. */
export function eligibleProducts(config: GameConfig, state: FarmState) {
  const ownedMaterials = new Set<string>();
  for (const p of state.printers) {
    printerModel(config, p.modelId).materials.forEach((m) => ownedMaterials.add(m));
  }
  return config.catalogs.products.filter(
    (p) =>
      p.unlockLevel <= state.level &&
      p.materials.some((m) => ownedMaterials.has(m) && material(config, m).unlockLevel <= state.level),
  );
}

/** How many orders the player may hold accepted at once. */
export function acceptedCapacity(config: GameConfig, state: FarmState): number {
  return Math.floor(
    config.orders.maxAcceptedBase + state.level * config.orders.maxAcceptedPerLevel,
  );
}

/**
 * Build one offer. Deterministic in `nonce`, so the same farm state always
 * generates the same board.
 */
export function generateOrder(
  config: GameConfig,
  state: FarmState,
  now: number,
  nonce: string,
): Order | null {
  const products = eligibleProducts(config, state);
  if (!products.length) return null;

  const rng = rngFor('order', state.seed, nonce);
  const tier = rng.pick(eligibleTiers(config, state));
  const prod = rng.pick(products);

  const ownedMaterials = new Set<string>();
  for (const p of state.printers) {
    printerModel(config, p.modelId).materials.forEach((m) => ownedMaterials.add(m));
  }
  const materials = prod.materials.filter(
    (m) => ownedMaterials.has(m) && material(config, m).unlockLevel <= state.level,
  );
  if (!materials.length) return null;

  // Bias requests toward filament the workshop actually has on the rack.
  // A customer asking for a colour the player has never bought is a dead end
  // rather than a decision — and on the very first orders it would leave a new
  // player unable to print anything at all. Once the workshop is established
  // some orders deliberately call for stock the player has to go and buy,
  // which is where the filament economy comes from.
  const established = state.stats.ordersCompleted >= 3;
  const preferStock = !established || rng.next() < 0.65;

  const stockedMaterials = materials.filter((m) =>
    state.spools.some((s) => s.materialId === m && s.grams >= prod.grams),
  );
  const materialPool = preferStock && stockedMaterials.length ? stockedMaterials : materials;
  const materialId = rng.pick(materialPool);

  const stockedColors = state.spools
    .filter((s) => s.materialId === materialId && s.grams >= prod.grams)
    .map((s) => s.colorId);
  const colorPool =
    preferStock && stockedColors.length
      ? Array.from(new Set(stockedColors))
      : config.catalogs.colors.map((c) => c.id);
  const colorId = rng.pick(colorPool);

  const qty = rng.int(tier.qty[0], tier.qty[1]);
  const mat = material(config, materialId);
  const grams = Math.ceil(prod.grams * qty * (1 + config.materials.wasteFactor));
  const printMs = Math.round(prod.minutes * 60_000 * qty * mat.timeFactor);

  // Tight deadlines pay more. Urgency runs 0 (relaxed) .. 1 (rush).
  const urgency = rng.next() < 0.22 ? rng.float(0.6, 1) : rng.float(0, 0.35);
  const deadlineFactor = tier.deadlineFactor * (1 - urgency * 0.45);
  const deadlineMs = Math.max(20 * 60_000, Math.round(printMs * deadlineFactor));

  const reward = orderReward(config, prod.id, qty, materialId, tier, urgency);
  const repReward = Math.max(1, Math.round(tier.rep[0] * (0.6 + prod.complexity * 0.12)));

  const nameList = tier.id === 'individual' ? CUSTOMER_NAMES : BUSINESS_NAMES;

  return {
    id: `o_${nonce}`,
    productId: prod.id,
    qty,
    tier: tier.id,
    customerName: rng.pick(nameList),
    materialId,
    colorId,
    grams,
    printMs,
    offeredAt: now,
    expiresAt: now + config.orders.offerTtlMs,
    acceptedAt: null,
    dueAt: null,
    // Stored so accepting can set dueAt without re-rolling.
    reward,
    repReward,
    difficulty: Math.max(1, Math.min(5, prod.complexity + (urgency > 0.5 ? 1 : 0))),
    status: 'offered',
    jobIds: [],
    deadlineMs,
    readyAt: null,
    late: false,
  };
}

/** The deadline window an offer carries before it is accepted. */
export function orderDeadlineMs(config: GameConfig, order: Order): number {
  if (typeof order.deadlineMs === 'number' && order.deadlineMs > 0) return order.deadlineMs;
  const tier = tierDef(config, order.tier);
  return Math.max(20 * 60_000, Math.round(order.printMs * tier.deadlineFactor));
}

export type DeadlineBand = 'normal' | 'soon' | 'urgent' | 'critical';

/** Colour band for a deadline chip — stronger as time runs out, never flashing. */
export function deadlineBand(order: Order, now: number): DeadlineBand {
  if (order.dueAt == null) return 'normal';
  const left = order.dueAt - now;
  const total = Math.max(1, order.dueAt - (order.acceptedAt ?? order.offeredAt));
  const frac = left / total;
  if (left <= 0 || frac <= 0.1) return 'critical';
  if (frac <= 0.25) return 'urgent';
  if (frac <= 0.5) return 'soon';
  return 'normal';
}

export interface Assignment {
  printerId: string;
  qty: number;
  durationMs: number;
  grams: number;
}

/**
 * Split an order across the given machines.
 *
 * Work is handed out in proportion to how fast each machine is, so the parts
 * finish at roughly the same time instead of one printer holding up the order.
 */
export function planAssignment(
  config: GameConfig,
  order: Order,
  printers: Printer[],
): Assignment[] {
  if (!printers.length) return [];
  const prod = product(config, order.productId);
  const rates = printers.map((p) => {
    const oneUnit = estimateDuration(config, p, order.productId, 1, order.materialId);
    return oneUnit > 0 ? 1 / oneUnit : 0;
  });
  const totalRate = rates.reduce((a, b) => a + b, 0);
  if (totalRate <= 0) return [];

  const raw = rates.map((r) => (r / totalRate) * order.qty);
  const qtys = raw.map((v) => Math.floor(v));
  let assigned = qtys.reduce((a, b) => a + b, 0);

  // Hand the rounding remainder to the machines with the largest fractional part.
  const order2 = raw
    .map((v, i) => ({ i, frac: v - Math.floor(v) }))
    .sort((a, b) => b.frac - a.frac);
  let k = 0;
  while (assigned < order.qty) {
    qtys[order2[k % order2.length].i] += 1;
    assigned += 1;
    k += 1;
  }

  return printers
    .map((p, i) => ({
      printerId: p.id,
      qty: qtys[i],
      durationMs: estimateDuration(config, p, order.productId, qtys[i], order.materialId),
      grams: estimateGrams(config, p, order.productId, qtys[i]),
    }))
    .filter((a) => a.qty > 0);
}

/** Longest leg of a split — i.e. when the whole order is actually finished. */
export function assignmentEta(assignments: Assignment[]): number {
  return assignments.reduce((max, a) => Math.max(max, a.durationMs), 0);
}

export { product as jobProduct };
