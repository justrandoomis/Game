extends Node2D
## The part on the build plate, revealed layer by layer.
##
## Redraws only when a new layer lands, which for a real print is once every
## few seconds — not every frame.

var icon: String = "dino"
var color: Color = Palette.GREEN
var progress: float = 0.0


func set_model(next_icon: String, next_color: Color, next_progress: float) -> void:
	icon = next_icon
	color = next_color
	progress = clampf(next_progress, 0.0, 1.0)
	visible = progress > 0.0
	queue_redraw()


func clear_model() -> void:
	progress = 0.0
	visible = false
	queue_redraw()


func _draw() -> void:
	if progress <= 0.0:
		return
	Shapes.draw_model(self, Vector2.ZERO, 18.0, icon, color, progress, 3.4)
