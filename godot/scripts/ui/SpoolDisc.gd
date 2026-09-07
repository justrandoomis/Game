extends Control
class_name SpoolDisc
## A filament spool drawn face-on, with the wind showing how much is left.

var color: Color = Palette.GREEN
var fill: float = 1.0


func _init(next_color: Color = Palette.GREEN, next_fill: float = 1.0) -> void:
	color = next_color
	fill = clampf(next_fill, 0.0, 1.0)
	custom_minimum_size = Vector2(38, 38)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_spool(next_color: Color, next_fill: float) -> void:
	color = next_color
	fill = clampf(next_fill, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var centre := size * 0.5
	var radius: float = minf(size.x, size.y) * 0.46
	# Flange, then the filament wind shrinking toward the hub as it is used.
	draw_circle(centre, radius, Palette.SAND)
	draw_circle(centre, radius * 0.94, Palette.CREAM)
	var wind: float = lerpf(radius * 0.34, radius * 0.88, fill)
	draw_circle(centre, wind, color)
	draw_circle(centre, radius * 0.30, Palette.CREAM)
	draw_arc(centre, radius * 0.30, 0, TAU, 20, Palette.LINE, 1.5)
