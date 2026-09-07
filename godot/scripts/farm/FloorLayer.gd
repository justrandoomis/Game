extends Node2D
## The workshop floor and walls.
##
## The floor is the station grid plus a one-cell service band around it. The
## band is where the filament rack, the maintenance bench and the plants stand:
## because those positions are grid cells too, fixtures land on the same
## isometric lattice as the stations and can never drift off the floor or into
## a station's space.
##
## Redrawn only when the room changes tier.

var rows: int = 2
var cols: int = 2
var floor_style: String = "tile"

const WALL_H := 104.0
const SLAB_EDGE := 8.0


func configure(next_rows: int, next_cols: int, style: String) -> void:
	rows = maxi(1, next_rows)
	cols = maxi(1, next_cols)
	floor_style = style
	queue_redraw()


## Floor palettes per tier, so a bigger workshop is also a different space.
func _colors() -> Dictionary:
	match floor_style:
		"concrete":
			return {"a": Color("E8E5DE"), "b": Color("DEDAD2"), "band": Color("D2CEC5"), "edge": Color("BDB9B0")}
		"epoxy":
			return {"a": Color("E6EFF1"), "b": Color("DAE7EB"), "band": Color("C9DBE1"), "edge": Color("B0C6CE")}
		"industrial":
			return {"a": Color("E1E4E8"), "b": Color("D5D9DF"), "band": Color("C4CAD2"), "edge": Color("AEB5BF")}
		_:
			return {"a": Palette.FLOOR, "b": Palette.FLOOR_ALT, "band": Color("E2DDD2"), "edge": Palette.FLOOR_LINE}


## Outer corners of the whole floor, service band included.
func slab_corners() -> Dictionary:
	var half := Vector2(Iso.TILE_W * 0.5, Iso.TILE_H * 0.5)
	return {
		"n": Iso.cell_to_world(-1, -1) + Vector2(0, -half.y),
		"e": Iso.cell_to_world(-1, cols) + Vector2(half.x, 0),
		"s": Iso.cell_to_world(rows, cols) + Vector2(0, half.y),
		"w": Iso.cell_to_world(rows, -1) + Vector2(-half.x, 0),
	}


func _draw() -> void:
	var colors := _colors()
	var hw := Iso.TILE_W * 0.5
	var hh := Iso.TILE_H * 0.5
	var corners := slab_corners()

	# Slab body plus a lip on the two near edges, so the floor has thickness.
	draw_colored_polygon(PackedVector2Array([corners["n"], corners["e"], corners["s"], corners["w"]]), colors["band"])
	draw_colored_polygon(PackedVector2Array([
		corners["w"], corners["s"], corners["s"] + Vector2(0, SLAB_EDGE), corners["w"] + Vector2(0, SLAB_EDGE),
	]), colors["edge"])
	draw_colored_polygon(PackedVector2Array([
		corners["s"], corners["e"], corners["e"] + Vector2(0, SLAB_EDGE), corners["s"] + Vector2(0, SLAB_EDGE),
	]), Palette.shade(colors["edge"], 0.08))

	# Station cells, checkered so the grid reads without hard gridlines.
	for row in rows:
		for col in cols:
			var fill: Color = colors["a"] if (row + col) % 2 == 0 else colors["b"]
			IsoDraw.diamond(self, Iso.cell_to_world(row, col), hw, hh, fill)

	# A hairline along the station area's edge separates work floor from walkway.
	var grid_n := Iso.cell_to_world(0, 0) + Vector2(0, -hh)
	var grid_e := Iso.cell_to_world(0, cols - 1) + Vector2(hw, 0)
	var grid_s := Iso.cell_to_world(rows - 1, cols - 1) + Vector2(0, hh)
	var grid_w := Iso.cell_to_world(rows - 1, 0) + Vector2(-hw, 0)
	draw_polyline(PackedVector2Array([grid_n, grid_e, grid_s, grid_w, grid_n]), colors["edge"], 1.5, true)

	_draw_walls(corners)


## Two back walls, running along the outer edges of the service band.
func _draw_walls(corners: Dictionary) -> void:
	var n: Vector2 = corners["n"]
	var e: Vector2 = corners["e"]
	var w: Vector2 = corners["w"]

	# Right-hand wall (behind the columns) catches the light.
	draw_colored_polygon(PackedVector2Array([
		n, e, e + Vector2(0, -WALL_H), n + Vector2(0, -WALL_H),
	]), Color("F2F7F9"))
	# Left-hand wall sits in shade, which is what gives the room its corner.
	draw_colored_polygon(PackedVector2Array([
		w, n, n + Vector2(0, -WALL_H), w + Vector2(0, -WALL_H),
	]), Color("E2EAEF"))
	# Skirting board along both walls.
	draw_colored_polygon(PackedVector2Array([
		n, e, e + Vector2(0, -9.0), n + Vector2(0, -9.0),
	]), Color("E4EBEE"))
	draw_colored_polygon(PackedVector2Array([
		w, n, n + Vector2(0, -9.0), w + Vector2(0, -9.0),
	]), Color("D3DDE4"))

	_draw_window(w, n)
	_draw_posters(n, e)


## A window on the shaded wall — the daylight the whole palette is built around.
func _draw_window(from: Vector2, to: Vector2) -> void:
	var a := from.lerp(to, 0.30)
	var b := from.lerp(to, 0.62)
	var top := -WALL_H + 22.0
	var bottom := -40.0
	draw_colored_polygon(PackedVector2Array([
		a + Vector2(0, bottom), b + Vector2(0, bottom), b + Vector2(0, top), a + Vector2(0, top),
	]), Color("A9CFE0"))
	draw_colored_polygon(PackedVector2Array([
		a + Vector2(0, bottom - 4.0), b + Vector2(0, bottom - 4.0),
		b + Vector2(0, top + 4.0), a + Vector2(0, top + 4.0),
	]), Color("CFE9F5"))
	# Glazing bar.
	var mid_a := a.lerp(b, 0.5)
	draw_line(mid_a + Vector2(0, bottom - 4.0), mid_a + Vector2(0, top + 4.0), Color("EAF4F9"), 3.0)


## Two workshop posters. Set dressing that never reaches the station grid.
func _draw_posters(from: Vector2, to: Vector2) -> void:
	var a := from.lerp(to, 0.18)
	var b := from.lerp(to, 0.36)
	draw_colored_polygon(PackedVector2Array([
		a + Vector2(0, -34.0), b + Vector2(0, -34.0), b + Vector2(0, -84.0), a + Vector2(0, -84.0),
	]), Palette.CREAM)
	draw_colored_polygon(PackedVector2Array([
		a + Vector2(0, -50.0), b + Vector2(0, -50.0), b + Vector2(0, -60.0), a + Vector2(0, -60.0),
	]), Palette.TEAL)
	draw_colored_polygon(PackedVector2Array([
		a + Vector2(0, -64.0), b.lerp(a, 0.35) + Vector2(0, -64.0),
		b.lerp(a, 0.35) + Vector2(0, -70.0), a + Vector2(0, -70.0),
	]), Palette.INK_FAINT)

	var c := from.lerp(to, 0.52)
	var d := from.lerp(to, 0.68)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -38.0), d + Vector2(0, -38.0), d + Vector2(0, -82.0), c + Vector2(0, -82.0),
	]), Palette.CREAM)
	draw_circle(c.lerp(d, 0.5) + Vector2(0, -62.0), 9.0, Palette.YELLOW)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -44.0), d + Vector2(0, -44.0), d + Vector2(0, -48.0), c + Vector2(0, -48.0),
	]), Palette.ORANGE)
