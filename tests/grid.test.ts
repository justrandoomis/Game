import { describe, expect, it } from 'vitest';
import {
  TILE_W,
  TILE_H,
  buildRoomSlots,
  cellToWorld,
  fitScale,
  roomBounds,
  slotDepth,
  slotId,
  slotLabel,
  slotToWorld,
} from '../shared/grid';

describe('farm grid', () => {
  it('places every cell on the same isometric lattice', () => {
    // The defining property of the layout: one step along a column always
    // moves by exactly the same screen vector, everywhere in the room.
    const step = cellToWorld(0, 1);
    for (let row = 0; row < 4; row++) {
      for (let col = 0; col < 4; col++) {
        const here = cellToWorld(row, col);
        const next = cellToWorld(row, col + 1);
        expect(next.x - here.x).toBeCloseTo(step.x);
        expect(next.y - here.y).toBeCloseTo(step.y);
      }
    }
  });

  it('uses a 2:1 dimetric projection', () => {
    expect(TILE_W / TILE_H).toBeCloseTo(2);
    expect(cellToWorld(0, 1)).toEqual({ x: TILE_W / 2, y: TILE_H / 2 });
    expect(cellToWorld(1, 0)).toEqual({ x: -TILE_W / 2, y: TILE_H / 2 });
  });

  it('never gives two slots the same position', () => {
    const seen = new Set<string>();
    for (const slot of buildRoomSlots({ rows: 6, cols: 6 })) {
      const at = slotToWorld(slot);
      const key = `${at.x.toFixed(3)}:${at.y.toFixed(3)}`;
      expect(seen.has(key)).toBe(false);
      seen.add(key);
    }
  });

  it('centres a multi-cell machine on its whole footprint', () => {
    const wide = { id: 'x', row: 1, col: 1, w: 2, h: 1 };
    const a = cellToWorld(1, 1);
    const b = cellToWorld(1, 2);
    expect(slotToWorld(wide)).toEqual({ x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 });
  });

  it('sorts a multi-cell machine by its nearest corner', () => {
    // Depth has to come from the far corner, or a 2x2 machine punches through
    // the station in front of it.
    expect(slotDepth({ id: 'a', row: 0, col: 0, w: 2, h: 2 })).toBe(2);
    expect(slotDepth({ id: 'b', row: 1, col: 1, w: 1, h: 1 })).toBe(2);
  });

  it('numbers stations in reading order', () => {
    const room = { rows: 2, cols: 3 };
    const slots = buildRoomSlots(room);
    expect(slots.map((s) => slotLabel(s, room))).toEqual(['P1', 'P2', 'P3', 'P4', 'P5', 'P6']);
  });

  it('keeps slot ids stable, because they are save keys', () => {
    expect(slotId(0, 0)).toBe('s_0_0');
    expect(slotId(3, 2)).toBe('s_3_2');
  });

  it('grows the room bounds with the room', () => {
    const small = roomBounds({ rows: 2, cols: 2 });
    const large = roomBounds({ rows: 4, cols: 4 });
    expect(large.width).toBeGreaterThan(small.width);
    expect(large.height).toBeGreaterThan(small.height);
  });

  it('clamps the fit scale to a usable zoom range', () => {
    const bounds = roomBounds({ rows: 6, cols: 6 });
    expect(fitScale(bounds, 390, 650)).toBeGreaterThanOrEqual(0.42);
    expect(fitScale(bounds, 4000, 4000)).toBeLessThanOrEqual(1.25);
  });
});
