extends Node2D
## The filament rack on the workshop wall.
##
## Filament does not only exist in a menu: what the player owns is what stands
## on this rack. Spools fill the shelves as stock grows, so buying filament is
## visible in the room.

const SHELVES := 3
const PER_SHELF := 5
const SHELF_W := 118.0
const SHELF_GAP := 27.0
const TAP_RECT := Rect2(-72.0, -116.0, 144.0, 140.0)

var _spools: Array = []


## `spools` is the raw server list; only colour and material are used here.
func set_spools(spools: Array) -> void:
	_spools = spools
	queue_redraw()


func contains_point(local_point: Vector2) -> bool:
	return TAP_RECT.has_point(local_point)


func _draw() -> void:
	IsoDraw.shadow(self, Vector2(0, 2.0), 62.0, 0.10)

	# Uprights and shelves. One frame, drawn once, whatever is stored on it.
	IsoDraw.post(self, Vector2(-SHELF_W * 0.5, 6.0), 4.0, 100.0, Palette.STEEL_DARK)
	IsoDraw.post(self, Vector2(SHELF_W * 0.5, -6.0), 4.0, 100.0, Palette.STEEL_DARK)

	for shelf in SHELVES:
		var y := -18.0 - float(shelf) * SHELF_GAP
		draw_colored_polygon(PackedVector2Array([
			Vector2(-SHELF_W * 0.5, y + 6.0), Vector2(SHELF_W * 0.5, y - 6.0),
			Vector2(SHELF_W * 0.5, y - 10.0), Vector2(-SHELF_W * 0.5, y + 2.0),
		]), Palette.STEEL_MID)

	# Spools, filled bottom shelf first so the rack visibly grows with stock.
	var index := 0
	for spool in _spools:
		if index >= SHELVES * PER_SHELF:
			break
		var shelf := index / PER_SHELF
		var column := index % PER_SHELF
		var t := (float(column) + 0.5) / float(PER_SHELF)
		var x := lerpf(-SHELF_W * 0.5 + 10.0, SHELF_W * 0.5 - 10.0, t)
		var y := -18.0 - float(shelf) * SHELF_GAP + lerpf(4.0, -8.0, t) - 10.0
		var color := Palette.filament(String(spool.get("colorId", "white")))
		var remaining := clampf(float(spool.get("grams", 0.0)) / maxf(1.0, float(spool.get("capacity", 1000.0))), 0.05, 1.0)
		IsoDraw.spool(self, Vector2(x, y), 6.0 + 3.0 * remaining, color)
		index += 1

	# Cardboard boxes on the floor beside the rack — stock that has not been
	# unpacked yet. Purely set dressing, and never in the way of the grid.
	IsoDraw.solid(self, Vector2(-52.0, 22.0), 17.0, 8.5, 18.0, Color("D9B487"))
	IsoDraw.solid(self, Vector2(-30.0, 30.0), 14.0, 7.0, 14.0, Color("CFA97A"))
