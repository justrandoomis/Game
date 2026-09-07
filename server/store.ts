/**
 * Storage adapter.
 *
 * In production the game talks to the same Cloudflare D1 database the rest of
 * Levonis uses, through the same REST helper `server.ts` already relies on. If
 * those credentials are absent the server falls back to a local JSON store so
 * the game is runnable standalone in development without a second database.
 *
 * The interface is deliberately repository-shaped rather than SQL-shaped: game
 * saves are a single JSON document per player, which keeps D1 round-trips to
 * one read and one write per request.
 */

import fs from 'fs';
import path from 'path';

export interface FarmRow {
  userId: string;
  state: string;
  level: number;
  coins: number;
  reputation: number;
  farmValue: number;
  ordersCompleted: number;
  updatedAt: number;
}

export interface LeaderboardRow {
  userId: string;
  name: string;
  level: number;
  farmValue: number;
  reputation: number;
  ordersCompleted: number;
}

export interface GameStore {
  init(): Promise<void>;
  getFarm(userId: string): Promise<FarmRow | null>;
  saveFarm(row: FarmRow): Promise<void>;
  getConfigOverrides(): Promise<unknown>;
  setConfigOverrides(value: unknown): Promise<void>;
  leaderboard(metric: 'farmValue' | 'reputation' | 'ordersCompleted' | 'level', limit: number): Promise<LeaderboardRow[]>;
  /** Append-only audit trail — every accepted intent, for anti-cheat review. */
  logIntent(userId: string, intent: string, payload: unknown, ok: boolean, at: number): Promise<void>;
  /** Levonis Points claimed by a player inside a rolling window. */
  pointsClaimedSince(userId: string, since: number): Promise<number>;
  recordPointClaim(userId: string, points: number, coins: number, at: number): Promise<void>;
}

/* ------------------------------------------------------------- D1 backend */

async function d1(sql: string, params: unknown[] = []): Promise<any[]> {
  const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
  const dbId = process.env.CLOUDFLARE_DATABASE_ID;
  const token = process.env.CLOUDFLARE_API_TOKEN;
  const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/d1/database/${dbId}/query`;
  const response = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ sql, params }),
  });
  const data: any = await response.json();
  if (!data.success) throw new Error(data.errors?.[0]?.message || 'D1 query failed');
  return data.result[0].results ?? [];
}

class D1Store implements GameStore {
  async init() {
    await d1(`CREATE TABLE IF NOT EXISTS pf_farms (
      user_id TEXT PRIMARY KEY,
      state TEXT NOT NULL,
      level INTEGER DEFAULT 1,
      coins INTEGER DEFAULT 0,
      reputation REAL DEFAULT 0,
      farm_value INTEGER DEFAULT 0,
      orders_completed INTEGER DEFAULT 0,
      updated_at INTEGER DEFAULT 0
    )`);
    await d1(`CREATE TABLE IF NOT EXISTS pf_config (key TEXT PRIMARY KEY, value TEXT)`);
    await d1(`CREATE TABLE IF NOT EXISTS pf_intents (
      id TEXT PRIMARY KEY,
      user_id TEXT,
      intent TEXT,
      payload TEXT,
      ok INTEGER,
      created_at INTEGER
    )`);
    await d1(`CREATE TABLE IF NOT EXISTS pf_point_claims (
      id TEXT PRIMARY KEY,
      user_id TEXT,
      points INTEGER,
      coins INTEGER,
      created_at INTEGER
    )`);
  }

  async getFarm(userId: string): Promise<FarmRow | null> {
    const rows = await d1('SELECT * FROM pf_farms WHERE user_id = ?', [userId]);
    if (!rows.length) return null;
    const r = rows[0];
    return {
      userId: r.user_id,
      state: r.state,
      level: r.level,
      coins: r.coins,
      reputation: r.reputation,
      farmValue: r.farm_value,
      ordersCompleted: r.orders_completed,
      updatedAt: r.updated_at,
    };
  }

  async saveFarm(row: FarmRow) {
    await d1(
      `INSERT INTO pf_farms (user_id, state, level, coins, reputation, farm_value, orders_completed, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET
         state = excluded.state, level = excluded.level, coins = excluded.coins,
         reputation = excluded.reputation, farm_value = excluded.farm_value,
         orders_completed = excluded.orders_completed, updated_at = excluded.updated_at`,
      [row.userId, row.state, row.level, row.coins, row.reputation, row.farmValue, row.ordersCompleted, row.updatedAt],
    );
  }

  async getConfigOverrides() {
    const rows = await d1('SELECT value FROM pf_config WHERE key = ?', ['balance']);
    if (!rows.length) return null;
    try {
      return JSON.parse(rows[0].value);
    } catch {
      return null;
    }
  }

  async setConfigOverrides(value: unknown) {
    await d1(
      `INSERT INTO pf_config (key, value) VALUES (?, ?)
       ON CONFLICT(key) DO UPDATE SET value = excluded.value`,
      ['balance', JSON.stringify(value ?? {})],
    );
  }

  async leaderboard(metric: string, limit: number): Promise<LeaderboardRow[]> {
    const column = {
      farmValue: 'farm_value',
      reputation: 'reputation',
      ordersCompleted: 'orders_completed',
      level: 'level',
    }[metric] ?? 'farm_value';
    const rows = await d1(
      `SELECT f.user_id, f.level, f.farm_value, f.reputation, f.orders_completed,
              COALESCE(u.username, u.name, 'Player') AS name
         FROM pf_farms f LEFT JOIN users u ON u.id = f.user_id
        ORDER BY f.${column} DESC LIMIT ?`,
      [limit],
    );
    return rows.map((r: any) => ({
      userId: r.user_id,
      name: r.name,
      level: r.level,
      farmValue: r.farm_value,
      reputation: r.reputation,
      ordersCompleted: r.orders_completed,
    }));
  }

  async logIntent(userId: string, intent: string, payload: unknown, ok: boolean, at: number) {
    await d1('INSERT INTO pf_intents (id, user_id, intent, payload, ok, created_at) VALUES (?, ?, ?, ?, ?, ?)', [
      `${at}_${Math.random().toString(36).slice(2, 8)}`,
      userId,
      intent,
      JSON.stringify(payload ?? {}).slice(0, 2000),
      ok ? 1 : 0,
      at,
    ]);
  }

  async pointsClaimedSince(userId: string, since: number) {
    const rows = await d1('SELECT SUM(points) AS total FROM pf_point_claims WHERE user_id = ? AND created_at >= ?', [userId, since]);
    return Number(rows[0]?.total ?? 0);
  }

  async recordPointClaim(userId: string, points: number, coins: number, at: number) {
    await d1('INSERT INTO pf_point_claims (id, user_id, points, coins, created_at) VALUES (?, ?, ?, ?, ?)', [
      `${at}_${Math.random().toString(36).slice(2, 8)}`,
      userId,
      points,
      coins,
      at,
    ]);
  }
}

/* ------------------------------------------------------------ file backend */

interface FileData {
  farms: Record<string, FarmRow>;
  config: unknown;
  intents: Array<{ userId: string; intent: string; ok: boolean; at: number }>;
  claims: Array<{ userId: string; points: number; coins: number; at: number }>;
  names: Record<string, string>;
}

class FileStore implements GameStore {
  private file: string;
  private data: FileData = { farms: {}, config: null, intents: [], claims: [], names: {} };

  constructor(dir: string) {
    this.file = path.join(dir, 'printer-farm.json');
  }

  async init() {
    const dir = path.dirname(this.file);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    if (fs.existsSync(this.file)) {
      try {
        this.data = { ...this.data, ...JSON.parse(fs.readFileSync(this.file, 'utf8')) };
      } catch {
        /* a corrupt dev save should not stop the server booting */
      }
    }
  }

  private flush() {
    // Keep the audit trail bounded in dev.
    if (this.data.intents.length > 500) this.data.intents = this.data.intents.slice(-500);
    fs.writeFileSync(this.file, JSON.stringify(this.data));
  }

  async getFarm(userId: string) {
    return this.data.farms[userId] ?? null;
  }

  async saveFarm(row: FarmRow) {
    this.data.farms[row.userId] = row;
    this.flush();
  }

  async getConfigOverrides() {
    return this.data.config;
  }

  async setConfigOverrides(value: unknown) {
    this.data.config = value;
    this.flush();
  }

  async leaderboard(metric: string, limit: number): Promise<LeaderboardRow[]> {
    const key = metric as keyof FarmRow;
    return Object.values(this.data.farms)
      .map((f) => ({
        userId: f.userId,
        name: this.data.names[f.userId] ?? `Player ${f.userId.slice(0, 4)}`,
        level: f.level,
        farmValue: f.farmValue,
        reputation: f.reputation,
        ordersCompleted: f.ordersCompleted,
      }))
      .sort((a, b) => Number((b as any)[key] ?? 0) - Number((a as any)[key] ?? 0))
      .slice(0, limit);
  }

  async logIntent(userId: string, intent: string, _payload: unknown, ok: boolean, at: number) {
    this.data.intents.push({ userId, intent, ok, at });
    this.flush();
  }

  async pointsClaimedSince(userId: string, since: number) {
    return this.data.claims
      .filter((c) => c.userId === userId && c.at >= since)
      .reduce((sum, c) => sum + c.points, 0);
  }

  async recordPointClaim(userId: string, points: number, coins: number, at: number) {
    this.data.claims.push({ userId, points, coins, at });
    this.flush();
  }

  setName(userId: string, name: string) {
    this.data.names[userId] = name;
  }
}

let store: GameStore | null = null;

export function hasD1(): boolean {
  return !!(
    process.env.CLOUDFLARE_ACCOUNT_ID &&
    process.env.CLOUDFLARE_DATABASE_ID &&
    process.env.CLOUDFLARE_API_TOKEN
  );
}

export async function getStore(): Promise<GameStore> {
  if (store) return store;
  store = hasD1() ? new D1Store() : new FileStore(process.env.PF_DATA_DIR || '.data');
  await store.init();
  return store;
}
