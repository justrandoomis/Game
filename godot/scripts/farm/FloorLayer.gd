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

const SLAB_EDGE := 8.0

## The walls are built from one KayKit wall model, tiled. It is four units
## wide and the props are baked at four units to the cell (see
## tools/prop_recipes.json), so one segment is exactly one cell edge long and
## a run of them tiles the grid without a seam or a leftover gap — the same
## guarantee the station grid gives the machines.
##
## Segments are centred on the floor's outer edge rather than set outside it,
## so that where the two runs meet they overlap by their own thickness and
## close the corner instead of leaving a notch in it.
##
## They are also drawn a whisker over size. Neighbouring segments then overlap
## by about a pixel, which hides the seam that a sprite edge lands on when a
## run is drawn at a fractional zoom.
const WALL_OVERLAP := 1.02

## Where the picture hangs: clear of the wainscot below it and of the wall's
## top edge above.
const PICTURE_Y := -57.0
const PICTURE_SCALE := 0.62


func _ready() -> void:
	Props.prepare(self)


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

	_draw_walls()


## The room's two back walls.
##
## Each wall is a run of baked wall segments, one per cell edge along the outer
## boundary of the service band. Because the segments come from the same grid
## the machines stand on, the room's shell grows with the workshop and stays
## square to it however many stations the player buys.
##
## The runs are drawn outward from the back corner, which is the far point of
## the room in this projection — so every segment is drawn over the one behind
## it and the wall reads as one continuous surface.
func _draw_walls() -> void:
	var half := Vector2(Iso.TILE_W * 0.5, Iso.TILE_H * 0.5)

	# Right-hand wall, behind the columns, running to the lower right. It
	# carries the hatch customers collect finished prints from, and one picture
	# — both on the segments nearest the corner, which are the two the camera
	# always frames whatever size the workshop is.
	for step in cols + 2:
		var col := step - 1
		var at := Iso.cell_to_world(-1, col) + Vector2(half.x * 0.5, -half.y * 0.5)
		# Segment -1 takes the picture, 0 the hatch. Wider rooms are glazed on
		# this side as well, on segments the filament rack never stands in
		# front of (it takes the last column of the back walkway).
		var glazed := col >= 1 and col <= cols - 2 and col % 3 == 1
		var piece := "wall_right"
		if col == 0:
			piece = "hatch_right"
		elif glazed:
			piece = "window_right"
		Props.draw(self, piece, at, WALL_OVERLAP)
		if col == -1:
			Props.draw(self, "picture", at + Vector2(0, PICTURE_Y), PICTURE_SCALE)

	# Left-hand wall, running to the lower left. It carries the windows: this
	# is the shaded side, and the daylight coming through it is what the whole
	# palette is built around.
	for step in rows + 2:
		var row := step - 1
		var at := Iso.cell_to_world(row, -1) + Vector2(-half.x * 0.5, -half.y * 0.5)
		var glazed := row == 0 or (rows >= 3 and row == 2)
		Props.draw(self, "window_left" if glazed else "wall_left", at, WALL_OVERLAP)
