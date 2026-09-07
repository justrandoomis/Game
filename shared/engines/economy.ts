/** Pricing, rewards and the cost of everything the player can buy. */

import type { GameConfig } from '../config/gameConfig';
import type { CustomerTierDef } from '../config/gameConfig';
import type { Printer } from '../types';
import { printerModel, product, material } from './derive';

/**
 * Reward for a customer order.
 *
 * Pay is grounded in the two real costs the player carries — filament and
 * machine time — then scaled by complexity, the customer tier and how tight
 * the deadline is.
 */
export function orderReward(
  config: GameConfig,
  productId: string,
  qty: number,
  materialId: string,
  tier: CustomerTierDef,
  urgency: number,
): number {
  const p = product(config, productId);
  const m = material(config, materialId);
  const grams = p.grams * qty;
  const hours = (p.minutes * qty * m.timeFactor) / 60;

  const materialCost = (grams / m.spoolSize) * m.pricePerSpool;
  const base =
    grams * config.economy.coinPerGram +
    hours * config.economy.coinPerHour +
    materialCost;

  const complexity = 1 + (p.complexity - 1) * config.economy.complexityBonus;
  const urgencyMul = 1 + urgency * config.economy.urgencyBonus;

  return Math.round(base * complexity * tier.payFactor * urgencyMul);
}

/** Shop price of one spool. */
export function spoolPrice(config: GameConfig, materialId: string): number {
  return Math.round(material(config, materialId).pricePerSpool * config.materials.priceFactor);
}

/** What the player gets back for selling a machine, scaled by its condition. */
export function printerResale(config: GameConfig, printer: Printer): number {
  const model = printerModel(config, printer.modelId);
  return Math.round(model.price * model.resaleFactor * (0.45 + (printer.health / 100) * 0.55));
}

/**
 * Cost of unlocking the nth station (1-indexed) in the current tier.
 * Grows geometrically so each new station is a real decision.
 */
export function slotCost(config: GameConfig, unlockedCount: number): number {
  const { slotCostBase, slotCostGrowth } = config.workshop;
  return Math.round(slotCostBase * Math.pow(slotCostGrowth, Math.max(0, unlockedCount - 1)));
}

/** Level gate for the nth station (1-indexed). */
export function slotLevel(config: GameConfig, unlockedCount: number): number {
  return 1 + Math.max(0, unlockedCount - 1) * config.workshop.slotLevelStep;
}

/** Store sale price for one unit, after the current demand multiplier. */
export function storePrice(config: GameConfig, productId: string, demand: number): number {
  const p = product(config, productId);
  return Math.round(p.salePrice * config.economy.storeMargin * demand);
}

/** Rough production cost of one unit, shown next to the sale price. */
export function productionCost(config: GameConfig, productId: string, materialId: string): number {
  const p = product(config, productId);
  const m = material(config, materialId);
  return Math.round((p.grams / m.spoolSize) * m.pricePerSpool + (p.minutes / 60) * 8);
}
