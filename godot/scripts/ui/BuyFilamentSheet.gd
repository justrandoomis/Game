extends "res://scripts/ui/BottomSheet.gd"
## Buying filament.
##
## Pick a material, pick a colour, pick how many, buy. Materials the player has
## not reached yet are shown greyed with the level they arrive at, so the range
## is something to look forward to rather than a surprise.
##
## The server takes up to ten spools in one purchase and used to be sent one at
## a time from here, which made stocking a workshop ten taps and ten round
## trips. The count below is that same limit.

const MAX_COUNT := 10

var _material_id: String = "pla"
var _color_id: String = "white"
var _count: int = 1


func open(preferred_material: String = "", preferred_color: String = "") -> void:
	if preferred_material != "":
		_material_id = preferred_material
	if preferred_color != "":
		_color_id = preferred_color
	_rebuild()
	GameState.state_changed.connect(_rebuild)


func _rebuild() -> void:
	if not is_instance_valid(self) or _closing:
		return
	for child in content().get_children():
		child.queue_free()

	add_header(I18n.t("buy_filament"), I18n.t("spools"))
	content().add_child(_material_picker())
	content().add_child(_color_picker())
	content().add_child(_summary())


	refit()

func _material_picker() -> Control:
	var column := UiKit.vbox(6)
	column.add_child(UiKit.label(I18n.t("material"), UiKit.FONT_SMALL, Palette.INK_SOFT, true))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)

	for material in Config.all_materials():
		var material_id := String(material.get("id", ""))
		var locked: bool = GameState.level() < int(material.get("unlockLevel", 1))
		var active: bool = material_id == _material_id

		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 60)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = locked
		button.add_theme_stylebox_override("normal", UiKit.flat(
			Palette.SKY_SOFT if active else Palette.PAPER, 14.0,
			Palette.SKY_DEEP if active else Palette.LINE, 2
		))
		button.add_theme_stylebox_override("disabled", UiKit.flat(Palette.SAND, 14.0))

		var inner := UiKit.vbox(1)
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(inner)
		var name_label := UiKit.label(String(material.get("name", "")), UiKit.FONT_SMALL,
			Palette.INK if not locked else Palette.INK_FAINT, true)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(name_label)
		var sub := UiKit.label(
			I18n.tf("unlocks_at", [int(material.get("unlockLevel", 1))]) if locked
				else I18n.number(int(material.get("pricePerSpool", 0))),
			UiKit.FONT_CAPTION, Palette.INK_FAINT
		)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(sub)

		button.pressed.connect(func():
			Audio.play("tap")
			_material_id = material_id
			_rebuild())
		grid.add_child(button)

	column.add_child(grid)
	return column


## Every colour at once, wrapped onto as many rows as it takes. A swipeable
## strip put half the range past the right edge of the sheet with nothing to
## say it was there, and a palette the player cannot see all of is not a
## palette.
func _color_picker() -> Control:
	var column := UiKit.vbox(6)
	var head := UiKit.hbox(6)
	head.add_child(UiKit.label(I18n.t("color"), UiKit.FONT_SMALL, Palette.INK_SOFT, true))
	head.add_child(UiKit.spacer())
	head.add_child(UiKit.caption(String(Config.color(_color_id).get("name", ""))))
	column.add_child(head)

	var wrap := HFlowContainer.new()
	wrap.add_theme_constant_override("h_separation", 8)
	wrap.add_theme_constant_override("v_separation", 8)
	for entry in Config.all_colors():
		var color_id := String(entry.get("id", ""))
		var active: bool = color_id == _color_id
		var button := Button.new()
		button.custom_minimum_size = Vector2(40, 40)
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = String(entry.get("name", color_id))
		button.add_theme_stylebox_override("normal", UiKit.flat(
			Palette.filament(color_id), 20.0,
			Palette.SKY_DEEP if active else Palette.LINE, 3 if active else 1
		))
		button.pressed.connect(func():
			Audio.play("tap")
			_color_id = color_id
			_rebuild())
		wrap.add_child(button)

	column.add_child(wrap)
	return column


## How many spools this purchase is for.
func _count_picker(price: int) -> Control:
	var row := UiKit.hbox(10)
	row.add_child(UiKit.label(I18n.t("quantity"), UiKit.FONT_SMALL, Palette.INK_SOFT, true))
	row.add_child(UiKit.spacer())

	var minus := UiKit.button("−", "secondary")
	minus.custom_minimum_size = Vector2(44, 40)
	minus.disabled = _count <= 1
	minus.pressed.connect(func():
		_count = maxi(1, _count - 1)
		_rebuild())
	row.add_child(minus)

	var value := UiKit.label(str(_count), UiKit.FONT_TITLE, Palette.INK, true)
	value.custom_minimum_size = Vector2(36, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)

	var plus := UiKit.button("+", "secondary")
	plus.custom_minimum_size = Vector2(44, 40)
	# Capped both by what the server accepts and by what the player can pay for.
	plus.disabled = _count >= MAX_COUNT or GameState.coins() < price * (_count + 1)
	plus.pressed.connect(func():
		_count = mini(MAX_COUNT, _count + 1)
		_rebuild())
	row.add_child(plus)
	return row


func _summary() -> Control:
	var material := Config.material(_material_id)
	var price := int(material.get("pricePerSpool", 0))
	var column := UiKit.vbox(10)

	var card := UiKit.card(12, Palette.SAND)
	var row := UiKit.hbox(10)
	card.add_child(row)
	row.add_child(SpoolDisc.new(Palette.filament(_color_id), 1.0, _material_id))
	var info := UiKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label("%s · %s" % [
		String(material.get("name", "")), String(Config.color(_color_id).get("name", ""))
	], UiKit.FONT_BODY, Palette.INK, true))
	info.add_child(UiKit.caption("%d %s · %s %d %s" % [
		int(material.get("spoolSize", 1000)), I18n.t("grams"),
		I18n.t("available"), int(GameState.grams_available(_material_id, _color_id)),
		I18n.t("grams")
	]))
	info.add_child(UiKit.pill(
		I18n.t("reel_" + Reel.style(_material_id)),
		Color(Reel.tint(_material_id), 0.22), Palette.shade(Config.material_tint(_material_id), 0.2)
	))
	row.add_child(info)
	column.add_child(card)

	column.add_child(_count_picker(price))

	var total := price * _count
	var buy := UiKit.button("%s · %s" % [I18n.t("buy"), I18n.number(total)], "primary", true)
	buy.disabled = GameState.coins() < total
	var count := _count
	buy.pressed.connect(func():
		if await GameState.intent("buy_spool", {
			"materialId": _material_id, "colorId": _color_id, "count": count
		}):
			Audio.play("purchase")
			Events.toast.emit(I18n.tn("spools_count", count), "success"))
	column.add_child(buy)
	return column
