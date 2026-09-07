extends Control
## The bottom navigation.
##
## Five destinations, colourful and obvious, with a clear active state and
## enough height to be comfortable on a phone without eating the farm. Honours
## the iPhone home-indicator safe area.

signal selected(screen: String)

const ITEMS := [
	{"id": "farm", "icon": "home", "color": Palette.TEAL},
	{"id": "orders", "icon": "clipboard", "color": Palette.SKY_DEEP},
	{"id": "shop", "icon": "store", "color": Palette.CORAL},
	{"id": "inventory", "icon": "box", "color": Palette.ORANGE},
	{"id": "upgrades", "icon": "arrow_up", "color": Palette.GREEN_DEEP},
]

var current: String = "farm"
var _buttons: Dictionary = {}
var _badges: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_build()
	GameState.state_changed.connect(_refresh_badges)
	I18n.language_changed.connect(func(_lang): _relabel())


func _build() -> void:
	var safe_bottom: float = maxf(DisplayServer.get_display_safe_area().position.y * 0.0, 0.0)
	custom_minimum_size = Vector2(0, 74.0 + safe_bottom)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := UiKit.flat(Palette.PAPER, 0.0)
	box.corner_radius_top_left = 22
	box.corner_radius_top_right = 22
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 8
	box.content_margin_bottom = int(10.0 + safe_bottom)
	box.shadow_color = Color(0.14, 0.20, 0.29, 0.14)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, -2)
	panel.add_theme_stylebox_override("panel", box)
	add_child(panel)

	var row := UiKit.hbox(0)
	panel.add_child(row)

	for item in ITEMS:
		row.add_child(_build_item(item))
	_update_active()
	UiKit.apply_direction(self)


func _build_item(item: Dictionary) -> Control:
	var id: String = item["id"]
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 54.0)
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.add_theme_stylebox_override("normal", UiKit.flat(Color(1, 1, 1, 0), 14.0))
	button.add_theme_stylebox_override("hover", UiKit.flat(Color(1, 1, 1, 0), 14.0))
	button.add_theme_stylebox_override("pressed", UiKit.flat(Palette.SAND, 14.0))

	var column := UiKit.vbox(2)
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)

	var glyph := UiKit.icon(item["icon"], Palette.INK_FAINT, 24.0)
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(glyph)

	var caption := UiKit.label(I18n.t(id), UiKit.FONT_CAPTION, Palette.INK_FAINT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)

	# Badge dot for boards that need attention.
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(9, 9)
	badge.add_theme_stylebox_override("panel", UiKit.flat(Palette.CORAL, 5.0))
	badge.position = Vector2(38, 6)
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(badge)

	button.pressed.connect(func():
		Audio.play("tap")
		select(id))

	_buttons[id] = {"button": button, "icon": glyph, "label": caption, "color": item["color"]}
	_badges[id] = badge
	return button


func select(id: String) -> void:
	if current == id:
		return
	current = id
	_update_active()
	selected.emit(id)


func _update_active() -> void:
	for id in _buttons.keys():
		var entry: Dictionary = _buttons[id]
		var active: bool = id == current
		var color: Color = entry["color"] if active else Palette.INK_FAINT
		entry["icon"].color = color
		entry["label"].add_theme_color_override("font_color", color)
		var box: StyleBoxFlat = UiKit.flat(
			Color(color.r, color.g, color.b, 0.12) if active else Color(1, 1, 1, 0), 14.0
		)
		entry["button"].add_theme_stylebox_override("normal", box)
		if active:
			var glyph: Control = entry["icon"]
			var tween: Tween = glyph.create_tween()
			tween.tween_property(glyph, "scale", Vector2(1.18, 1.18), 0.09)
			tween.tween_property(glyph, "scale", Vector2.ONE, 0.18) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _relabel() -> void:
	for id in _buttons.keys():
		_buttons[id]["label"].text = I18n.t(id)
	UiKit.apply_direction(self)


## Dots that tell the player where there is something to do.
func _refresh_badges() -> void:
	if not GameState.ready_state:
		return
	var offers: int = GameState.offered_orders().size()
	var ready: int = GameState.orders().filter(
		func(o): return String(o.get("status", "")) == "ready"
	).size()
	_badges["orders"].visible = offers > 0 or ready > 0

	var needs_attention: bool = GameState.printers().any(
		func(p): return String(p.get("status", "")) == "failed"
	)
	_badges["farm"].visible = needs_attention
