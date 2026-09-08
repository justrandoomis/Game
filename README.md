# LEVO Printer Farm

A 3D-printing management game for the **Levonis** platform. The player starts
with one small printer on one workbench and grows it into an organised,
profitable print farm.

The farm itself is the game. It is a fixed-perspective isometric workshop where
every machine stands on a real grid slot, every empty bay is somewhere the farm
can visibly grow into, and every print you can watch happening.

---

## Two halves

| | | |
|---|---|---|
| **`godot/`** | Godot 4.8 client | The farm, the stations, the animations, the touch controls, the five screens. Presentation only. |
| **`shared/` + `server/`** | Node/TypeScript backend | The simulation and the economy. Authoritative for everything the player owns. |

The split is deliberate and load-bearing: **Godot is the game client, not the
economic authority.** It never decides that a print finished, that an order
paid out, or that a spool has 200 g left. It asks, renders and sends intents.

```
Godot client                    Levonis backend
────────────                    ───────────────
 render the farm   ◄── snapshot ──  resolve everything due since last time
 player taps       ─── intent ──►   validate, mutate, persist, re-snapshot
 interpolate       ◄── serverNow ── the only clock either side trusts
```

---

## Running it

```bash
# Backend (also serves an exported Web build from client/web)
npm install
npm run dev          # http://localhost:3000

# Client — open godot/ in Godot 4.8, or:
godot --path godot                      # runs against http://localhost:3000
godot --path godot -- --selftest        # boot check for CI, prints a summary
```

With no Cloudflare credentials the backend keeps saves in `.data/` so the game
runs standalone. Point `CLOUDFLARE_*` at the Levonis D1 database and it uses
that instead — see `.env.example`.

```bash
npm test             # 51 tests over the grid, the simulation and the server
npm run lint         # tsc --noEmit
npm run game:check   # imports the Godot project and boots it against the API
npm run game:bake    # re-renders the workshop props from the KayKit models
```

`game:bake` is the only script that needs a display, because it renders. On a
headless machine: `xvfb-run -a godot --path godot res://tools/BakeProps.tscn`.
You only need it after editing `godot/tools/prop_recipes.json` — the sprites it
produces are committed.

### Engine version

The project targets **Godot 4.8** (verified against `4.8-dev4`). It uses no
4.8-only API: it was developed and also verified running unchanged on
4.3-stable, so if you need a stable-only build, lowering `config/features` in
`godot/project.godot` back to `"4.3"` is the whole change.

4.8 also writes a `.uid` file beside every script. Those are committed: they
are how the engine keeps resource references stable across renames, and Godot
expects them in version control.

4.8-dev4 is a development snapshot. Engine APIs can move between dev snapshots,
and exporting needs the matching dev export templates — worth pinning the exact
build for anyone else working on this.

On a **fresh checkout** Godot needs two import passes: the first one imports
the font and audio, and the theme that references the font only resolves on the
second. That is normal for any Godot project with assets, and `npm run
game:check` does both — a single pass will print font errors and is not a
failure.

---

## The farm grid

This is the rule the whole scene is built on, and the reason the workshop reads
as clean rows and columns however large it gets:

> **Nothing in the farm is ever positioned by hand or at random.**

Every station, empty bay, floor tile, filament rack, bench, plant and packing
box derives its position from one function — `Iso.cell_to_world(row, col)` in
`godot/scripts/core/Iso.gd`, mirrored by `shared/grid.ts` on the server.

- One fixed 2:1 dimetric projection. The camera pans and zooms; it never
  rotates, so one drawing routine is correct for every slot in the room.
- One `PrinterStation.tscn`, identical everywhere. Same table, same height,
  same orientation, same spacing. Only the machine standing on it changes.
- Slot ids (`s_<row>_<col>`) are save keys shared by client and server.
- Stations unlock in reading order, so the farm always fills out evenly.
- Multi-cell machines (2×1, 2×2) occupy more of the grid rather than breaking it.
- Fixtures and decor live on a one-cell **service band** around the grid — also
  grid cells, so they can never float off the floor or crowd a station.

Growing the workshop grows the room:

| Tier | Room | Stations |
|---|---|---|
| Tiny Workshop | 2 × 2 | 2 |
| Small Workshop | 2 × 3 | 4 |
| Garage | 3 × 4 | 8 |
| Print Farm | 4 × 5 | 16 |
| Industrial Farm | 6 × 6 | 36 |

---

## Server authority

The client cannot give itself anything. There is exactly one write endpoint:

```
POST /api/game/intent   { intent: "accept_order", payload: { orderId } }
```

No amounts, no prices, no timestamps, no outcomes. The server re-derives the
cost from config, checks the player can afford it and is allowed it, mutates,
persists, and returns a whole fresh snapshot that replaces the client's copy.
Every intent is written to an audit table whether it succeeded or not.

**Time** is never taken from the device. A job stores the server's
`startedAt` and its `durationMs`; progress is `(serverNow - startedAt) /
durationMs`. Between snapshots the client advances its clock on Godot's
monotonic tick counter, so changing the phone's date cannot move a print
forward or make a deadline pass.

**Offline progress** is not simulated tick by tick. `resolveFarm()` replays
whatever fell due between `lastResolvedAt` and now, in strict event order, and
returns a report of what the player missed. Running it twice over the same
window changes nothing, which is what makes it safe to recompute on every
request.

---

## Balancing

Every number the game balances on lives in `shared/config/` — printer stats,
filament prices, products, order generation, rewards, reputation, failure
odds, maintenance, level gates, workshop tiers, Levonis Points limits. No
component contains an economy constant.

Admins override any of it in the `pf_config` table:

```
GET  /api/game/admin/config
POST /api/game/admin/config   { overrides: { economy: { coinPerGram: 2.4 } } }
```

Overrides deep-merge over the defaults; arrays replace wholesale, so a whole
catalog can be swapped without a deploy.

---

## Farm Coins vs Levonis Points

**Farm Coins** are the game's own currency and stay inside the game.

**Levonis Points** are the platform's real reward currency. Conversion is
deliberately hard to reach and is **off by default**: it needs an admin to
enable it, a minimum level, a minimum reputation, and it is capped per rolling
week per player, with every claim recorded. There is no unlimited farming path.


---

## Where the art comes from

The workshop is drawn from two sources that share one perspective.

**Anything that shows live state is drawn as flat polygons** through
`IsoDraw.gd` — the machines, the part appearing on the plate layer by layer,
each spool and how much filament is left on it, status lights, empty bays. It
recolours from `Palette.gd` for free, which is why a fleet in six shell
colours costs one drawing routine.

**The furniture is modelled.** Work tables, walls, shelving, crates, plants
and the rug come from [KayKit](https://kaylousberg.com) low-poly packs. They
are not loaded as meshes. `godot/tools/BakeProps.gd` renders each chosen model
once, offline, through an orthographic camera set to the game's own
projection — yaw 45°, pitch 30°, which is exactly the 2:1 dimetric the rest of
the farm is drawn in — and writes a sprite plus the anchor pixel that has to
land on a grid position:

```
godot/assets/kaykit/     source models, unmodified   (build input, never shipped)
godot/tools/             prop_recipes.json + the baker
godot/assets/props/      the sprites and props.json  (what the game draws)
```

Which models are used, and at what size, is entirely
`godot/tools/prop_recipes.json`. Two scales matter:

| | px per model unit | why |
|---|---|---|
| props | 44 | a 2-unit table lands 124 px wide — 84% of a 148 px cell, so stations keep a visible gap |
| walls | 26.163 | `TILE_W / 2 / (4·cos45°)`, so a 4-unit KayKit wall spans **exactly one cell edge** and wall runs tile the room with no seam |

That second number is the point: the room's shell is built from the same grid
as the machines, so it grows with the workshop and stays square to it.

Sprites are baked at 2× and drawn with mipmaps, so they stay sharp when the
player pinches in and quiet when a 6×6 farm is framed whole. The source models
are excluded from every export preset — the shipped web build contains no
mesh, no material and no glTF, only ~300 KB of PNG.

Nothing about the scene graph changed to get modelled furniture in: every prop
is drawn inside an existing `_draw()`, so depth ordering, hit testing and the
camera are the code they always were.

### Asset credits

The 3D models are **KayKit** packs by [Kay
Lousberg](https://www.kaylousberg.com) — *Furniture Bits*, *Restaurant Bits*
and *Prototype Bits*, all **CC0**. Only the twenty models the workshop
actually uses are vendored, unmodified, under `godot/assets/kaykit/`, each pack
with its own `LICENSE.txt`.

---

## Documentation

- [`docs/architecture.md`](docs/architecture.md) — how the pieces fit together
- [`docs/levonis-integration.md`](docs/levonis-integration.md) — mounting this
  inside the Levonis platform
- [`docs/roadmap.md`](docs/roadmap.md) — what is built and what comes next
