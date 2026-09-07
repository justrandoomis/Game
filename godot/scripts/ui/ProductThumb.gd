extends Control
class_name ProductThumb
## A small drawing of a printed part.
##
## Uses the same layer-stack silhouettes the build plate does, so the picture
## on an order card is literally the thing that will appear on the printer.

var icon: String = "dino"
var color: Color = Palette.GREEN


func _init(next_icon: String = "dino", next_color: Color = Palette.GREEN) -> void:
	icon = next_icon
	color = next_color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(40, 40)


func set_product(next_icon: String, next_color: Color) -> void:
	icon = next_icon
	color = next_color
	queue_redraw()


func _draw() -> void:
	var box: float = minf(size.x, size.y)
	Shapes.draw_icon(self, size * 0.5, box * 0.66, icon, color)
