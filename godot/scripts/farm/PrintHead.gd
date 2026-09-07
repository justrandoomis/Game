extends Node2D
## The printhead, sweeping along the gantry.
##
## Kept as its own node so the sweep is a transform change every frame rather
## than a redraw of the whole machine — the animation costs nothing.

const SWEEP := 15.0
const PERIOD := 2.6

var _active: bool = false
var _time: float = 0.0
var _rest_y: float = -14.0


func _ready() -> void:
	set_process(false)


## `height` is how far above the plate the head currently rides, which follows
## the layer being printed.
func set_active(active: bool, height: float) -> void:
	_rest_y = -14.0 - height
	position.y = _rest_y
	if _active == active:
		return
	_active = active
	visible = active
	set_process(active)
	if not active:
		position.x = 0.0


func _process(delta: float) -> void:
	_time += delta
	# A smooth back-and-forth pass, with a slight vertical bob for the belt.
	position.x = sin(_time * TAU / PERIOD) * SWEEP
	position.y = _rest_y + sin(_time * TAU / PERIOD) * SWEEP * 0.5


func _draw() -> void:
	IsoDraw.solid(self, Vector2.ZERO, 7.0, 3.5, 7.0, Palette.STEEL_DARK)
	# Nozzle.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2.5, 0), Vector2(2.5, 0), Vector2(0, 5.0),
	]), Palette.shade(Palette.STEEL_DARK, 0.3))
	# Hot end glow: a small warm dot, not a light.
	draw_circle(Vector2(0, 4.0), 1.6, Palette.ORANGE)
