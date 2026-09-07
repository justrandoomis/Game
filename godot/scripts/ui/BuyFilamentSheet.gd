extends "res://scripts/ui/BottomSheet.gd"
## Buying filament.
##
## Pick a material, pick a colour, buy the spool. Materials the player has not
## reached yet are shown greyed with the level they arrive at, so the range is
## something to look forward to rather than a surprise.

var _material_id: String = "pla"
var _color_id: String = "white"


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


func _color_picker() -> Control:
	var column := UiKit.vbox(6)
	column.add_child(UiKit.label(I18n.t("color"), UiKit.FONT_SMALL, Palette.INK_SOFT, true))

	var strip := UiKit.strip(48.0, 8)
	var row: HBoxContainer = strip["row"]
	for entry in Config.all_colors():
		var color_id := String(entry.get("id", ""))
		var active: bool = color_id == _color_id
		var button := Button.new()
		button.custom_minimum_size = Vector2(40, 40)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_stylebox_override("normal", UiKit.flat(
			Palette.filament(color_id), 20.0,
			Palette.SKY_DEEP if active else Palette.LINE, 3 if active else 1
		))
		button.pressed.connect(func():
			Audio.play("tap")
			_color_id = color_id
			_rebuild())
		row.add_child(button)

	column.add_child(strip["scroll"])
	return column


func _summary() -> Control:
	var material := Config.material(_material_id)
	var price := int(material.get("pricePerSpool", 0))
	var column := UiKit.vbox(10)

	var card := UiKit.card(12, Palette.SAND)
	var row := UiKit.hbox(10)
	card.add_child(row)
	row.add_child(SpoolDisc.new(Palette.filament(_color_id), 1.0))
	var info := UiKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label("%s · %s" % [
		String(material.get("name", "")), String(Config.color(_color_id).get("name", ""))
	], UiKit.FONT_BODY, Palette.INK, true))
	info.add_child(UiKit.caption("%d %s · %s %d" % [
		int(material.get("spoolSize", 1000)), I18n.t("grams"),
		I18n.t("available"), int(GameState.grams_available(_material_id, _color_id))
	]))
	row.add_child(info)
	column.add_child(card)

	var buy := UiKit.button("%s · %s" % [I18n.t("buy"), I18n.number(price)], "primary", true)
	buy.disabled = GameState.coins() < price
	buy.pressed.connect(func():
		if await GameState.intent("buy_spool", {"materialId": _material_id, "colorId": _color_id, "count": 1}):
			Audio.play("purchase")
			Events.toast.emit(I18n.t("buy_filament"), "success"))
	column.add_child(buy)
	return column
