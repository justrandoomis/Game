extends Node2D
## A printer standing on a station.
##
## The shell is a baked sprite — one for the open-frame machines, one for the
## enclosed ones — tinted with the model's skin colour. Six shell colours across
## two families therefore cost two textures rather than twelve, and every
## machine in the workshop still shares one perspective and one set of
## proportions. See tools/PropModels.gd for the geometry.
##
## Everything that shows live state is still drawn by hand, because a sprite
## cannot say it: the part rising off the plate layer by layer, the head
## sweeping the gantry, the status lamp, and the spool — whose colour is the
## filament the server says is actually threaded, not a colour baked into the
## machine.
##
## Local origin (0, 0) is where the machine meets the table top. Everything
## above it is positioned from the shell's own mount points, so changing a
## proportion in PropModels moves the print, the nozzle and the spool with it.

const OPEN := "printer_open"
const AMS := "printer_ams"
const SPOOL := "spool"

## One shell per family. They are the same machine growing up, and the
## differences are the ones the player is buying: a P is a plain box, an X adds
## the camera that watches the print, an H is bigger, vented and twin-nozzled.
const SHELLS := {
	"A-series": "printer_open",
	"P-series": "printer_case_p",
	"X-series": "printer_case_x",
	"H-series": "printer_case_h",
}
const GLASS := {
	"P-series": "printer_glass_p",
	"X-series": "printer_glass_x",
	"H-series": "printer_glass_h",
}

## A machine is drawn at the size it is. Build volume is the number on the shop
## card, so the sprite scales with it and an A1 mini is visibly a small machine
## standing next to an H2C.
const SIZE_BASE := 180.0
const SIZE_SPAN := 220.0
const SIZE_MIN := 0.84
const SIZE_MAX := 1.20

## Layer thickness on screen, for revealing the print.
const LAYER_H := 3.4
## Clearance the nozzle keeps above the top layer, and below the gantry.
const NOZZLE_LIFT := 4.0
const GANTRY_CLEAR := 8.0
## The multi-material unit and the machine's own spool are drawn smaller than
## the model bakes at — an AMS is a box beside a printer, not another printer.
const AMS_SCALE := 0.62
const ARM_SPOOL_SCALE := 0.50

@onready var head: Node2D = $Head
@onready var model_node: Node2D = $Model
@onready var glass: Node2D = $Glass
@onready var light: Node2D = $StatusLight

var model_id: String = "a1_mini"
var status: String = "idle"
var progress: float = 0.0
var product_icon: String = "dino"
var filament_color: Color = Palette.GREEN
var has_ams: bool = false

var _skin: Dictionary = Palette.SKIN["cream"]
var _family: String = "A-series"
var _shell_scale: float = 1.0
var _material_id: String = "pla"
var _shown_layers: int = -1


## Declared for the boot check — see PrinterStation.prop_ids().
func prop_ids() -> PackedStringArray:
	var out := PackedStringArray([AMS, SPOOL])
	out.append_array(Reel.prop_ids())
	for id in SHELLS.values():
		out.append(String(id))
	for id in GLASS.values():
		out.append(String(id))
	return out


func _ready() -> void:
	Props.prepare(self)
	_apply_model()


## Point the machine at a catalog entry. Everything visual follows from this.
func configure(next_model_id: String, upgrades: Array = []) -> void:
	model_id = next_model_id
	has_ams = upgrades.has("ams")
	_apply_model()
	queue_redraw()


func _apply_model() -> void:
	var entry := Config.printer_model(model_id) if Config.is_loaded else {}
	_skin = Palette.skin(String(entry.get("skin", "cream")))
	_family = String(entry.get("family", "A-series"))
	if not SHELLS.has(_family):
		_family = "A-series"
	_shell_scale = _size_of(entry)
	if entry.has("multicolor") and bool(entry["multicolor"]):
		has_ams = true
	_place_parts()


## How large this model is drawn, from the build volume the shop quotes.
func _size_of(entry: Dictionary) -> float:
	var build: Array = entry.get("build", [])
	var largest := 0.0
	for value in build:
		largest = maxf(largest, float(value))
	if largest <= 0.0:
		return 1.0
	return clampf(SIZE_MIN + 0.36 * (largest - SIZE_BASE) / SIZE_SPAN, SIZE_MIN, SIZE_MAX)


## Put the moving parts where this shell keeps them. A bed slinger and an
## enclosed chamber hold their plate at the same height but not their gantry or
## their lamp, and both come off the models rather than out of this file.
func _place_parts() -> void:
	# @onready assigns these just before _ready() runs, so this holds inside
	# _ready() as well as on every later configure().
	if head == null:
		return
	var shell := _shell()
	var plate := Props.mount(shell, "plate", _shell_scale)
	model_node.position = plate
	head.position = plate
	model_node.scale = Vector2.ONE * _shell_scale
	light.position = Props.mount(shell, "lamp", _shell_scale)
	glass.call("set_shell", String(GLASS.get(_family, "")), _shell_scale, _skin["body"])


func _shell() -> String:
	return String(SHELLS.get(_family, OPEN))


func _enclosed() -> bool:
	return _family != "A-series"


## Update the live print. Only redraws the model when a layer actually lands,
## so a running printer costs one redraw every few seconds, not every frame.
func set_print(
	next_status: String, next_progress: float, icon: String, color: Color,
	material_id: String = "pla"
) -> void:
	var layers_before := _shown_layers
	var color_before := filament_color
	var material_before := _material_id
	_material_id = material_id
	status = next_status
	progress = clampf(next_progress, 0.0, 1.0)
	product_icon = icon
	filament_color = color

	var total: int = Shapes.profile(icon).size()
	_shown_layers = clampi(int(ceil(progress * total)), 0, total)

	head.visible = status == "printing"
	if head.has_method("set_active"):
		head.call("set_active", status == "printing", _head_height())
	if light.has_method("set_status"):
		light.call("set_status", status)
	if _shown_layers != layers_before and model_node.has_method("set_model"):
		model_node.call("set_model", icon, color, progress)
	# The spool on the arm is part of this node's own drawing, so a change of
	# filament has to repaint it.
	if color != color_before or material_id != material_before:
		queue_redraw()


## How far above the plate the nozzle rides: the layers printed so far, never
## lower than the plate and never into the gantry.
func _head_height() -> float:
	if _shown_layers <= 0:
		return NOZZLE_LIFT
	var shell := _shell()
	var span := absf(
		Props.mount(shell, "gantry", _shell_scale).y - Props.mount(shell, "plate", _shell_scale).y
	)
	return clampf(
		float(_shown_layers) * LAYER_H + NOZZLE_LIFT, NOZZLE_LIFT, maxf(NOZZLE_LIFT, span - GANTRY_CLEAR)
	)


func _draw() -> void:
	var shell := _shell()
	var body: Color = _skin["body"]
	Props.draw(self, shell, Vector2.ZERO, _shell_scale, body)

	# An open machine wears its spool on an arm over the gantry, where the
	# player can see what is loaded. An enclosed one keeps it inside.
	if not _enclosed():
		var at := Props.mount(shell, "spool", _shell_scale)
		var size := ARM_SPOOL_SCALE * _shell_scale
		Props.draw(self, SPOOL, at, size, filament_color)
		Props.draw(self, Reel.prop(_material_id), at, size, Reel.tint(_material_id))

	if has_ams:
		Props.draw(self, AMS, Props.mount(shell, "ams", _shell_scale), AMS_SCALE * _shell_scale, body)
