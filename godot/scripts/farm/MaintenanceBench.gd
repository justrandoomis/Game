extends Node2D
## The maintenance bench.
##
## Where servicing happens. Giving repairs a physical place in the room means
## maintenance is something the player goes and does, rather than a number in
## a menu.

const TAP_RECT := Rect2(-66.0, -78.0, 132.0, 108.0)

var _busy: bool = false


func set_busy(busy: bool) -> void:
	if _busy == busy:
		return
	_busy = busy
	queue_redraw()


func contains_point(local_point: Vector2) -> bool:
	return TAP_RECT.has_point(local_point)


func _draw() -> void:
	IsoDraw.shadow(self, Vector2(0, 2.0), 54.0, 0.11)

	# Bench: the same table language as a printer station, in steel.
	for corner in [Vector2(0, -20.0), Vector2(44.0, 0), Vector2(0, 20.0), Vector2(-44.0, 0)]:
		IsoDraw.post(self, corner, 3.5, 26.0, Palette.STEEL_DARK)
	IsoDraw.box(
		self, Vector2(0, -26.0), 50.0, 25.0, 6.0,
		Palette.tint(Palette.SKY_DEEP, 0.42), Palette.SKY_DEEP, Palette.shade(Palette.SKY_DEEP, 0.22)
	)

	# Pegboard of tools on the wall behind it.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-44.0, -34.0), Vector2(30.0, -71.0), Vector2(30.0, -108.0), Vector2(-44.0, -71.0),
	]), Palette.SAND)
	var tools := [Palette.CORAL, Palette.TEAL, Palette.YELLOW, Palette.ORANGE, Palette.SKY_DEEP]
	for i in tools.size():
		var t := (float(i) + 0.5) / float(tools.size())
		var base := Vector2(-44.0, -46.0).lerp(Vector2(26.0, -81.0), t)
		draw_line(base, base + Vector2(0, 13.0), Palette.STEEL_DARK, 2.0)
		draw_circle(base + Vector2(0, 15.0), 3.4, tools[i])

	# Parts bin and a spare nozzle tray on the bench top.
	IsoDraw.solid(self, Vector2(-16.0, -30.0), 12.0, 6.0, 8.0, Palette.STEEL)
	IsoDraw.solid(self, Vector2(14.0, -26.0), 10.0, 5.0, 5.0, Palette.CREAM)

	if _busy:
		# A machine is on the bench right now.
		IsoDraw.solid(self, Vector2(0, -34.0), 20.0, 10.0, 16.0, Palette.ORANGE)
		draw_circle(Vector2(0, -56.0), 3.4, Palette.YELLOW)
