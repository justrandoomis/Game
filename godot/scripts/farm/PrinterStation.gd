extends Node2D
## THE STANDARDISED PRINTER STATION.
##
## One work table — the same baked model, at the same scale, under every
## machine in the farm. Its size, height, orientation and perspective are
## therefore identical everywhere, and the height a printer mounts at is
## measured off the table model rather than typed in. That is what keeps the
## workshop reading as clean rows and columns however large it grows.
##
## The station is placed by the grid (see scripts/core/Iso.gd); it never
## positions itself.

## The work table. One baked model for the whole farm, so no station can be a
## different size, height or angle from the one beside it.
const TABLE := "station_table"
## Parts bins under the table, drawn from the crate model at a fraction of its
## size — the same texture, not another asset.
const BIN_SCALE := 0.34
## Used only if the props have not been baked; the real value is measured from
## the table model below.
const MOUNT_FALLBACK := -38.0
## Local hit rectangle used for tapping. Constant, because every station is.
const TAP_RECT := Rect2(-72.0, -132.0, 144.0, 166.0)

@onready var printer: Node2D = $Printer
@onready var bubble: Node2D = $Bubble
@onready var label: Label = $Label

## Where a printer's feet meet the table top. Read off the table model itself,
## so the mount height and the table can never disagree.
@onready var mount_y: float = -Props.top(TABLE) if Props.has(TABLE) else MOUNT_FALLBACK

var slot_id: String = ""
var station_label: String = "P1"
var printer_id: String = ""

var _status: String = "idle"
var _health: float = 100.0


func _ready() -> void:
	Props.prepare(self)
	printer.position = Vector2(0, mount_y)
	bubble.call("set_base", mount_y - 76.0)
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
	tween.tween_property(printer, "position:y", mount_y, 0.5).from(mount_y - 60.0) \
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
	# The sprite carries no shadow of its own, so the table is grounded the
	# same way every other solid in the room is.
	IsoDraw.shadow(self, Vector2(0, 2.0), Props.half_width(TABLE) * 0.86, 0.12)

	# Parts bins tucked under the table, as in a real print farm. Drawn before
	# the table so the table front hides their lower halves.
	Props.draw(self, "crate", Vector2(-22.0, 9.0), BIN_SCALE)
	Props.draw(self, "crate", Vector2(21.0, 5.0), BIN_SCALE)

	# The work table. Every station's is the same model at the same scale, in
	# the same projection, standing on the cell the grid gave it.
	Props.draw(self, TABLE, Vector2.ZERO)

	# Station name plate on the floor at the front edge.
	IsoDraw.chip(self, Rect2(-27.0, 13.0, 54.0, 19.0), Palette.PAPER, 8.0)
	IsoDraw.chip(self, Rect2(-27.0, 13.0, 54.0, 19.0), Color(0.14, 0.20, 0.29, 0.10), 8.0)


## Depth ordering happens between stations, in the Stations container, never
## inside one. A station is a single composite object: the table, the machine
## standing on it and its label are drawn in tree order, so the machine is
## always in front of the table it sits on.
