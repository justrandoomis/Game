/**
 * MASTER BALANCING CONFIG.
 *
 * Every number the game balances on lives here. Components never contain
 * economy constants — they read them from the resolved config. The server
 * merges admin overrides (pf_config table) over these defaults, so balancing
 * is a database change, not a deploy.
 */

import { PRINTER_CATALOG, type PrinterModel } from './printers';
import { MATERIALS, COLORS, type FilamentColor, type Material } from './materials';
import { PRODUCTS, type Product } from './products';
import type { CustomerTier, PartId } from '../types';

export interface WorkshopTier {
  id: string;
  name: string;
  rows: number;
  cols: number;
  /** Slots the player may unlock while on this tier. */
  slots: number;
  /** Level required to move up to this tier. */
  unlockLevel: number;
  /** Coins to expand into this tier. */
  cost: number;
  /** Floor palette key, so each tier reads as a different physical space. */
  floor: 'tile' | 'concrete' | 'epoxy' | 'industrial';
}

export interface PartDef {
  id: PartId;
  name: string;
  price: number;
  /** Health restored when used in a service. */
  restores: number;
  unlockLevel: number;
}

export interface UpgradeDef {
  id: string;
  name: string;
  category: 'printer' | 'workshop' | 'storage' | 'automation' | 'energy' | 'quality';
  price: number;
  unlockLevel: number;
  /** Applied as multipliers/additions when the upgrade is installed. */
  effects: Partial<{
    speed: number;
    quality: number;
    failure: number;
    healthDecay: number;
    queueCapacity: number;
    materialWaste: number;
  }>;
  description: string;
}

export interface CustomerTierDef {
  id: CustomerTier;
  name: string;
  /** Minimum reputation before this tier appears. */
  minReputation: number;
  minLevel: number;
  /** Reward multiplier. */
  payFactor: number;
  /** Quantity range for orders from this tier. */
  qty: [number, number];
  /** Reputation gained/lost. */
  rep: [number, number];
  /** Deadline generosity: multiple of raw print time. */
  deadlineFactor: number;
}

export interface GameConfig {
  version: number;
  start: {
    coins: number;
    level: number;
    xp: number;
    reputation: number;
    printerModelId: string;
    spools: Array<{ materialId: string; colorId: string; grams: number }>;
    unlockedSlots: number;
  };
  progression: {
    /** XP needed to reach level n+1 = base * n^exp, rounded. */
    xpBase: number;
    xpExponent: number;
    maxLevel: number;
    /** level -> feature keys unlocked at that level. */
    unlocks: Record<number, string[]>;
  };
  workshop: {
    tiers: WorkshopTier[];
    /** Cost of unlocking station #n within the current tier. */
    slotCostBase: number;
    slotCostGrowth: number;
    /** Level required to unlock station #n (1-indexed). */
    slotLevelStep: number;
  };
  economy: {
    /** Coins per gram baseline used to price customer orders. */
    coinPerGram: number;
    /** Coins per print-hour baseline. */
    coinPerHour: number;
    /** Reward multiplier per complexity point above 1. */
    complexityBonus: number;
    /** Extra pay for urgent deadlines. */
    urgencyBonus: number;
    /** Fraction of the reward paid when delivered late. */
    latePenalty: number;
    /** Store sale price multiplier applied to product.salePrice. */
    storeMargin: number;
    /** Seconds between store sale ticks. */
    storeSaleIntervalMs: number;
    /** A finished order left uncollected this long is delivered automatically. */
    autoDeliverMs: number;
  };
  orders: {
    /** Milliseconds between order-board refreshes. */
    spawnIntervalMs: number;
    /** Max simultaneous offers on the board. */
    maxOffered: number;
    /** Max orders the player may hold accepted at once (per level band). */
    maxAcceptedBase: number;
    maxAcceptedPerLevel: number;
    /** How long an un-accepted offer stays on the board. */
    offerTtlMs: number;
    tiers: CustomerTierDef[];
  };
  materials: {
    /** Fraction of grams lost to purge/waste on every print. */
    wasteFactor: number;
    /** Markup on the shop price of a spool. */
    priceFactor: number;
  };
  maintenance: {
    /** Health lost per print-hour at reliability 50. */
    healthDecayPerHour: number;
    /** Thresholds surfaced in the UI. */
    thresholds: { good: number; service: number; warning: number; critical: number };
    /** Service actions available at the bench. */
    actions: Array<{
      id: string;
      name: string;
      cost: number;
      durationMs: number;
      restores: number;
      partId?: PartId;
      minLevel: number;
    }>;
    parts: PartDef[];
  };
  failures: {
    /** Multiplier applied to the printer's base failure rate. */
    globalFactor: number;
    /** Extra failure probability at 0 health (linear to 0 at full health). */
    healthWeight: number;
    /** Extra failure probability per complexity point above 1. */
    complexityWeight: number;
    /** Health lost when a print fails. */
    healthLossOnFail: number;
    /** Fraction of reserved filament lost on a failure. */
    materialLossOnFail: number;
  };
  reputation: {
    start: number;
    max: number;
    /** Reputation lost when an accepted order misses its deadline. */
    lateLoss: number;
    failLoss: number;
    rejectLoss: number;
    /** Passive drift back toward this value, per day. */
    decayPerDay: number;
  };
  upgrades: UpgradeDef[];
  demand: {
    /** How far demand can drift from 1.0. */
    min: number;
    max: number;
    /** Milliseconds between demand shifts. */
    shiftIntervalMs: number;
    /** Max change per shift. */
    step: number;
  };
  levonis: {
    /** Farm Coins required for one Levonis Point. Never unlimited. */
    coinsPerPoint: number;
    /** Points a player may claim per week. */
    weeklyPointCap: number;
    minLevel: number;
    minReputation: number;
    /** Conversion is off until an admin turns it on. */
    enabled: boolean;
  };
  catalogs: {
    printers: PrinterModel[];
    materials: Material[];
    colors: FilamentColor[];
    products: Product[];
  };
}

export const DEFAULT_CONFIG: GameConfig = {
  version: 1,
  start: {
    coins: 650,
    level: 1,
    xp: 0,
    reputation: 0,
    printerModelId: 'a1_mini',
    spools: [{ materialId: 'pla', colorId: 'green', grams: 1000 }],
    unlockedSlots: 1,
  },
  progression: {
    xpBase: 120,
    xpExponent: 1.45,
    maxLevel: 60,
    unlocks: {
      1: ['farm', 'orders', 'inventory', 'printers'],
      3: ['store'],
      5: ['maintenance'],
      8: ['materials_advanced'],
      10: ['multi_printer'],
      12: ['reputation'],
      15: ['upgrades'],
      20: ['employees'],
      25: ['electricity'],
      30: ['contracts'],
      35: ['loans'],
      40: ['research'],
      50: ['industrial'],
    },
  },
  workshop: {
    // Each tier grows the room itself, not just the number of stations, so
    // expanding is something the player sees. A tier always exposes more grid
    // cells than it lets you unlock, which is what makes the locked area at
    // the back read as "there is room to grow here".
    tiers: [
      { id: 'tiny',       name: 'Tiny Workshop',   rows: 2, cols: 2, slots: 2,  unlockLevel: 1,  cost: 0,      floor: 'tile' },
      { id: 'small',      name: 'Small Workshop',  rows: 2, cols: 3, slots: 4,  unlockLevel: 4,  cost: 1800,   floor: 'tile' },
      { id: 'garage',     name: 'Garage',          rows: 3, cols: 4, slots: 8,  unlockLevel: 10, cost: 9500,   floor: 'concrete' },
      { id: 'print_farm', name: 'Print Farm',      rows: 4, cols: 5, slots: 16, unlockLevel: 20, cost: 42000,  floor: 'epoxy' },
      { id: 'industrial', name: 'Industrial Farm', rows: 6, cols: 6, slots: 36, unlockLevel: 35, cost: 190000, floor: 'industrial' },
    ],
    slotCostBase: 450,
    slotCostGrowth: 1.55,
    slotLevelStep: 2,
  },
  economy: {
    coinPerGram: 1.9,
    coinPerHour: 46,
    complexityBonus: 0.14,
    urgencyBonus: 0.25,
    latePenalty: 0.45,
    storeMargin: 1.0,
    storeSaleIntervalMs: 6 * 60 * 1000,
    autoDeliverMs: 10 * 60 * 1000,
  },
  orders: {
    spawnIntervalMs: 4 * 60 * 1000,
    maxOffered: 6,
    maxAcceptedBase: 3,
    maxAcceptedPerLevel: 0.25,
    offerTtlMs: 45 * 60 * 1000,
    tiers: [
      { id: 'individual',     name: 'Individual',     minReputation: 0,  minLevel: 1,  payFactor: 1.0,  qty: [1, 3],   rep: [2, -3],  deadlineFactor: 3.2 },
      { id: 'small_business', name: 'Small Business', minReputation: 25, minLevel: 6,  payFactor: 1.25, qty: [3, 8],   rep: [4, -5],  deadlineFactor: 2.8 },
      { id: 'merchant',       name: 'Merchant',       minReputation: 45, minLevel: 12, payFactor: 1.5,  qty: [6, 18],  rep: [6, -8],  deadlineFactor: 2.5 },
      { id: 'company',        name: 'Company',        minReputation: 65, minLevel: 22, payFactor: 1.85, qty: [15, 45], rep: [9, -12], deadlineFactor: 2.2 },
      { id: 'industrial',     name: 'Industrial',     minReputation: 82, minLevel: 32, payFactor: 2.3,  qty: [40, 120],rep: [14, -18],deadlineFactor: 2.0 },
    ],
  },
  materials: {
    wasteFactor: 0.04,
    priceFactor: 1.0,
  },
  maintenance: {
    healthDecayPerHour: 0.85,
    thresholds: { good: 100, service: 70, warning: 40, critical: 20 },
    actions: [
      { id: 'clean',      name: 'Clean',           cost: 40,  durationMs: 4 * 60 * 1000,  restores: 8,  minLevel: 5 },
      { id: 'lubricate',  name: 'Lubricate',       cost: 90,  durationMs: 8 * 60 * 1000,  restores: 18, minLevel: 5 },
      { id: 'nozzle',     name: 'Replace Nozzle',  cost: 150, durationMs: 10 * 60 * 1000, restores: 32, partId: 'nozzle', minLevel: 5 },
      { id: 'hotend',     name: 'Replace Hotend',  cost: 320, durationMs: 18 * 60 * 1000, restores: 55, partId: 'hotend', minLevel: 9 },
      { id: 'plate',      name: 'Replace Plate',   cost: 210, durationMs: 12 * 60 * 1000, restores: 40, partId: 'plate',  minLevel: 9 },
      { id: 'overhaul',   name: 'Full Service',    cost: 620, durationMs: 30 * 60 * 1000, restores: 100, minLevel: 14 },
    ],
    parts: [
      { id: 'nozzle', name: 'Nozzle',          price: 55,  restores: 32, unlockLevel: 5 },
      { id: 'hotend', name: 'Hotend',          price: 180, restores: 55, unlockLevel: 9 },
      { id: 'plate',  name: 'Build Plate',     price: 130, restores: 40, unlockLevel: 9 },
      { id: 'belt',   name: 'Belt Set',        price: 95,  restores: 25, unlockLevel: 14 },
      { id: 'gear',   name: 'Extruder Gears',  price: 120, restores: 30, unlockLevel: 14 },
      { id: 'kit',    name: 'Maintenance Kit', price: 340, restores: 70, unlockLevel: 14 },
    ],
  },
  failures: {
    globalFactor: 1.0,
    healthWeight: 0.22,
    complexityWeight: 0.018,
    healthLossOnFail: 9,
    materialLossOnFail: 0.6,
  },
  reputation: {
    start: 0,
    max: 100,
    lateLoss: 4,
    failLoss: 3,
    rejectLoss: 0.5,
    decayPerDay: 0.5,
  },
  upgrades: [
    { id: 'nozzle_hard',   name: 'Hardened Nozzle',  category: 'printer',    price: 420,  unlockLevel: 15, effects: { failure: -0.15, healthDecay: -0.1 },       description: 'Survives abrasive filaments and slows wear.' },
    { id: 'plate_texture', name: 'Textured Plate',   category: 'quality',    price: 380,  unlockLevel: 15, effects: { failure: -0.2, quality: 3 },               description: 'First layers stick. Fewer detached parts.' },
    { id: 'ams',           name: 'AMS Unit',         category: 'printer',    price: 1400, unlockLevel: 17, effects: { queueCapacity: 2 },                        description: 'Automatic filament changes and a deeper queue.' },
    { id: 'dryer',         name: 'Filament Dryer',   category: 'quality',    price: 900,  unlockLevel: 18, effects: { quality: 5, failure: -0.12 },              description: 'Dry filament prints cleaner, especially PETG and PA.' },
    { id: 'camera',        name: 'Monitoring Camera',category: 'automation', price: 650,  unlockLevel: 19, effects: { failure: -0.1 },                           description: 'Catches spaghetti early and aborts the print.' },
    { id: 'kit_auto',      name: 'Service Kit',      category: 'printer',    price: 1100, unlockLevel: 20, effects: { healthDecay: -0.25 },                      description: 'Keeps the machine healthy far longer between services.' },
    { id: 'rack_extra',    name: 'Extra Filament Rack', category: 'storage', price: 750,  unlockLevel: 16, effects: {},                                          description: 'More spools on the wall, more colours on hand.' },
    { id: 'flow_calib',    name: 'Flow Calibration', category: 'quality',    price: 520,  unlockLevel: 21, effects: { materialWaste: -0.4 },                     description: 'Less purge waste on every print.' },
    { id: 'speed_profile', name: 'Tuned Profiles',   category: 'printer',    price: 1250, unlockLevel: 22, effects: { speed: -0.08, failure: 0.02 },             description: 'Faster prints, at a slight reliability cost.' },
  ],
  demand: {
    min: 0.55,
    max: 1.9,
    shiftIntervalMs: 30 * 60 * 1000,
    step: 0.25,
  },
  levonis: {
    coinsPerPoint: 2500,
    weeklyPointCap: 150,
    minLevel: 10,
    minReputation: 50,
    enabled: false,
  },
  catalogs: {
    printers: PRINTER_CATALOG,
    materials: MATERIALS,
    colors: COLORS,
    products: PRODUCTS,
  },
};

type Plain = Record<string, unknown>;

function isPlainObject(v: unknown): v is Plain {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

/**
 * Deep-merge admin overrides over the defaults. Arrays are replaced wholesale
 * so an admin can swap the whole printer catalog, not just patch entry 0.
 */
export function mergeConfig(base: GameConfig, overrides: unknown): GameConfig {
  if (!isPlainObject(overrides)) return base;
  const walk = (b: unknown, o: unknown): unknown => {
    if (!isPlainObject(o)) return o === undefined ? b : o;
    if (!isPlainObject(b)) return o;
    const out: Plain = { ...b };
    for (const key of Object.keys(o)) {
      out[key] = walk((b as Plain)[key], (o as Plain)[key]);
    }
    return out;
  };
  return walk(base, overrides) as GameConfig;
}

/** XP required to advance from `level` to `level + 1`. */
export function xpForLevel(config: GameConfig, level: number): number {
  const { xpBase, xpExponent } = config.progression;
  return Math.round(xpBase * Math.pow(level, xpExponent));
}

/** Feature keys the player has unlocked at their current level. */
export function unlockedFeatures(config: GameConfig, level: number): Set<string> {
  const out = new Set<string>();
  for (const [lvl, keys] of Object.entries(config.progression.unlocks)) {
    if (level >= Number(lvl)) keys.forEach((k) => out.add(k));
  }
  return out;
}

export function hasFeature(config: GameConfig, level: number, key: string): boolean {
  return unlockedFeatures(config, level).has(key);
}
