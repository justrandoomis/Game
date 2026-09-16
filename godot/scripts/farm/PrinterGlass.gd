extends Node2D
## The front of an enclosed machine.
##
## Its own node, and a later sibling than the print, because that is the whole
## point of an enclosed printer in this game: the part has to be visible
## through the door while it rises. Drawing the chamber and its front in one
## sprite would put the glass behind the print or the print outside the
## machine.

const GLASS := "printer_glass"

var _shown: bool = false
var _tint: Color = Color.WHITE


func _ready() -> void:
	Props.prepare(self)


## Declared for the boot check — see PrinterStation.prop_ids().
func prop_ids() -> PackedStringArray:
	return PackedStringArray([GLASS])


func set_enclosed(enclosed: bool, tint: Color) -> void:
	if _shown == enclosed and _tint == tint:
		return
	_shown = enclosed
	_tint = tint
	queue_redraw()


func _draw() -> void:
	if not _shown:
		return
	Props.draw(self, GLASS, Vector2.ZERO, 1.0, _tint)
