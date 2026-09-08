extends Node2D
## The maintenance bench.
##
## Where servicing happens. Giving repairs a physical place in the room means
## maintenance is something the player goes and does, rather than a number in
## a menu.
##
## The cabinet is a baked model; the pegboard, the tools and the machine on the
## bench are still drawn, because they are what changes when a printer is being
## worked on.

const CABINET := "bench_cabinet"
## Shadows are drawn a little inside the footprint, so the object overhangs its
## own shadow rather than sitting on a hard outline of itself.
const SHADOW_INSET := 0.9
## Where the stool stands, relative to the bench.
##
## It has to stay on the bench's own cell AND clear of the station on the cell
## to the lower right: that station's table is 130 px wide on a 148 px cell, so
## it reaches 9 px back over the boundary. Anything further right than that is
## buried by it — which is what the stool's old offset was, invisibly, until a
## workshop grew big enough for that slot to be bought.
const STOOL_AT := Vector2(-30.0, 16.0)
## Covers the cabinet, the stool beside it and the tool board above it.
const TAP_RECT := Rect2(-70.0, -96.0, 140.0, 132.0)

var _busy: bool = false


## Declared for the boot check — see PrinterStation.prop_ids().
func prop_ids() -> PackedStringArray:
	return PackedStringArray([CABINET, "stool", "books"])


func _ready() -> void:
	Props.prepare(self)


func set_busy(busy: bool) -> void:
	if _busy == busy:
		return
	_busy = busy
	queue_redraw()


func contains_point(local_point: Vector2) -> bool:
	return TAP_RECT.has_point(local_point)


func _draw() -> void:
	# The cabinet is twice as wide as it is deep, so its shadow is a
	# parallelogram taken from the model's own ground axes. A square diamond
	# here leaves a wedge of shadow lying on bare floor in front of it.
	IsoDraw.footprint(
		self, Vector2(0, 2.0),
		Props.along(CABINET, "x") * SHADOW_INSET, Props.along(CABINET, "z") * SHADOW_INSET,
		0.11
	)

	# Pegboard of tools on the wall the bench backs onto. Drawn first so the
	# cabinet stands in front of it.
	_draw_pegboard()

	Props.draw(self, CABINET, Vector2.ZERO)

	# A stool pulled up to the bench, and the bench top itself.
	Props.draw(self, "stool", STOOL_AT, 0.8)
	_draw_worktop()


## A tool board on the wall behind the bench.
##
## The bench stands on the left-hand walkway, so the wall behind it is half a
## tile up and to the left, and it runs along the row axis. Both come from the
## tile, so the board lies flat on that wall the same way the wall itself lies
## on the grid — it cannot end up at a slightly different angle.
const ON_WALL := Vector2(-Iso.TILE_W * 0.25, -Iso.TILE_H * 0.25)
const ALONG_WALL := Vector2(-Iso.TILE_W * 0.5, Iso.TILE_H * 0.5)
const BOARD_SPAN := 0.52
const BOARD_BOTTOM := 26.0
const BOARD_HEIGHT := 36.0


func _draw_pegboard() -> void:
	var reach: Vector2 = ALONG_WALL * BOARD_SPAN * 0.5
	var bottom := ON_WALL + Vector2(0, -BOARD_BOTTOM)
	var rise := Vector2(0, -BOARD_HEIGHT)
	var near := bottom - reach
	var far := bottom + reach
	var board := Palette.tint(Palette.PROP_WOOD, 0.34)
	draw_colored_polygon(PackedVector2Array([near, far, far + rise, near + rise]), board)
	draw_polyline(PackedVector2Array([
		near, far, far + rise, near + rise, near,
	]), Palette.PROP_WOOD_DARK, 1.5, true)

	# Tools hanging in a row, following the wall's slope.
	var tools := [Palette.CORAL, Palette.TEAL, Palette.YELLOW, Palette.ORANGE, Palette.SKY_DEEP]
	for i in tools.size():
		var t := (float(i) + 0.5) / float(tools.size())
		var hook := near.lerp(far, t) + Vector2(0, -BOARD_HEIGHT + 8.0)
		draw_line(hook, hook + Vector2(0, 11.0), Palette.STEEL_DARK, 2.0)
		draw_circle(hook + Vector2(0, 13.0), 3.2, tools[i])


## What is on the bench: a parts bin, a nozzle tray, and — while a machine is
## being serviced — the machine itself.
func _draw_worktop() -> void:
	var top := -Props.top(CABINET)
	IsoDraw.solid(self, Vector2(-20.0, top + 4.0), 11.0, 5.5, 8.0, Palette.STEEL)
	Props.draw(self, "books", Vector2(14.0, top + 9.0), 0.55)
	if _busy:
		IsoDraw.solid(self, Vector2(-2.0, top + 2.0), 18.0, 9.0, 15.0, Palette.ORANGE)
		draw_circle(Vector2(-2.0, top - 15.0), 3.4, Palette.YELLOW)
