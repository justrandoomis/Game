extends Node2D
## THE STANDARDISED PRINTER STATION.
##
## One work table, drawn by one routine, used by every machine in the farm.
## Its dimensions, height, orientation and perspective are constants — nothing
## about a station changes because of which printer stands on it. That is what
## keeps the workshop reading as clean rows and columns however large it grows.
##
## The station is placed by the grid (see scripts/core/Iso.gd); it never
## positions itself.

## Table footprint — identical for every station in every room.
const TABLE_HW := 58.0
const TABLE_HH := 29.0
const TABLE_TOP := 8.0
const LEG_H := 34.0
## Where a printer's feet meet the table top.
const MOUNT_Y := -(LEG_H + TABLE_TOP)
## Local hit rectangle used for tapping. Constant, because every station is.
const TAP_RECT := Rect2(-72.0, -132.0, 144.0, 166.0)

@onready var printer: Node2D = $Printer
@onready var bubble: Node2D = $Bubble
@onready var label: Label = $Label

var slot_id: String = ""
var station_label: String = "P1"
var printer_id: String = ""

var _status: String = "idle"
var _health: float = 100.0


func _ready() -> void:
	printer.position = Vector2(0, MOUNT_Y)
	bubble.position = Vector2(0, MOUNT_Y - 76.0)
	_refresh_label()


func setup(next_slot_id: String, next_label: String) -> void:
	slot_id = next_slot_id
	station_label = next_label
	if is_node_ready():
		_refresh_label()


func _refresh_label() -> void:
	label.text = station_label
	label.position = Vector2(-30.0, 14.0)
	label.size = Vector2(60.0, 20.0)


## Push one printer's server state into the station. Called on every snapshot;
## everything below this line is presentation only.
func apply(printer_data: Dictionary, job: Dictionary, progress: float) -> void:
	printer_id = String(printer_data.get("id", ""))
	_status = String(printer_data.get("status", "idle"))
	_health = float(printer_data.get("health", 100.0))

	printer.configure(String(printer_data.get("modelId", "a1_mini")), printer_data.get("upgrades", []))

	var icon := "dino"
	var color := Palette.GREEN
	if not job.is_empty():
		var product := Config.product(String(job.get("productId", "")))
		icon = String(product.get("icon", "dino"))
		color = Palette.filament(String(job.get("colorId", "green")))

	if _status == "printing" and not job.is_empty():
		printer.set_print("printing", progress, icon, color)
	elif _status == "failed" and not job.is_empty():
		# A failed print leaves the ruined part on the plate until it is cleared.
		printer.set_print("failed", Val.field(job, "failedAt", 0.4), icon, color)
	else:
		printer.set_print(_status, 0.0, icon, color)

	bubble.call("show_status", _status, progress, job, _health)
	queue_redraw()


## Play the unboxing when a machine is delivered to this station.
func play_arrival() -> void:
	printer.modulate.a = 0.0
	printer.scale = Vector2(0.7, 0.7)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(printer, "modulate:a", 1.0, 0.28)
	tween.tween_property(printer, "position:y", MOUNT_Y, 0.5).from(MOUNT_Y - 60.0) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(printer, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A short nudge when the player taps the station.
func play_tap() -> void:
	var tween := create_tween()
	tween.tween_property(printer, "scale", Vector2(1.06, 0.94), 0.07)
	tween.tween_property(printer, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func contains_point(local_point: Vector2) -> bool:
	return TAP_RECT.has_point(local_point)


func _draw() -> void:
	IsoDraw.shadow(self, Vector2(0, 2.0), TABLE_HW * 0.92, 0.12)

	# Storage bins tucked under the table, as in a real print farm.
	_draw_bin(Vector2(-20.0, 7.0))
	_draw_bin(Vector2(19.0, 4.0))

	# Four legs at the corners of the table's footprint, inset so the top
	# visibly overhangs them.
	var inset := 0.84
	for corner in [
		Vector2(0, -TABLE_HH * inset), Vector2(TABLE_HW * inset, 0),
		Vector2(0, TABLE_HH * inset), Vector2(-TABLE_HW * inset, 0),
	]:
		IsoDraw.post(self, corner, 4.5, LEG_H, Palette.WOOD_DARK)

	# The table top. Every station's is the same size, height and angle.
	IsoDraw.box(
		self, Vector2(0, -LEG_H), TABLE_HW, TABLE_HH, TABLE_TOP,
		Palette.WOOD, Palette.WOOD_MID, Palette.WOOD_DARK
	)
	# A thin lighter edge so the top reads as a surface, not a flat shape.
	draw_polyline(PackedVector2Array([
		Vector2(-TABLE_HW, -LEG_H - TABLE_TOP), Vector2(0, -LEG_H - TABLE_TOP - TABLE_HH),
		Vector2(TABLE_HW, -LEG_H - TABLE_TOP),
	]), Palette.tint(Palette.WOOD, 0.28), 1.5, true)

	# Station name plate on the floor at the front edge.
	IsoDraw.chip(self, Rect2(-27.0, 13.0, 54.0, 19.0), Palette.PAPER, 8.0)
	IsoDraw.chip(self, Rect2(-27.0, 13.0, 54.0, 19.0), Color(0.14, 0.20, 0.29, 0.10), 8.0)


func _draw_bin(at: Vector2) -> void:
	IsoDraw.solid(self, at, 19.0, 9.5, 20.0, Palette.STEEL_MID)
	draw_line(at + Vector2(-9.0, -20.0), at + Vector2(9.0, -20.0), Palette.STEEL_DARK, 1.5)


## Depth ordering happens between stations, in the Stations container, never
## inside one. A station is a single composite object: the table, the machine
## standing on it and its label are drawn in tree order, so the machine is
## always in front of the table it sits on.
