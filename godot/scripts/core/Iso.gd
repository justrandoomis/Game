extends Node
## FARM GRID + ISOMETRIC PROJECTION.
##
## The single source of truth for where anything stands in the workshop.
## Every station, empty slot and floor tile derives its position from here —
## nothing in the farm is ever placed by hand or at random, which is what
## guarantees the rows and columns line up and that the farm can grow
## programmatically.
##
## Mirrors shared/grid.ts on the server so client and server agree on layout.
## Projection is a fixed 2:1 dimetric one; the camera never rotates, so a
## single drawing routine is correct for every slot in the room.

const TILE_W: float = 148.0
const TILE_H: float = 74.0

## Centre of cell (row, col) in world space. Origin is the centre of cell (0,0);
## +col runs to the lower-right, +row to the lower-left.
func cell_to_world(row: int, col: int) -> Vector2:
	return Vector2((col - row) * (TILE_W * 0.5), (col + row) * (TILE_H * 0.5))


## Centre of a footprint, so a 2x2 machine sits centred on the cells it covers.
func slot_to_world(row: int, col: int, w: int = 1, h: int = 1) -> Vector2:
	var a := cell_to_world(row, col)
	var b := cell_to_world(row + h - 1, col + w - 1)
	return (a + b) * 0.5


## Painter's-algorithm depth. Larger draws in front. Using the far corner of a
## footprint stops multi-cell machines punching through their neighbours.
func slot_depth(row: int, col: int, w: int = 1, h: int = 1) -> int:
	return (row + h - 1) + (col + w - 1)


## Deterministic slot id. Must match the server's `s_<row>_<col>` save key.
func slot_id(row: int, col: int) -> String:
	return "s_%d_%d" % [row, col]


## Parse a slot id back to its cell. Returns Vector2i(-1, -1) if malformed.
func parse_slot(id: String) -> Vector2i:
	var parts := id.split("_")
	if parts.size() != 3 or parts[0] != "s":
		return Vector2i(-1, -1)
	return Vector2i(int(parts[1]), int(parts[2]))


## Station label in reading order: P1, P2, P3...
func slot_label(row: int, col: int, cols: int) -> String:
	return "P%d" % (row * cols + col + 1)


## Every slot in a room, in reading order. Slot order is also unlock order, so
## the workshop always fills its rows evenly.
func room_slots(rows: int, cols: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for row in rows:
		for col in cols:
			out.append(Vector2i(row, col))
	return out


## Bounding box of a room's floor, with a margin for wall trim.
func room_bounds(rows: int, cols: int, pad: float = TILE_W * 0.5) -> Rect2:
	var corners := [
		cell_to_world(0, 0),
		cell_to_world(0, cols - 1),
		cell_to_world(rows - 1, 0),
		cell_to_world(rows - 1, cols - 1),
	]
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for c in corners:
		min_x = minf(min_x, c.x)
		max_x = maxf(max_x, c.x)
		min_y = minf(min_y, c.y)
		max_y = maxf(max_y, c.y)
	min_x -= TILE_W * 0.5 + pad
	max_x += TILE_W * 0.5 + pad
	min_y -= TILE_H * 0.5 + pad
	max_y += TILE_H * 0.5 + pad
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)


## Diamond outline of one floor tile, centred on the origin.
func tile_diamond(hw: float = TILE_W * 0.5, hh: float = TILE_H * 0.5) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)
	])


## Which cell a world point falls in — used to turn a tap into a slot.
func world_to_cell(world: Vector2) -> Vector2i:
	var fx := world.x / (TILE_W * 0.5)
	var fy := world.y / (TILE_H * 0.5)
	return Vector2i(int(round((fy - fx) * 0.5)), int(round((fy + fx) * 0.5)))
