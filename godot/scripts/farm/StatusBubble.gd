extends Node2D
## The speech-bubble status tag above a station.
##
## Deliberately small and only as loud as it needs to be: a running printer
## shows a progress bar, a machine that wants something says what, and a
## failure gets the one alert in the scene that moves. Health only appears once
## it matters, so the farm never looks like a wall of gauges.
##
## An idle machine shrinks to a dot. Idle is the commonest state a farm is in —
## a workshop of twelve stations was a wall of tags reading "Idle", each one
## nearly as wide as the tile it stood on and covering the machine behind it.
## The dot still says the station is ready, in the same colour, and the machine
## under it is visible, which is the thing the player actually came to look at.

const WIDTH := 96.0
const WIDTH_QUIET := 30.0
const HEIGHT := 30.0
const HEIGHT_QUIET := 22.0
const BAR_H := 5.0

var _status: String = "idle"
var _progress: float = 0.0
var _health: float = 100.0
var _remaining_text: String = ""
var _alert: bool = false
var _time: float = 0.0
## Resting height above the station, set by the station that owns this bubble
## so a failure alert returns to the same place the bubble started. Without it
## an alerting bubble drops onto the machine it is meant to be pointing at.
var _base: float = -62.0

@onready var text_label: Label = $Text


func _ready() -> void:
	z_index = 400
	z_as_relative = false
	set_process(false)
	_layout_label()


## Whether this bubble is down to a dot: idle, and nothing else to say. A
## machine that is idle but due a service still wants a word — being quiet
## about it is how a farm ends up full of worn machines.
func _quiet() -> bool:
	return _status == "idle" and not _needs_service()


func _needs_service() -> bool:
	var thresholds := Config.health_thresholds() if Config.is_loaded else {"service": 70}
	return _health <= float(thresholds.get("service", 70))


func _layout_label() -> void:
	text_label.position = Vector2(-WIDTH * 0.5 + 24.0, -HEIGHT + 5.0)
	text_label.size = Vector2(WIDTH - 32.0, HEIGHT - 10.0)


func show_status(status: String, progress: float, job: Dictionary, health: float) -> void:
	_status = status
	_progress = clampf(progress, 0.0, 1.0)
	_health = health
	_remaining_text = ""

	if status == "printing" and not job.is_empty():
		var started := Val.field_int(job, "startedAt", 0)
		var duration := int(job.get("durationMs", 0))
		if started > 0 and duration > 0:
			_remaining_text = ServerClock.format_duration(ServerClock.remaining(started + duration))

	if is_node_ready():
		text_label.text = status_text()
		text_label.visible = not _quiet()
		text_label.position.y = (-HEIGHT + 1.0) if status == "printing" else (-HEIGHT + 5.0)

	var next_alert := status == "failed"
	if next_alert != _alert:
		_alert = next_alert
		set_process(_alert)
		if not _alert:
			position.y = _base_y()
	queue_redraw()


## Called by the station once, with the height its machine reaches.
func set_base(y: float) -> void:
	_base = y
	position.y = y


func _base_y() -> float:
	return _base


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y() + sin(_time * 3.0) * 3.0


func _draw() -> void:
	var accent := Palette.status(_status)
	var wide := not _quiet()
	var w := WIDTH if wide else WIDTH_QUIET
	var h := HEIGHT if wide else HEIGHT_QUIET
	var rect := Rect2(-w * 0.5, -h, w, h)
	var radius := 11.0 if wide else h * 0.5

	# Bubble body with a soft drop shadow and a tail pointing at the machine.
	IsoDraw.chip(self, Rect2(rect.position + Vector2(0, 2), rect.size), Color(0.14, 0.20, 0.29, 0.13), radius)
	IsoDraw.chip(self, rect, Palette.PAPER, radius)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -1), Vector2(6, -1), Vector2(0, 7),
	]), Palette.PAPER)

	# Status dot. It is the whole bubble when the machine is only idle, so it
	# sits in the middle then and beside the text otherwise.
	var dot := Vector2(-w * 0.5 + 15.0, -h * 0.5) if wide else Vector2(0, -h * 0.5)
	draw_circle(dot, 6.0, accent)
	if _status == "printing":
		draw_circle(dot, 2.6, Palette.PAPER)
	elif _status == "failed":
		# A small exclamation, drawn rather than typeset so it never reflows.
		draw_rect(Rect2(dot.x - 1.0, dot.y - 4.0, 2.0, 5.0), Palette.PAPER)
		draw_rect(Rect2(dot.x - 1.0, dot.y + 2.0, 2.0, 2.0), Palette.PAPER)

	if _status == "printing":
		# Percentage and countdown sit above the bar, drawn by the Label child.
		var bar := Rect2(-WIDTH * 0.5 + 26.0, -HEIGHT * 0.5 + 1.0, 58.0, BAR_H)
		IsoDraw.chip(self, bar, Palette.SAND, BAR_H * 0.5)
		if _progress > 0.01:
			IsoDraw.chip(
				self, Rect2(bar.position, Vector2(maxf(BAR_H, bar.size.x * _progress), bar.size.y)),
				accent, BAR_H * 0.5
			)

	# Health pip, and only once the machine actually wants attention. A bubble
	# showing one is never the quiet kind, so there is room for it.
	if _needs_service() and _status != "failed":
		var warning := 40.0
		if Config.is_loaded:
			warning = float(Config.health_thresholds().get("warning", 40))
		var pip := Palette.ORANGE if _health > warning else Palette.CORAL
		draw_circle(Vector2(w * 0.5 - 10.0, -h + 9.0), 4.0, pip)


## The text the bubble shows. Rendered by a Label child so it localises, shapes
## Arabic correctly and picks up the theme font rather than being drawn by hand.
func status_text() -> String:
	if _status == "printing":
		return _remaining_text if _remaining_text != "" else I18n.t("printing")
	return I18n.t(_status)


## While printing, the bubble shows the countdown above the progress bar.
func countdown_text() -> String:
	return _remaining_text
