/**
 * FARM GRID — the single source of truth for where anything stands in the
 * workshop.
 *
 * Every station, every empty slot and every floor tile derives its position
 * from this module. Nothing in the scene is ever positioned by hand or at
 * random, which is what guarantees the rows and columns line up and that the
 * farm can grow programmatically.
 *
 * Projection is a fixed 2:1 dimetric ("isometric") one. The camera never
 * rotates, so a single sprite drawn at this angle is correct for every slot.
 */

export const TILE_W = 148;
export const TILE_H = 74;

/** Height in px that one unit of "raised floor" adds. */
export const TILE_LIFT = 10;

export interface GridPoint {
  x: number;
  y: number;
}

export interface SlotDef {
  id: string;
  row: number;
  col: number;
  /** Footprint in cells. Large machines occupy 2x1 or 2x2 without breaking rows. */
  w: number;
  h: number;
}

export interface RoomDef {
  rows: number;
  cols: number;
}

/**
 * Centre of cell (row, col) in world space.
 *
 * World origin (0,0) is the centre of cell (0,0). Positive `col` runs to the
 * lower-right, positive `row` to the lower-left.
 */
export function cellToWorld(row: number, col: number): GridPoint {
  return {
    x: (col - row) * (TILE_W / 2),
    y: (col + row) * (TILE_H / 2),
  };
}

/** Centre of a slot's whole footprint, so 2x2 machines stay visually centred. */
export function slotToWorld(slot: SlotDef): GridPoint {
  const a = cellToWorld(slot.row, slot.col);
  const b = cellToWorld(slot.row + slot.h - 1, slot.col + slot.w - 1);
  return { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 };
}

/**
 * Painter's-algorithm depth key. Larger draws later (in front).
 * Using the far corner of the footprint keeps multi-cell machines from
 * punching through their neighbours.
 */
export function slotDepth(slot: SlotDef): number {
  return slot.row + slot.h - 1 + (slot.col + slot.w - 1);
}

export function cellDepth(row: number, col: number): number {
  return row + col;
}

/** Deterministic slot id. Stable across sessions — it is a save key. */
export function slotId(row: number, col: number): string {
  return `s_${row}_${col}`;
}

/** Human-facing station label: P1, P2, ... in reading order. */
export function slotLabel(slot: SlotDef, room: RoomDef): string {
  return `P${slot.row * room.cols + slot.col + 1}`;
}

/**
 * Every slot in a room, in reading order (left→right, top→bottom).
 * Slot order is also unlock order, so expansion always fills rows evenly.
 */
export function buildRoomSlots(room: RoomDef): SlotDef[] {
  const slots: SlotDef[] = [];
  for (let row = 0; row < room.rows; row++) {
    for (let col = 0; col < room.cols; col++) {
      slots.push({ id: slotId(row, col), row, col, w: 1, h: 1 });
    }
  }
  return slots;
}

export interface WorldBounds {
  minX: number;
  minY: number;
  maxX: number;
  maxY: number;
  width: number;
  height: number;
}

/** Bounding box of a room's floor, with a half-tile margin for wall trim. */
export function roomBounds(room: RoomDef, pad = TILE_W / 2): WorldBounds {
  const corners = [
    cellToWorld(0, 0),
    cellToWorld(0, room.cols - 1),
    cellToWorld(room.rows - 1, 0),
    cellToWorld(room.rows - 1, room.cols - 1),
  ];
  const xs = corners.map((c) => c.x);
  const ys = corners.map((c) => c.y);
  const minX = Math.min(...xs) - TILE_W / 2 - pad;
  const maxX = Math.max(...xs) + TILE_W / 2 + pad;
  const minY = Math.min(...ys) - TILE_H / 2 - pad;
  const maxY = Math.max(...ys) + TILE_H / 2 + pad;
  return { minX, minY, maxX, maxY, width: maxX - minX, height: maxY - minY };
}

/** Diamond outline of one floor tile, as an SVG points string. */
export function tileDiamondPoints(inset = 0): string {
  const hw = TILE_W / 2 - inset;
  const hh = TILE_H / 2 - inset * (TILE_H / TILE_W);
  return `0,${-hh} ${hw},0 0,${hh} ${-hw},0`;
}

/** Scale that fits the whole room inside a viewport, clamped to sane zoom. */
export function fitScale(
  bounds: WorldBounds,
  viewportW: number,
  viewportH: number,
  min = 0.42,
  max = 1.25,
): number {
  if (viewportW <= 0 || viewportH <= 0) return 1;
  const s = Math.min(viewportW / bounds.width, viewportH / bounds.height);
  return Math.max(min, Math.min(max, s));
}
