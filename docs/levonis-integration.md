# Mounting Printer Farm inside Levonis

The game is built to slot into the existing platform rather than stand beside
it. Nothing here duplicates a system Levonis already has.

## What is reused, not rebuilt

| System | How the game uses it |
|---|---|
| **Authentication** | `server/auth.ts` verifies the same JWT `/api/auth/login` issues, with the same `JWT_SECRET`. Signed into Levonis means signed into the game. |
| **Users** | Player identity is the `users.id` already in the token. No second profile. |
| **Database** | The same Cloudflare D1 database, through the same REST helper `server.ts` uses. New tables are prefixed `pf_`. |
| **Levonis Points** | Read and awarded by the platform's own wallet. The game only *requests* a capped conversion; it never credits points itself. |
| **Tickets** | The platform's tickets gate special contracts and events. Normal play needs none. |
| **Localisation** | Same three languages, same RTL behaviour, same Cairo typeface. |
| **Admin** | Balancing is a row in `pf_config`, editable from the existing admin area. |

## Wiring it up

### 1. Mount the router

In the platform's `server.ts`, beside the existing routes:

```ts
import { createGameRouter } from './game/router';

app.use('/api/game', createGameRouter());
```

It brings its own `express.json()` with a 64 KB cap, its own auth middleware
and its own rate limiting. It touches no existing route.

### 2. Copy the game's server code in

```
server/auth.ts          server/store.ts       server/game/*
shared/grid.ts          shared/types.ts       shared/config/*   shared/engines/*
```

`shared/` has no dependencies beyond TypeScript itself.

### 3. Create the tables

`GameStore.init()` runs the DDL on first use — `pf_farms`, `pf_config`,
`pf_intents`, `pf_point_claims` — so there is no separate migration step. It
is `CREATE TABLE IF NOT EXISTS` throughout and leaves existing tables alone.

### 4. Export the Godot client to Web

Needs the export templates matching the engine build — for a dev snapshot that
means the dev templates, not the stable ones.

```bash
godot --headless --path godot --export-release "Web" ../client/web/index.html
```

Serve `client/web/` from the platform with cross-origin isolation headers —
Godot's threaded Web build requires them:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

`server/index.ts` already sets these when it serves `client/web/`.

### 5. Link it from the platform

The platform already has a `/games` hub (`src/pages/Games.tsx`) and full-screen
route handling in `App.tsx`. Add Printer Farm as an entry pointing at the
exported build. The client reads the JWT from the same `auth_token`
localStorage key `AuthContext` writes, so no extra sign-in step is needed.

For a native build, pass the token in with `Net.set_token()` after whatever
sign-in flow the app uses.

## Keeping the two economies apart

Farm Coins are game currency and never leave the game. Levonis Points are real
platform rewards.

`POST /api/game/levonis/claim` is the only bridge, and it is deliberately
narrow:

- **off** unless an admin sets `levonis.enabled`
- minimum level and minimum reputation
- a per-player rolling weekly cap
- coins debited server-side, re-read immediately before the debit so two
  concurrent requests cannot spend the same balance
- every claim written to `pf_point_claims`

The endpoint reserves and records the claim; **crediting the platform wallet
stays the platform's own transaction**, so the two ledgers never diverge inside
this module.

## Configuration

Add nothing new. The game reads variables the platform already sets:

```
CLOUDFLARE_ACCOUNT_ID     CLOUDFLARE_DATABASE_ID     CLOUDFLARE_API_TOKEN
JWT_SECRET
PF_ADMIN_EMAILS           optional, defaults to the existing admin address
```

Without the Cloudflare variables the backend falls back to a JSON file store so
the game can be run and reviewed on its own.
