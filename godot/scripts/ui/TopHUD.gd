extends Control
## The top HUD.
##
## Level and XP, Farm Coins, reputation, and a way into settings — and nothing
## else. Everything here is read from the server snapshot; the HUD never
## computes a balance of its own.
##
## Sized for a 360 px phone first: one row, real touch targets, no wrapping.

signal settings_pressed()

const BAR_H := 7.0

var _level_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _coins_label: Label
var _rep_label: Label
var _coin_anchor: Control
var _offline_chip: Control
## How much of the top of the screen belongs to the device, not the game.
var _safe_top: float = 0.0


## The height the HUD occupies, so the screens below it start under it rather
## than at a number typed into the scene.
func chrome_height() -> float:
	return 62.0 + _safe_top


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	# Clear of the notch. The HUD is pinned to the top of the screen, which on
	# a phone is behind the status bar unless it makes room for it.
	_safe_top = float(UiKit.safe_insets(self)["top"])
	custom_minimum_size = Vector2(0, 62.0 + _safe_top)
	_build()
	GameState.state_changed.connect(refresh)
	GameState.online_changed.connect(_on_online_changed)
	I18n.language_changed.connect(func(_lang): _apply_direction(); refresh())
	refresh()


func _apply_direction() -> void:
	UiKit.apply_direction(self)


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	# Clear of the notch: the HUD is pinned to the very top of the screen.
	margin.add_theme_constant_override("margin_top", int(8.0 + _safe_top))
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var row := UiKit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	row.add_child(_build_level())
	row.add_child(_build_offline())
	row.add_child(_build_coins())
	row.add_child(_build_reputation())
	row.add_child(_build_settings())
	_apply_direction()


## Level badge with the XP bar beside it — the player's headline progress.
func _build_level() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _hud_box())

	var row := UiKit.hbox(8)
	panel.add_child(row)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(30, 30)
	badge.add_theme_stylebox_override("panel", UiKit.flat(Palette.SKY_DEEP, 15.0))
	_level_label = UiKit.label("1", UiKit.FONT_SMALL, Palette.PAPER, true)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(_level_label)
	row.add_child(badge)

	var column := UiKit.vbox(2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_label = UiKit.label("0 / 0 XP", UiKit.FONT_CAPTION, Palette.INK_SOFT)
	_xp_bar = UiKit.bar(0.0, Palette.TEAL, BAR_H)
	column.add_child(_xp_label)
	column.add_child(_xp_bar)
	row.add_child(column)
	return panel


func _build_coins() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _hud_box())
	var row := UiKit.hbox(5)
	panel.add_child(row)
	row.add_child(UiKit.icon("coin", Palette.YELLOW_DEEP, 18.0))
	_coins_label = UiKit.label("0", UiKit.FONT_SMALL, Palette.INK, true)
	_coins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_coins_label)
	_coin_anchor = panel
	return panel


func _build_reputation() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _hud_box())
	var row := UiKit.hbox(4)
	panel.add_child(row)
	row.add_child(UiKit.icon("star", Palette.YELLOW, 16.0))
	# "2.0" beside a star is a rating out of something the player is left to
	# guess at. The scale is printed.
	_rep_label = UiKit.label("0.0 / 5", UiKit.FONT_SMALL, Palette.INK, true)
	_rep_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_rep_label)
	panel.tooltip_text = I18n.t("reputation")
	return panel


## A quiet chip that appears only when the workshop has stopped answering.
## Everything on the farm is interpolated between snapshots, so without it a
## dead connection looks exactly like a farm that is working.
func _build_offline() -> Control:
	var panel := PanelContainer.new()
	var box := UiKit.flat(Palette.CORAL, 14.0)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(UiKit.label(I18n.t("reconnecting"), UiKit.FONT_CAPTION, Palette.PAPER, true))
	panel.visible = false
	_offline_chip = panel
	return panel


func _build_settings() -> Control:
	var node := Button.new()
	node.custom_minimum_size = Vector2(40, 40)
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_stylebox_override("normal", _hud_box())
	node.add_theme_stylebox_override("hover", _hud_box())
	node.add_theme_stylebox_override("pressed", UiKit.flat(Palette.SAND, 14.0))
	var glyph := UiKit.icon("gear", Palette.INK_SOFT, 20.0)
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.add_child(glyph)
	node.pressed.connect(func():
		Audio.play("tap")
		settings_pressed.emit())
	return node


func _hud_box() -> StyleBoxFlat:
	var box := UiKit.flat(Color(1, 1, 1, 0.94), 14.0)
	box.content_margin_left = 8
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	box.shadow_color = Color(0.14, 0.20, 0.29, 0.12)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 2)
	return box


func refresh() -> void:
	if not GameState.ready_state or _level_label == null:
		return
	var level := GameState.level()
	var needed := Config.xp_for_level(level) if Config.is_loaded else 0
	_level_label.text = str(level)
	_xp_bar.value = 0.0 if needed <= 0 else clampf(float(GameState.xp()) / float(needed), 0.0, 1.0)
	_xp_label.text = "%s / %s XP" % [I18n.number(GameState.xp()), I18n.number(needed)]

	var coins := GameState.coins()
	if _coins_label.text != I18n.number(coins):
		_coins_label.text = I18n.number(coins)
		_pop(_coins_label)

	# Reputation is shown as a friendly star rating, not a raw percentage.
	var max_rep: float = 100.0
	if Config.is_loaded:
		max_rep = float(Config.data.get("reputation", {}).get("max", 100.0))
	_rep_label.text = I18n.tf(
		"of_five", ["%.1f" % (GameState.reputation() / maxf(1.0, max_rep) * 5.0)]
	)


func _on_online_changed(online: bool) -> void:
	if _offline_chip != null and is_instance_valid(_offline_chip):
		_offline_chip.visible = not online


func _pop(node: Control) -> void:
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(1.16, 1.16), 0.09)
	tween.tween_property(node, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Where coin bursts should fly to.
func coin_anchor() -> Vector2:
	if _coin_anchor == null:
		return Vector2(size.x * 0.5, 40.0)
	return _coin_anchor.get_global_rect().get_center()
