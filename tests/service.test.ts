import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import fs from 'fs';
import os from 'os';
import path from 'path';

/**
 * Exercises the real server path — storage, config merge, intent dispatch and
 * persistence — rather than the pure engines. The file store stands in for
 * Cloudflare D1; both implement the same repository interface.
 */

const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'pf-test-'));
process.env.PF_DATA_DIR = dataDir;
delete process.env.CLOUDFLARE_ACCOUNT_ID;
delete process.env.CLOUDFLARE_DATABASE_ID;
delete process.env.CLOUDFLARE_API_TOKEN;

const { applyIntent, loadFarm, loadConfig } = await import('../server/game/service');
const { getStore } = await import('../server/store');

const PLAYER = 'test-player';

afterAll(() => {
  fs.rmSync(dataDir, { recursive: true, force: true });
});

describe('game service', () => {
  it('creates a farm on first contact and persists it', async () => {
    const first = await loadFarm(PLAYER);
    expect(first.created).toBe(true);
    expect(first.state.printers).toHaveLength(1);

    const second = await loadFarm(PLAYER);
    expect(second.created).toBe(false);
    expect(second.state.createdAt).toBe(first.state.createdAt);
  });

  it('gives different players different farms', async () => {
    const a = await loadFarm('player-a');
    const b = await loadFarm('player-b');
    expect(a.state.seed).not.toBe(b.state.seed);
  });

  it('rejects an unknown intent', async () => {
    const result = await applyIntent(PLAYER, 'give_me_coins' as never, {});
    expect(result.ok).toBe(false);
    expect(result.error).toBe('unknown_intent');
  });

  it('ignores client-supplied amounts entirely', async () => {
    const before = (await loadFarm(PLAYER)).state.coins;
    // A tampered client asking for a free spool and a pile of coins.
    const result = await applyIntent(PLAYER, 'buy_spool', {
      materialId: 'pla',
      colorId: 'red',
      count: 1,
      price: 0,
      coins: 999999,
    });
    expect(result.ok).toBe(true);
    const after = result.snapshot!.state;
    const config = await loadConfig();
    const pla = config.catalogs.materials.find((m) => m.id === 'pla')!;
    // Charged the catalog price, and the injected coin field did nothing.
    expect(after.coins).toBe(before - pla.pricePerSpool);
  });

  it('clamps a bulk purchase instead of trusting the count', async () => {
    const result = await applyIntent(PLAYER, 'buy_spool', {
      materialId: 'pla',
      colorId: 'blue',
      count: 10_000,
    });
    // Either refused for cost, or clamped — never 10,000 spools.
    if (result.ok) {
      const blue = result.snapshot!.state.spools.filter((s) => s.colorId === 'blue');
      expect(blue.length).toBeLessThanOrEqual(10);
    } else {
      expect(result.error).toBe('not_enough_coins');
    }
  });

  it('returns a snapshot stamped with the server clock', async () => {
    const result = await applyIntent(PLAYER, 'advance_tutorial', { step: 2 });
    expect(result.ok).toBe(true);
    expect(result.snapshot!.serverNow).toBeGreaterThan(0);
    expect(Math.abs(result.snapshot!.serverNow - Date.now())).toBeLessThan(5000);
  });

  it('writes an audit line for every intent, accepted or not', async () => {
    await applyIntent(PLAYER, 'buy_printer', { modelId: 'h2c', slotId: 's_0_0' });
    const raw = JSON.parse(fs.readFileSync(path.join(dataDir, 'printer-farm.json'), 'utf8'));
    const mine = raw.intents.filter((i: { userId: string }) => i.userId === PLAYER);
    expect(mine.length).toBeGreaterThan(0);
    expect(mine.some((i: { ok: boolean }) => i.ok === false)).toBe(true);
  });

  it('keeps the leaderboard ordered by farm value', async () => {
    const store = await getStore();
    const rows = await store.leaderboard('farmValue', 10);
    expect(rows.length).toBeGreaterThan(0);
    for (let i = 1; i < rows.length; i++) {
      expect(rows[i - 1].farmValue).toBeGreaterThanOrEqual(rows[i].farmValue);
    }
  });

  it('applies admin balancing overrides to every player', async () => {
    const store = await getStore();
    await store.setConfigOverrides({ economy: { coinPerGram: 42 } });
    const { invalidateConfig } = await import('../server/game/service');
    invalidateConfig();
    const config = await loadConfig(true);
    expect(config.economy.coinPerGram).toBe(42);
    await store.setConfigOverrides({});
    invalidateConfig();
  });
});
