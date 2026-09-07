/**
 * Printer Farm API.
 *
 * Mounted at /api/game. Drop `createGameRouter()` into the platform's
 * `server.ts` (`app.use('/api/game', createGameRouter())`) and the game runs
 * on the existing Express app, the existing JWT and the existing database.
 */

import express, { type Router } from 'express';
import { requireAdmin, requirePlayer, type PlayerRequest } from '../auth';
import { getStore } from '../store';
import {
  applyIntent,
  invalidateConfig,
  loadConfig,
  loadFarm,
  snapshot,
  type IntentName,
} from './service';
import { summarize } from '../../shared/engines/state';
import { farmValue } from '../../shared/engines/derive';

const VALID_INTENTS = new Set<IntentName>([
  'accept_order', 'reject_order', 'assign_order', 'collect_order',
  'start_store_job', 'cancel_job', 'reorder_queue', 'clear_failure',
  'service_printer', 'repair_printer', 'buy_spool', 'buy_part',
  'buy_printer', 'sell_printer', 'move_printer', 'buy_upgrade',
  'unlock_slot', 'expand_workshop', 'advance_tutorial',
]);

/** Per-player intent throttle. A real game client never needs more than this. */
const RATE_LIMIT = { windowMs: 10_000, max: 40 };
const hits = new Map<string, number[]>();

function rateLimited(userId: string): boolean {
  const now = Date.now();
  const list = (hits.get(userId) ?? []).filter((t) => now - t < RATE_LIMIT.windowMs);
  list.push(now);
  hits.set(userId, list);
  if (hits.size > 5000) hits.clear();
  return list.length > RATE_LIMIT.max;
}

export function createGameRouter(): Router {
  const router = express.Router();
  router.use(express.json({ limit: '64kb' }));

  /** Static balancing data. Safe to cache client-side for a session. */
  router.get('/config', async (_req, res) => {
    try {
      const config = await loadConfig();
      res.json({ success: true, config, serverNow: Date.now() });
    } catch (err) {
      res.status(500).json({ success: false, error: (err as Error).message });
    }
  });

  /** The player's farm, brought up to date, plus what they missed. */
  router.get('/state', requirePlayer, async (req: PlayerRequest, res) => {
    try {
      const { state, report, created } = await loadFarm(req.player!.id);
      res.json({ success: true, ...snapshot(state, report), created });
    } catch (err) {
      res.status(500).json({ success: false, error: (err as Error).message });
    }
  });

  /** The one write endpoint. Everything the player does goes through here. */
  router.post('/intent', requirePlayer, async (req: PlayerRequest, res) => {
    const userId = req.player!.id;
    if (rateLimited(userId)) {
      return res.status(429).json({ success: false, error: 'rate_limited' });
    }
    const intent = String(req.body?.intent ?? '') as IntentName;
    if (!VALID_INTENTS.has(intent)) {
      return res.status(400).json({ success: false, error: 'unknown_intent' });
    }
    const payload = (req.body?.payload ?? {}) as Record<string, unknown>;
    try {
      const result = await applyIntent(userId, intent, payload);
      if (!result.ok) {
        return res.status(200).json({ success: false, error: result.error, fx: result.fx });
      }
      res.json({ success: true, fx: result.fx, ...result.snapshot });
    } catch (err) {
      res.status(500).json({ success: false, error: (err as Error).message });
    }
  });

  router.get('/leaderboard', requirePlayer, async (req: PlayerRequest, res) => {
    try {
      const metricParam = String(req.query.metric ?? 'farmValue');
      const metric = (['farmValue', 'reputation', 'ordersCompleted', 'level'] as const).find(
        (m) => m === metricParam,
      ) ?? 'farmValue';
      const store = await getStore();
      const rows = await store.leaderboard(metric, 25);
      res.json({ success: true, metric, rows, me: req.player!.id });
    } catch (err) {
      res.status(500).json({ success: false, error: (err as Error).message });
    }
  });

  /**
   * Farm Coins → Levonis Points.
   *
   * Deliberately conservative: off unless an admin enables it, gated on level
   * and reputation, and capped per rolling week. The endpoint only *reserves*
   * the points and logs the claim — crediting the platform wallet is the
   * platform's own transaction, so the two ledgers never diverge here.
   */
  router.post('/levonis/claim', requirePlayer, async (req: PlayerRequest, res) => {
    try {
      const config = await loadConfig();
      const rules = config.levonis;
      if (!rules.enabled) {
        return res.json({ success: false, error: 'conversion_disabled' });
      }
      const { state } = await loadFarm(req.player!.id);
      if (state.level < rules.minLevel) return res.json({ success: false, error: 'level_too_low' });
      if (state.reputation < rules.minReputation) return res.json({ success: false, error: 'reputation_too_low' });

      const requested = Math.floor(Number(req.body?.points ?? 0));
      if (!Number.isFinite(requested) || requested <= 0) {
        return res.json({ success: false, error: 'invalid_amount' });
      }

      const store = await getStore();
      const weekAgo = Date.now() - 7 * 86_400_000;
      const claimed = await store.pointsClaimedSince(req.player!.id, weekAgo);
      if (claimed + requested > rules.weeklyPointCap) {
        return res.json({ success: false, error: 'weekly_cap_reached', remaining: Math.max(0, rules.weeklyPointCap - claimed) });
      }

      const coinCost = requested * rules.coinsPerPoint;
      if (state.coins < coinCost) return res.json({ success: false, error: 'not_enough_coins' });

      // Re-read immediately before the debit so a concurrent request cannot
      // spend the same coins twice, then record the claim for the weekly cap.
      const { state: fresh } = await loadFarm(req.player!.id);
      if (fresh.coins < coinCost) return res.json({ success: false, error: 'not_enough_coins' });
      fresh.coins -= coinCost;
      fresh.stats.coinsSpent += coinCost;
      await store.saveFarm({
        userId: req.player!.id,
        state: JSON.stringify(fresh),
        level: fresh.level,
        coins: Math.round(fresh.coins),
        reputation: fresh.reputation,
        farmValue: farmValue(config, fresh.printers, fresh.spools, fresh.coins),
        ordersCompleted: fresh.stats.ordersCompleted,
        updatedAt: Date.now(),
      });
      await store.recordPointClaim(req.player!.id, requested, coinCost, Date.now());

      res.json({ success: true, points: requested, coinsSpent: coinCost, ...snapshot(fresh) });
    } catch (err) {
      res.status(500).json({ success: false, error: (err as Error).message });
    }
  });

  /* ------------------------------------------------------------- admin */

  router.get('/admin/config', requirePlayer, requireAdmin, async (_req, res) => {
    const store = await getStore();
    res.json({ success: true, overrides: await store.getConfigOverrides(), resolved: await loadConfig(true) });
  });

  router.post('/admin/config', requirePlayer, requireAdmin, async (req, res) => {
    try {
      const store = await getStore();
      await store.setConfigOverrides(req.body?.overrides ?? {});
      invalidateConfig();
      res.json({ success: true, resolved: await loadConfig(true) });
    } catch (err) {
      res.status(500).json({ success: false, error: (err as Error).message });
    }
  });

  router.get('/admin/player/:id', requirePlayer, requireAdmin, async (req, res) => {
    try {
      const config = await loadConfig();
      const { state } = await loadFarm(String(req.params.id));
      res.json({ success: true, summary: summarize(config, state), state });
    } catch (err) {
      res.status(500).json({ success: false, error: (err as Error).message });
    }
  });

  return router;
}
