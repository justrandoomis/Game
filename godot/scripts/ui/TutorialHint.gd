extends Control
## The opening guidance.
##
## Three sentences, shown one at a time, driven by what the workshop actually
## looks like rather than by a stored script — so it is always correct, and it
## disappears for good once the player has run their first job. No modal steps,
## no blocking overlays.

var _label: Label
var _card: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 56)
	_build()
	GameState.state_changed.connect(refresh)
	I18n.language_changed.connect(func(_lang): refresh())
	refresh()


func _build() -> void:
	_card = PanelContainer.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.offset_left = 16.0
	_card.offset_right = -16.0
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiKit.flat(Palette.INK, UiKit.RADIUS)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	box.shadow_color = Color(0.14, 0.20, 0.29, 0.22)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 3)
	_card.add_theme_stylebox_override("panel", box)
	add_child(_card)

	var row := UiKit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)
	row.add_child(UiKit.icon("printer", Palette.SKY, 20.0))
	_label = UiKit.label("", UiKit.FONT_SMALL, Palette.PAPER)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_label)


## Which sentence applies is read straight off the farm.
func refresh() -> void:
	if not GameState.ready_state or _label == null:
		return

	var stats := GameState.stats()
	if int(stats.get("ordersCompleted", 0)) > 0:
		visible = false
		return

	var key := ""
	var has_running: bool = GameState.printers().any(
		func(p): return String(p.get("status", "")) == "printing"
	)
	var accepted := GameState.orders().filter(
		func(o): return String(o.get("status", "")) == "accepted"
	)

	if has_running:
		key = "tutorial_4"
	elif not accepted.is_empty():
		key = "tutorial_3"
	elif not GameState.offered_orders().is_empty():
		key = "tutorial_2"
	else:
		key = "tutorial_1"

	visible = true
	if _label.text != I18n.t(key):
		_label.text = I18n.t(key)
		_card.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_card, "modulate:a", 1.0, 0.25)
