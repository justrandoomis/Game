extends MarginContainer
## The inventory.
##
## Filament first, because filament is what the workshop runs on. Each spool is
## drawn as a spool with its remaining grams shown as a fill, so browsing stock
## feels like looking at the rack rather than reading a table.

var _column: VBoxContainer


func _ready() -> void:
	# A container root, so the scroll view is fitted to the screen rect exactly
	# and its contents are forced to the phone's width instead of overflowing.
	var parts := UiKit.screen_scroll()
	_column = parts["column"]
	add_child(parts["scroll"])
	GameState.state_changed.connect(rebuild)
	I18n.language_changed.connect(func(_lang): rebuild())
	rebuild()


func rebuild() -> void:
	if _column == null:
		return
	for child in _column.get_children():
		child.queue_free()
	UiKit.apply_direction(self)

	_column.add_child(UiKit.title(I18n.t("spools")))
	var spools := GameState.spools()
	if spools.is_empty():
		_column.add_child(UiKit.empty_state("spool", I18n.t("spools"), I18n.t("buy_filament")))
	else:
		_column.add_child(_spool_grid(spools))

	var buy := UiKit.button(I18n.t("buy_filament"), "primary", true)
	buy.pressed.connect(func(): Events.navigate.emit("buy_filament"))
	_column.add_child(buy)

	if Config.has_feature(GameState.level(), "maintenance"):
		_column.add_child(UiKit.vspace(8.0))
		_column.add_child(UiKit.title(I18n.t("parts")))
		_column.add_child(_parts_section())


## Two spools per row on a phone; the tile is big enough to read at a glance.
func _spool_grid(spools: Array) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for spool in spools:
		grid.add_child(_spool_tile(spool))
	return grid


func _spool_tile(spool: Dictionary) -> Control:
	var material := Config.material(String(spool.get("materialId", "")))
	var color_entry := Config.color(String(spool.get("colorId", "")))
	var grams := float(spool.get("grams", 0.0))
	var capacity: float = maxf(1.0, float(spool.get("capacity", 1000.0)))
	var fill: float = clampf(grams / capacity, 0.0, 1.0)
	var color := Palette.filament(String(spool.get("colorId", "white")))

	var card := UiKit.card(12)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UiKit.vbox(8)
	card.add_child(column)

	var head := UiKit.hbox(8)
	var disc := SpoolDisc.new(color, fill)
	head.add_child(disc)
	var info := UiKit.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label(String(material.get("name", "")), UiKit.FONT_BODY, Palette.INK, true))
	info.add_child(UiKit.caption(String(color_entry.get("name", ""))))
	head.add_child(info)
	column.add_child(head)

	column.add_child(UiKit.bar(fill, color, 7.0))
	column.add_child(UiKit.caption("%d / %d %s" % [int(grams), int(capacity), I18n.t("grams")]))
	return card


func _parts_section() -> Control:
	var card := UiKit.card()
	var column := UiKit.vbox(8)
	card.add_child(column)
	var owned := GameState.parts()

	for part in Config.all_parts():
		var part_id := String(part.get("id", ""))
		if GameState.level() < int(part.get("unlockLevel", 1)):
			continue
		var row := UiKit.hbox(8)
		row.add_child(UiKit.icon("wrench", Palette.STEEL_DARK, 18.0))
		var name_label := UiKit.label(String(part.get("name", "")), UiKit.FONT_SMALL, Palette.INK)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(UiKit.pill("×%d" % int(owned.get(part_id, 0)), Palette.SAND, Palette.INK_SOFT))

		var price := int(part.get("price", 0))
		var buy := UiKit.button(I18n.number(price), "secondary")
		buy.custom_minimum_size = Vector2(80, 38)
		buy.disabled = GameState.coins() < price
		buy.pressed.connect(func():
			if await GameState.intent("buy_part", {"partId": part_id, "count": 1}):
				Audio.play("purchase"))
		row.add_child(buy)
		column.add_child(row)
	return card
