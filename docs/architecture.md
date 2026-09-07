# Architecture

## The separation that matters

```
┌─────────────────────────────────────── Godot 4.8 client ───────────────────┐
│                                                                            │
│  scenes/farm/          scenes/ui/            autoload/                     │
│  ─────────────         ──────────            ─────────                     │
│  Farm.tscn             TopHUD                GameState   the snapshot      │
│  PrinterStation.tscn   BottomNav             Config      balancing data    │
│  Printer.tscn          OrderPopup            ServerClock trusted time      │
│  FilamentRack.tscn     BottomSheet           Net         HTTP transport    │
│  MaintenanceBench.tscn screens/*             I18n        en / ar / ku      │
│  Worker.tscn           FxLayer               Audio       cues + mute       │
│  EmptySlot.tscn                              Events      signal bus        │
│                                                                            │
│  scripts/core/  Iso (the grid)  IsoDraw  Palette  Shapes  Val              │
└────────────────────────────────┬───────────────────────────────────────────┘
                                 │  GET /api/game/state
                                 │  POST /api/game/intent
┌────────────────────────────────▼───────────────────────────────────────────┐
│                        Node / TypeScript backend                           │
│                                                                            │
│  server/game/router.ts    the API surface, rate limiting, admin, leaderboard│
│  server/game/service.ts   load → resolve → apply intent → persist          │
│  server/store.ts          D1 in production, JSON file in development        │
│  server/auth.ts           verifies the platform's own JWT                   │
│                                                                            │
│  shared/grid.ts           the grid, mirrored by Iso.gd                     │
│  shared/config/*          every balancing number in the game               │
│  shared/engines/*         the simulation                                    │
└────────────────────────────────────────────────────────────────────────────┘
```

`shared/` is isomorphic and imports nothing from React, Node or a browser. It
is the simulation; everything else is transport or presentation.

## Request shape

Every request follows the same five steps, and there is no other path that
changes a player's state:

1. **Load** the save (or create one on first contact).
2. **Resolve** — replay everything that fell due since `lastResolvedAt`.
3. **Apply** the intent, re-deriving every cost from config.
4. **Persist** the whole state as one JSON document plus indexed columns.
5. **Snapshot** back, stamped with `serverNow`.

Step 2 runs on reads too, which is why offline progression needs no cron job
and no background worker.

## The engines

| Module | Owns |
|---|---|
| `resolve.ts` | The event loop. Job completion, deadlines, auto-delivery, maintenance, order spawning, store sales, demand drift. |
| `intents.ts` | Every player action, and the validation behind it. |
| `jobEngine.ts` | Order generation and the multi-printer split. |
| `failures.ts` | Failure probability from health, reliability, material, complexity, spool quality and upgrades. |
| `economy.ts` | Rewards, prices, resale, station costs. |
| `inventory.ts` | Reserving and refunding filament. |
| `maintenance.ts` | Health decay and service actions. |
| `reputation.ts` | Reputation, its decay, and which customers will talk to you. |
| `progression.ts` | XP, levels and feature gates. |
| `derive.ts` | Effective stats, durations, grams, farm value. |
| `rng.ts` | Seeded randomness. Nothing calls `Math.random()`. |

### Determinism

Every committed outcome is seeded from a stable id — a print's success is
`rngFor('fail', job.id)`, an order's contents are `rngFor('order', seed, nonce)`.
Resolving the same state twice therefore produces the same result, which is
what lets the server recompute a player's absence idempotently on every read.

The test suite asserts this directly: resolving one long window in a single
step and in many small steps produces identical coins and print counts.

## The rendering approach

The farm ships **no sprite atlas and no 3D models**. Every solid is drawn from
flat polygons through two primitives in `IsoDraw.gd` — an isometric box and an
isometric diamond. That is a deliberate choice for this game:

- Every station is drawn by the same routine, so none can end up at a slightly
  different angle or size from its neighbour.
- Machines, filament colours and floor tiers recolour from the palette for free.
- It is tiny to download and cheap to draw on a mid-range phone.
- It stays crisp at any pixel density and any zoom.

Printed parts are a stack of thin isometric slabs, and only the layers printed
so far are drawn — so a part genuinely appears layer by layer as the job runs,
without slicing anything.

### Keeping it cheap

- A running printer redraws only when a **layer lands**, not every frame.
- The printhead is its own node, so its sweep is a transform, not a redraw.
- Progress and countdowns tick at **5 Hz**, not per frame.
- Off-screen screens are hidden **and** have their processing disabled.
- Depth ordering is Godot's built-in Y-sort, which is exact here because screen
  Y is proportional to isometric depth in this projection.
- Taps hit-test station rectangles front to back rather than using physics.

## Localisation

English, Arabic and Kurdish, matching the platform. Arabic and Kurdish set the
UI to right-to-left.

The farm scene is **never mirrored**. Only text and UI flow adapt; the
isometric geometry, the grid and the station layout stay identical in every
language, because mirroring the scene would break the single fixed perspective
the art direction depends on.
