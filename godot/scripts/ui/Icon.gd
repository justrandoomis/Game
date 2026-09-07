extends Control
class_name Icon
## Procedurally drawn icons.
##
## The game ships no icon atlas: every glyph is a handful of polygons drawn at
## whatever size it is asked for. That keeps the download small, keeps icons
## crisp at any density, and lets them recolour with the palette for free.

@export var name_id: String = "coin":
	set(value):
		name_id = value
		queue_redraw()

@export var color: Color = Palette.INK:
	set(value):
		color = value
		queue_redraw()


func _init(icon_name: String = "coin", icon_color: Color = Palette.INK, box: float = 20.0) -> void:
	name_id = icon_name
	color = icon_color
	custom_minimum_size = Vector2(box, box)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	# Draw at the size the caller asked for, centred in whatever rect the
	# layout gave us — an icon told to fill a button should not grow to fill it.
	var requested: float = maxf(custom_minimum_size.x, 1.0)
	var s: float = minf(minf(size.x, size.y), requested)
	var c := size * 0.5
	match name_id:
		"coin": _coin(c, s)
		"star": _star(c, s)
		"bolt": _bolt(c, s)
		"home": _home(c, s)
		"clipboard": _clipboard(c, s)
		"store": _store(c, s)
		"box": _box(c, s)
		"arrow_up": _arrow_up(c, s)
		"spool": _spool(c, s)
		"printer": _printer(c, s)
		"wrench": _wrench(c, s)
		"clock": _clock(c, s)
		"gear": _gear(c, s)
		"check": _check(c, s)
		"close": _close(c, s)
		"plus": _plus(c, s)
		"chevron": _chevron(c, s)
		"alert": _alert(c, s)
		_: _coin(c, s)


func _coin(c: Vector2, s: float) -> void:
	draw_circle(c, s * 0.42, color)
	draw_circle(c, s * 0.32, Palette.tint(color, 0.42))
	draw_rect(Rect2(c.x - s * 0.05, c.y - s * 0.18, s * 0.10, s * 0.36), color)


func _star(c: Vector2, s: float) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI * 0.5 + float(i) * PI / 5.0
		var radius: float = s * (0.46 if i % 2 == 0 else 0.20)
		points.append(c + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)


func _bolt(c: Vector2, s: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(s * 0.06, -s * 0.46), c + Vector2(-s * 0.26, s * 0.06),
		c + Vector2(-s * 0.02, s * 0.06), c + Vector2(-s * 0.08, s * 0.46),
		c + Vector2(s * 0.26, -s * 0.06), c + Vector2(s * 0.02, -s * 0.06),
	]), color)


func _home(c: Vector2, s: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -s * 0.44), c + Vector2(s * 0.46, -s * 0.02),
		c + Vector2(-s * 0.46, -s * 0.02),
	]), color)
	draw_rect(Rect2(c.x - s * 0.30, c.y - s * 0.06, s * 0.60, s * 0.44), color)


func _clipboard(c: Vector2, s: float) -> void:
	draw_rect(Rect2(c.x - s * 0.32, c.y - s * 0.38, s * 0.64, s * 0.78), color)
	draw_rect(Rect2(c.x - s * 0.16, c.y - s * 0.46, s * 0.32, s * 0.16), Palette.tint(color, 0.5))
	for i in 3:
		draw_rect(Rect2(c.x - s * 0.20, c.y - s * 0.14 + float(i) * s * 0.18, s * 0.40, s * 0.07),
			Palette.tint(color, 0.55))


func _store(c: Vector2, s: float) -> void:
	draw_rect(Rect2(c.x - s * 0.40, c.y - s * 0.10, s * 0.80, s * 0.50), color)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.46, -s * 0.10), c + Vector2(-s * 0.34, -s * 0.42),
		c + Vector2(s * 0.34, -s * 0.42), c + Vector2(s * 0.46, -s * 0.10),
	]), Palette.tint(color, 0.35))
	draw_rect(Rect2(c.x - s * 0.12, c.y + s * 0.10, s * 0.24, s * 0.30), Palette.tint(color, 0.6))


func _box(c: Vector2, s: float) -> void:
	IsoDraw.box(self, c + Vector2(0, s * 0.22), s * 0.40, s * 0.20, s * 0.40,
		Palette.tint(color, 0.30), color, Palette.shade(color, 0.22))


func _arrow_up(c: Vector2, s: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -s * 0.44), c + Vector2(s * 0.40, s * 0.02), c + Vector2(-s * 0.40, s * 0.02),
	]), color)
	draw_rect(Rect2(c.x - s * 0.15, c.y, s * 0.30, s * 0.42), color)


func _spool(c: Vector2, s: float) -> void:
	draw_circle(c, s * 0.44, Palette.shade(color, 0.2))
	draw_circle(c, s * 0.36, color)
	draw_circle(c, s * 0.14, Palette.CREAM)


func _printer(c: Vector2, s: float) -> void:
	draw_rect(Rect2(c.x - s * 0.40, c.y - s * 0.08, s * 0.80, s * 0.44), color)
	draw_rect(Rect2(c.x - s * 0.26, c.y - s * 0.44, s * 0.52, s * 0.30), Palette.tint(color, 0.35))
	draw_rect(Rect2(c.x - s * 0.18, c.y + s * 0.04, s * 0.36, s * 0.14), Palette.tint(color, 0.6))


func _wrench(c: Vector2, s: float) -> void:
	draw_line(c + Vector2(-s * 0.28, s * 0.30), c + Vector2(s * 0.20, -s * 0.18), color, s * 0.14)
	draw_circle(c + Vector2(s * 0.24, -s * 0.24), s * 0.17, color)
	draw_circle(c + Vector2(s * 0.30, -s * 0.30), s * 0.09, Palette.PAPER)


func _clock(c: Vector2, s: float) -> void:
	draw_arc(c, s * 0.40, 0, TAU, 24, color, s * 0.10)
	draw_line(c, c + Vector2(0, -s * 0.24), color, s * 0.09)
	draw_line(c, c + Vector2(s * 0.20, 0), color, s * 0.09)


func _gear(c: Vector2, s: float) -> void:
	for i in 8:
		var angle := float(i) * TAU / 8.0
		draw_line(c + Vector2(cos(angle), sin(angle)) * s * 0.24,
			c + Vector2(cos(angle), sin(angle)) * s * 0.44, color, s * 0.14)
	draw_circle(c, s * 0.28, color)
	draw_circle(c, s * 0.12, Palette.PAPER)


func _check(c: Vector2, s: float) -> void:
	draw_polyline(PackedVector2Array([
		c + Vector2(-s * 0.30, 0), c + Vector2(-s * 0.08, s * 0.22), c + Vector2(s * 0.32, -s * 0.26),
	]), color, s * 0.14, true)


func _close(c: Vector2, s: float) -> void:
	draw_line(c + Vector2(-s * 0.26, -s * 0.26), c + Vector2(s * 0.26, s * 0.26), color, s * 0.13)
	draw_line(c + Vector2(s * 0.26, -s * 0.26), c + Vector2(-s * 0.26, s * 0.26), color, s * 0.13)


func _plus(c: Vector2, s: float) -> void:
	draw_rect(Rect2(c.x - s * 0.30, c.y - s * 0.08, s * 0.60, s * 0.16), color)
	draw_rect(Rect2(c.x - s * 0.08, c.y - s * 0.30, s * 0.16, s * 0.60), color)


func _chevron(c: Vector2, s: float) -> void:
	draw_polyline(PackedVector2Array([
		c + Vector2(-s * 0.14, -s * 0.26), c + Vector2(s * 0.16, 0), c + Vector2(-s * 0.14, s * 0.26),
	]), color, s * 0.13, true)


func _alert(c: Vector2, s: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -s * 0.42), c + Vector2(s * 0.44, s * 0.34), c + Vector2(-s * 0.44, s * 0.34),
	]), color)
	draw_rect(Rect2(c.x - s * 0.05, c.y - s * 0.16, s * 0.10, s * 0.24), Palette.PAPER)
	draw_rect(Rect2(c.x - s * 0.05, c.y + s * 0.14, s * 0.10, s * 0.10), Palette.PAPER)
