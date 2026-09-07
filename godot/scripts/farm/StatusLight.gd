extends Node2D
## The little status lamp on the machine.
##
## The cheapest way to read a whole farm at a glance: one dot per station,
## colour-coded, pulsing only while something is actually happening.

var _color: Color = Palette.STATUS["idle"]
var _pulse: bool = false
var _time: float = 0.0


func _ready() -> void:
	set_process(false)


func set_status(status: String) -> void:
	_color = Palette.status(status)
	var next_pulse := status == "printing" or status == "failed"
	if next_pulse != _pulse:
		_pulse = next_pulse
		set_process(_pulse)
		if not _pulse:
			modulate.a = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_time * 3.4))


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.2, Color(_color.r, _color.g, _color.b, 0.28))
	draw_circle(Vector2.ZERO, 2.4, _color)
