/**
 * LEVO Printer Farm — shared domain types.
 *
 * This module is isomorphic: it is imported by the Express game API and by the
 * React client. It must never import React, Node built-ins or browser globals.
 */

export type MaterialId = string;
export type ColorId = string;
export type ProductId = string;
export type PrinterModelId = string;
export type PartId = string;
export type SlotId = string;

export type PrinterStatus =
  | 'idle'
  | 'printing'
  | 'paused'
  | 'maintenance'
  | 'failed'
  | 'offline';

export type JobStatus = 'queued' | 'printing' | 'done' | 'failed' | 'collected';

export type OrderStatus =
  | 'offered'
  | 'accepted'
  | 'in_progress'
  | 'ready'
  | 'delivered'
  | 'failed'
  | 'expired'
  | 'rejected';

export type CustomerTier =
  | 'individual'
  | 'small_business'
  | 'merchant'
  | 'company'
  | 'industrial';

export type FailureKind =
  | 'spaghetti'
  | 'first_layer'
  | 'clogged_nozzle'
  | 'filament_runout'
  | 'ams_jam'
  | 'part_detached'
  | 'mechanical';

/** A physical filament spool sitting on the workshop rack. */
export interface Spool {
  id: string;
  materialId: MaterialId;
  colorId: ColorId;
  /** Grams remaining. */
  grams: number;
  /** Grams the spool held when new — drives the fill indicator. */
  capacity: number;
  /** 0..100. Higher quality lowers failure probability. */
  quality: number;
}

export interface Printer {
  id: string;
  modelId: PrinterModelId;
  /** Grid slot this machine stands on, or null while in storage. */
  slotId: SlotId | null;
  /** 0..100 */
  health: number;
  status: PrinterStatus;
  /** Job ids, in execution order. Index 0 is the active job. */
  queue: string[];
  /** Cumulative operating hours — drives maintenance intervals. */
  hours: number;
  prints: number;
  upgrades: string[];
  purchasedAt: number;
  /** Set while status === 'maintenance'; server ms when the bench frees up. */
  maintenanceUntil?: number;
}

export interface Job {
  id: string;
  /** Customer order this job serves, or null for store production. */
  orderId: string | null;
  productId: ProductId;
  qty: number;
  printerId: string;
  materialId: MaterialId;
  colorId: ColorId;
  /** Spool the grams were reserved from, so a failure can return the remainder. */
  spoolId: string;
  /** Grams reserved for this job. */
  grams: number;
  durationMs: number;
  /** Server ms. Null while the job waits in a queue. */
  startedAt: number | null;
  status: JobStatus;
  failure?: FailureKind;
  /** 0..1 progress reached when the print failed. */
  failedAt?: number;
}

export interface Order {
  id: string;
  productId: ProductId;
  qty: number;
  tier: CustomerTier;
  customerName: string;
  materialId: MaterialId;
  colorId: ColorId;
  /** Total grams for the whole order. */
  grams: number;
  /** Total print milliseconds for the whole order on a baseline printer. */
  printMs: number;
  offeredAt: number;
  /** Server ms after which an un-accepted offer disappears from the board. */
  expiresAt: number;
  acceptedAt: number | null;
  /** Delivery window granted on accept, in ms. */
  deadlineMs: number;
  /** Server ms the order must be delivered by. Set on accept. */
  dueAt: number | null;
  /** Server ms every job finished and the order became collectable. */
  readyAt?: number | null;
  /** Delivered (or delivering) after the deadline — pays the reduced rate. */
  late?: boolean;
  reward: number;
  repReward: number;
  /** 1 (easy) .. 5 (hard) */
  difficulty: number;
  status: OrderStatus;
  jobIds: string[];
}

export interface FarmStats {
  ordersCompleted: number;
  ordersFailed: number;
  ordersLate: number;
  printsCompleted: number;
  printsFailed: number;
  coinsEarned: number;
  coinsSpent: number;
  gramsPrinted: number;
  storeSales: number;
}

export interface LogEntry {
  at: number;
  kind: string;
  /** i18n key suffix under `log.` plus interpolation values. */
  msg: string;
  data?: Record<string, string | number>;
}

export interface FarmState {
  /** Save-format version, for forward migration. */
  v: number;
  createdAt: number;
  /** Server ms of the last authoritative resolution pass. */
  lastResolvedAt: number;
  /** Workshop tier index into GameConfig.workshop.tiers. */
  tier: number;
  level: number;
  xp: number;
  coins: number;
  /** 0..100 */
  reputation: number;
  unlockedSlots: SlotId[];
  printers: Printer[];
  spools: Spool[];
  jobs: Job[];
  orders: Order[];
  /** Finished goods held for the in-game store. */
  storeStock: Record<ProductId, number>;
  /** Demand multiplier per product, drifts over time. */
  demand: Record<ProductId, number>;
  parts: Record<PartId, number>;
  stats: FarmStats;
  achievements: string[];
  /** Deterministic RNG seed. Advanced by the server only. */
  seed: number;
  /** Monotonic counter behind every generated entity id. */
  idSeq: number;
  lastOrderSpawnAt: number;
  lastDemandShiftAt: number;
  lastStoreSaleAt: number;
  tutorialStep: number;
  log: LogEntry[];
}

/** What happened while the player was away, surfaced on the next visit. */
export interface AwayReport {
  elapsedMs: number;
  printsCompleted: number;
  printsFailed: number;
  ordersDelivered: number;
  ordersExpired: number;
  coinsEarned: number;
  storeSales: number;
  newOrders: number;
  maintenanceNeeded: number;
  leveledUpTo?: number;
}

/** The full payload the client renders from. */
export interface FarmSnapshot {
  state: FarmState;
  /** Server clock at the moment the snapshot was produced. */
  serverNow: number;
  report?: AwayReport;
}
