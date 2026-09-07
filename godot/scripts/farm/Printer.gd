extends Node2D
## A printer standing on a station.
##
## One drawing routine for the entire fleet: only the palette and the frame
## form change between models, so every machine in the workshop shares the same
## perspective and proportions no matter what the player buys.
##
## Local origin (0, 0) is where the machine meets the table top.

## Half-diagonals of the machine's base footprint.
const BASE_HW := 36.0
const BASE_HH := 18.0
const BASE_H := 14.0
## Build plate, sitting just above the base.
const PLATE_HW := 28.0
const PLATE_HH := 14.0
const PLATE_Y := -BASE_H - 1.0
## Frame height above the plate.
const FRAME_H := 52.0
const LAYER_H := 3.4

@onready var head: Node2D = $Head
@onready var model_node: Node2D = $Model
@onready var light: Node2D = $StatusLight

var model_id: String = "a1_mini"
var status: String = "idle"
var progress: float = 0.0
var product_icon: String = "dino"
var filament_color: Color = Palette.GREEN
var has_ams: bool = false

var _skin: Dictionary = Palette.SKIN["cream"]
var _enclosed: bool = false
var _shown_layers: int = -1


func _ready() -> void:
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
	# A-series machines are open-frame bed slingers; P/X/H are enclosed boxes.
	var family := String(entry.get("family", "A-series"))
	_enclosed = family != "A-series"
	if entry.has("multicolor") and bool(entry["multicolor"]):
		has_ams = true


## Update the live print. Only redraws the model when a layer actually lands,
## so a running printer costs one redraw every few seconds, not every frame.
func set_print(next_status: String, next_progress: float, icon: String, color: Color) -> void:
	var layers_before := _shown_layers
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


func _head_height() -> float:
	if _shown_layers <= 0:
		return 4.0
	return clampf(float(_shown_layers) * LAYER_H + 4.0, 4.0, FRAME_H - 8.0)


func _draw() -> void:
	var body: Color = _skin["body"]
	var trim: Color = _skin["trim"]

	# --- base ---------------------------------------------------------------
	IsoDraw.box(
		self, Vector2.ZERO, BASE_HW, BASE_HH, BASE_H,
		Palette.tint(body, 0.10), Palette.shade(body, 0.10), Palette.shade(body, 0.28)
	)
	# A dark front panel with a screen, so the machine reads as having a face
	# rather than as a pale block against a pale floor.
	IsoDraw.panel_right(self, Vector2(0, BASE_HH - 1.0), 20.0, 8.0, Palette.shade(trim, 0.10))
	IsoDraw.panel_right(self, Vector2(4.0, BASE_HH - 5.0), 9.0, 4.5, Palette.SKY)
	draw_circle(Vector2(18.0, -5.0), 1.8, Palette.GREEN)
	# A grounding shadow line where the base meets the table.
	draw_line(Vector2(-BASE_HW, 0), Vector2(0, BASE_HH), Palette.shade(trim, 0.25), 1.5)
	draw_line(Vector2(0, BASE_HH), Vector2(BASE_HW, 0), Palette.shade(trim, 0.25), 1.5)

	# --- build plate --------------------------------------------------------
	IsoDraw.diamond(self, Vector2(0, PLATE_Y), PLATE_HW, PLATE_HH, Palette.STEEL_DARK)
	IsoDraw.diamond(self, Vector2(0, PLATE_Y - 1.5), PLATE_HW - 2.0, PLATE_HH - 1.0, Palette.STEEL)

	if _enclosed:
		_draw_enclosed_frame(body, trim)
	else:
		_draw_open_frame(body, trim)

	if has_ams:
		_draw_ams(trim)


## Open bed-slinger frame: two rear uprights carrying a gantry beam.
func _draw_open_frame(body: Color, trim: Color) -> void:
	var post_y := PLATE_Y - 1.0
	IsoDraw.post(self, Vector2(-BASE_HW * 0.62, post_y - BASE_HH * 0.30), 4.0, FRAME_H, trim)
	IsoDraw.post(self, Vector2(BASE_HW * 0.62, post_y - BASE_HH * 0.30), 4.0, FRAME_H, trim)
	# Gantry beam across the top, drawn as a flat slab so it reads as a rail.
	IsoDraw.box(
		self, Vector2(0, post_y - BASE_HH * 0.30 - FRAME_H + 6.0), BASE_HW * 0.72, 5.0, 6.0,
		Palette.tint(trim, 0.18), trim, Palette.shade(trim, 0.2)
	)
	# Spool arm on the left upright, close enough to read as part of the machine.
	var arm_y := post_y - FRAME_H * 0.62
	var spool_at := Vector2(-BASE_HW * 0.62 - 13.0, arm_y + 4.0)
	draw_line(Vector2(-BASE_HW * 0.62, arm_y), spool_at, trim, 3.0)
	IsoDraw.spool(self, spool_at, 10.0, filament_color)


## Enclosed frame: a glass box. Front faces are translucent so the print stays
## visible — the point of the scene is watching the part appear.
func _draw_enclosed_frame(body: Color, trim: Color) -> void:
	var hw := BASE_HW * 0.96
	var hh := BASE_HH * 0.96
	var y := PLATE_Y - 1.0
	var glass := Color(0.86, 0.94, 0.98, 0.30)

	# Back faces first, so the model draws over them.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-hw, y), Vector2(0, y - hh), Vector2(0, y - hh - FRAME_H), Vector2(-hw, y - FRAME_H),
	]), Palette.shade(body, 0.30))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, y - hh), Vector2(hw, y), Vector2(hw, y - FRAME_H), Vector2(0, y - hh - FRAME_H),
	]), Palette.shade(body, 0.16))
	# Roof.
	IsoDraw.box(
		self, Vector2(0, y - FRAME_H + 5.0), hw, hh, 5.0,
		Palette.tint(body, 0.12), Palette.shade(body, 0.08), Palette.shade(body, 0.24)
	)
	# Front glass, drawn after the model by the parent's ordering of children;
	# here it is a light wash that keeps the interior readable.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-hw, y), Vector2(0, y + hh), Vector2(0, y + hh - FRAME_H), Vector2(-hw, y - FRAME_H),
	]), glass)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, y + hh), Vector2(hw, y), Vector2(hw, y - FRAME_H), Vector2(0, y + hh - FRAME_H),
	]), glass)
	# Corner posts to give the box definition.
	IsoDraw.post(self, Vector2(-hw, y), 2.4, FRAME_H, trim)
	IsoDraw.post(self, Vector2(hw, y), 2.4, FRAME_H, trim)


## The multi-material unit, drawn as a small stack of spools beside the machine.
func _draw_ams(trim: Color) -> void:
	var at := Vector2(BASE_HW + 12.0, PLATE_Y - 6.0)
	IsoDraw.solid(self, at, 13.0, 7.0, 16.0, Palette.STEEL)
	var swatches := [Palette.FILAMENT["red"], Palette.FILAMENT["blue"],
					 Palette.FILAMENT["yellow"], Palette.FILAMENT["green"]]
	for i in 4:
		draw_circle(at + Vector2(-6.0 + i * 4.0, -19.0), 1.9, swatches[i])
