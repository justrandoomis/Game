extends Node2D
## The front of an enclosed machine.
##
## Its own node, and a later sibling than the print, because that is the whole
## point of an enclosed printer in this game: the part has to be visible
## through the door while it rises. Drawing the chamber and its front in one
## sprite would put the glass behind the print or the print outside the
## machine.

var _glass_id: String = ""
var _scale: float = 1.0
var _tint: Color = Color.WHITE


func _ready() -> void:
	Props.prepare(self)


## Declared for the boot check — see PrinterStation.prop_ids().
## Declared on Printer.gd, which owns the whole family table.
func prop_ids() -> PackedStringArray:
	return PackedStringArray()


## An empty id means an open-frame machine, which has no front to draw.
func set_shell(glass_id: String, shell_scale: float, tint: Color) -> void:
	if _glass_id == glass_id and is_equal_approx(_scale, shell_scale) and _tint == tint:
		return
	_glass_id = glass_id
	_scale = shell_scale
	_tint = tint
	queue_redraw()


func _draw() -> void:
	if _glass_id == "":
		return
	Props.draw(self, _glass_id, Vector2.ZERO, _scale, _tint)
