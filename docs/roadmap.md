# What is built, and what comes next

The brief asks for a beautiful vertical slice first, with the architecture in
place for the rest. That is what this is.

## Built and playable

**The farm**
- Fixed 2:1 isometric workshop on a strict grid; camera pans and pinch-zooms,
  never rotates
- One standardised `PrinterStation.tscn` used by every machine
- Empty bays drawn into the floor, with the next buyable one highlighted and
  the rest quietly locked
- Filament rack that fills as stock grows; maintenance bench; grid-aligned decor
- Workshop furniture — tables, walls, shelving, crates, plants — modelled
  rather than drawn: KayKit low-poly models baked offline into sprites in the
  game's own projection (`godot/tools/BakeProps.gd`), so nothing 3D ships
- Printing animation: sweeping printhead, part appearing layer by layer, status
  light, live countdown bubble
- Workshop expands to a physically bigger room, five tiers

**The loop**
- Customer orders → accept / reject → assign one or several printers → filament
  reserved → print → deliver → coins, XP and reputation
- Multi-printer splits weighted by machine speed, with a preview of the split,
  the filament needed and the ETA before committing
- Failures with real causes, a visible alert on the machine, and a blocked queue
  until cleared
- Maintenance actions, spare parts, machine health
- Store production and passive sales with drifting demand
- Buy filament, buy printers, unlock stations, expand the workshop, install
  upgrades
- Offline progression with a "while you were away" report

**Around it**
- Top HUD, five-tab bottom navigation with safe-area handling, bottom sheets
- Orders / Shop / Inventory / Upgrades screens, all gated by level
- Coin bursts, level-up banner, toasts, tutorial hints
- English, Arabic and Kurdish with proper RTL for UI only
- Sound cues with a mute setting
- Server-authoritative everything, with an audit trail and rate limiting
- 51 tests over the grid, the simulation and the server

## Implemented but not yet surfaced

These exist in config and in the engines, gated behind levels that the vertical
slice does not reach:

- Employees — `Worker.tscn` walks its routes; spawns once the system unlocks
- Electricity — per-machine draw is in the printer catalog
- Customer tiers above Merchant — in config, unlocked by reputation
- Levonis Points conversion — endpoint and caps built, off by default

## Next

**Phase 6 — management depth**
- Queue reordering by drag
- Employee automation: operators starting the next job, technicians servicing
- Electricity capacity as an expansion requirement
- Corporate and industrial contracts
- Random events (power cut, filament shortage, viral product)

**Phase 7 — meta**
- Leaderboards UI (the API is already there)
- Achievements and daily/weekly challenges
- Ticket-gated special contracts
- Business loans and Recovery Mode
- Prestige

**Engineering**
- Move off the 4.8 dev snapshot to 4.8-stable when it lands
- More baked props as the room grows: the recipe file takes a new model and a
  scale, and `--selftest` fails if one is catalogued without a sprite
- An admin UI for `pf_config`, rather than editing the row directly
- Push the Web export through the platform's CI
- Extend the CI smoke test (`--selftest`) into a scripted play-through
