extends Control
class_name SpoolDisc
## A filament spool drawn face-on, wherever the UI needs to show one.
##
## The same object the workshop rack holds: the wind carries the colour and
## shows how much is left, and the reel over it carries the material — see
## scripts/core/Reel.gd, which both this and the farm draw from, so a spool in
## the inventory and the spool on the shelf are recognisably the one spool.

var color: Color = Palette.GREEN
var fill: float = 1.0
var material_id: String = "pla"


func _init(
	next_color: Color = Palette.GREEN, next_fill: float = 1.0, next_material: String = "pla"
) -> void:
	color = next_color
	fill = clampf(next_fill, 0.0, 1.0)
	material_id = next_material
	custom_minimum_size = Vector2(38, 38)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_spool(next_color: Color, next_fill: float, next_material: String = "") -> void:
	color = next_color
	fill = clampf(next_fill, 0.0, 1.0)
	if next_material != "":
		material_id = next_material
	queue_redraw()


func _draw() -> void:
	Reel.draw_face(
		self, size * 0.5, minf(size.x, size.y) * 0.46, material_id, color, fill
	)
