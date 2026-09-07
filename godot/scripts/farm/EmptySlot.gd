extends Node2D
## An empty expansion slot.
##
## Drawn into the floor rather than floated over it as a card, so the workshop
## still reads as one room and the player can see exactly where it grows next.
## Three states: a station standing empty, the next station they can buy, and
## the ones still locked behind it.

const HW := Iso.TILE_W * 0.42
const HH := Iso.TILE_H * 0.42

@onready var label: Label = $Label
@onready var price_label: Label = $Price

var slot_id: String = ""
var available: bool = false
var cost: int = 0
var _time: float = 0.0


func _ready() -> void:
	label.position = Vector2(-52.0, 8.0)
	label.size = Vector2(104.0, 18.0)
	set_process(true)


func setup(next_slot_id: String, next_available: bool, caption: String, next_cost: int = 0) -> void:
	slot_id = next_slot_id
	available = next_available
	cost = next_cost
	if is_node_ready():
		label.text = caption
		label.add_theme_color_override(
			"font_color", Palette.INK if available else Palette.INK_FAINT
		)
		price_label.text = "" if cost <= 0 else I18n.number(cost)
		price_label.visible = cost > 0
	queue_redraw()


func _process(delta: float) -> void:
	if not available:
		return
	_time += delta
	# A slow breath on the next buyable slot draws the eye without nagging.
	modulate.a = 0.78 + 0.22 * (0.5 + 0.5 * sin(_time * 2.2))


func contains_point(local_point: Vector2) -> bool:
	# Point-in-diamond: the tile's own shape, so taps land where they look.
	return absf(local_point.x) / HW + absf(local_point.y) / HH <= 1.0


func _draw() -> void:
	if available:
		IsoDraw.diamond(self, Vector2.ZERO, HW, HH, Color(0.31, 0.75, 0.68, 0.18))
		IsoDraw.diamond_dashed(self, Vector2.ZERO, HW, HH, Palette.TEAL, 2.5, 10.0)
		_draw_plus(Palette.TEAL_DEEP)
	else:
		IsoDraw.diamond(self, Vector2.ZERO, HW, HH, Color(0.42, 0.48, 0.57, 0.08))
		IsoDraw.diamond_dashed(self, Vector2.ZERO, HW, HH, Palette.INK_FAINT, 1.5, 7.0)
		_draw_lock(Palette.INK_FAINT)

	# A chip behind the caption so it stays readable over any floor tone — and
	# none at all on a cell that has nothing to say.
	if label == null or label.text == "":
		return
	var chip_w: float = 96.0 if cost <= 0 else 104.0
	var chip_h: float = 20.0 if cost <= 0 else 36.0
	var chip := Rect2(-chip_w * 0.5, 2.0, chip_w, chip_h)
	IsoDraw.chip(self, Rect2(chip.position + Vector2(0, 1.5), chip.size), Color(0.14, 0.20, 0.29, 0.10), 9.0)
	IsoDraw.chip(self, chip, Palette.PAPER, 9.0)

	if cost > 0:
		# Price line under the caption, with a coin so it reads at a glance.
		draw_circle(Vector2(-16.0, 30.0), 5.5, Palette.YELLOW)
		draw_circle(Vector2(-16.0, 30.0), 3.4, Palette.YELLOW_DEEP)


func _draw_plus(color: Color) -> void:
	var at := Vector2(0, -12.0)
	draw_rect(Rect2(at.x - 9.0, at.y - 2.5, 18.0, 5.0), color)
	draw_rect(Rect2(at.x - 2.5, at.y - 9.0, 5.0, 18.0), color)


func _draw_lock(color: Color) -> void:
	var at := Vector2(0, -10.0)
	draw_rect(Rect2(at.x - 6.0, at.y - 1.0, 12.0, 9.0), color)
	draw_arc(at + Vector2(0, -1.0), 4.2, PI, TAU, 12, color, 2.0)
