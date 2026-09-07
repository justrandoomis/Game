/**
 * Player identity.
 *
 * Deliberately not a second auth system: it verifies the very same JWT the
 * Levonis platform issues from `/api/auth/login`, using the same JWT_SECRET.
 * Mounted inside the platform, a signed-in user is already a signed-in player.
 */

import type { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_jwt_key_123';

export interface PlayerRequest extends Request {
  player?: { id: string; email?: string };
}

/** Standalone dev only: no platform to sign us in, so use a stable local id. */
function devPlayer(req: Request): { id: string; email?: string } | null {
  if (process.env.NODE_ENV === 'production') return null;
  const header = req.header('x-pf-dev-user');
  return { id: header || 'dev-player', email: 'dev@local' };
}

export function requirePlayer(req: PlayerRequest, res: Response, next: NextFunction) {
  const header = req.header('authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';

  if (token) {
    try {
      const decoded = jwt.verify(token, JWT_SECRET) as { userId?: string; email?: string };
      if (decoded?.userId) {
        req.player = { id: String(decoded.userId), email: decoded.email };
        return next();
      }
    } catch {
      return res.status(401).json({ success: false, error: 'invalid_token' });
    }
  }

  const dev = devPlayer(req);
  if (dev) {
    req.player = dev;
    return next();
  }
  return res.status(401).json({ success: false, error: 'unauthenticated' });
}

/** Admin gate for the balancing endpoints. */
export function requireAdmin(req: PlayerRequest, res: Response, next: NextFunction) {
  const allowlist = (process.env.PF_ADMIN_EMAILS || 'aliamer59409@gmail.com')
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
  const email = req.player?.email?.toLowerCase();
  if (email && allowlist.includes(email)) return next();
  return res.status(403).json({ success: false, error: 'forbidden' });
}
