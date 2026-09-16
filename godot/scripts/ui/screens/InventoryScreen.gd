extends MarginContainer
## The inventory.
##
## Everything the workshop owns that is not a machine: filament, finished
## products waiting on the store shelf, and spare parts. Filament comes first,
## because filament is what the workshop runs on.
##
## Each spool is drawn as a spool — its reel in the material's colour and its
## remaining grams as a fill — so browsing stock feels like looking at the rack
## rather than reading a table.

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

	var spools := GameState.spools()
	_column.add_child(UiKit.section(I18n.t("spools"), spools.size()))
	_column.add_child(_filament_summary(spools))

	var buy := UiKit.button(I18n.t("buy_filament"), "primary", true)
	buy.pressed.connect(func(): Events.navigate.emit("buy_filament"))
	_column.add_child(buy)

	if spools.is_empty():
		_column.add_child(UiKit.empty_state("spool", I18n.t("spools"), I18n.t("buy_filament")))
	else:
		_column.add_child(_spool_grid(spools))

	if Config.has_feature(GameState.level(), "store"):
		_column.add_child(UiKit.vspace(4.0))
		_column.add_child(_products_section())

	if Config.has_feature(GameState.level(), "maintenance"):
		_column.add_child(UiKit.vspace(4.0))
		_column.add_child(UiKit.section(I18n.t("parts")))
		_column.add_child(_parts_section())


## How much filament there is, and of what. The per-material totals are what a
## player checks before accepting an order — the grid below answers "which
## spool", this answers "have I got enough".
func _filament_summary(spools: Array) -> Control:
	var by_material: Dictionary = {}
	var total := 0.0
	for spool in spools:
		var material_id := String(spool.get("materialId", "pla"))
		var grams := float(spool.get("grams", 0.0))
		by_material[material_id] = float(by_material.get(material_id, 0.0)) + grams
		total += grams

	var card := UiKit.card(12, Palette.SAND)
	var column := UiKit.vbox(8)
	card.add_child(column)

	var head := UiKit.hbox(10)
	head.add_child(UiKit.icon("spool", Palette.TEAL_DEEP, 22.0))
	var info := UiKit.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label("%s %s %s" % [
		I18n.t("filament_on_hand"), I18n.number(int(total)), I18n.t("grams")
	], UiKit.FONT_BODY, Palette.INK, true))
	info.add_child(UiKit.caption("%s · %s" % [
		I18n.tn("spools_count", spools.size()), I18n.tn("materials_count", by_material.size())
	]))
	head.add_child(info)
	column.add_child(head)

	# One chip per material held, in catalogue order so the row does not
	# reshuffle itself every time a spool runs out.
	var wrap := HFlowContainer.new()
	wrap.add_theme_constant_override("h_separation", 6)
	wrap.add_theme_constant_override("v_separation", 6)
	for material in Config.all_materials():
		var material_id := String(material.get("id", ""))
		if not by_material.has(material_id):
			continue
		var tint := Config.material_tint(material_id)
		wrap.add_child(UiKit.pill("%s %s %s" % [
			I18n.name_of("material", material),
			I18n.number(int(by_material[material_id])), I18n.t("grams")
		], Color(tint.r, tint.g, tint.b, 0.18), Palette.shade(tint, 0.20)))
	if wrap.get_child_count() > 0:
		column.add_child(wrap)
	return card


## What the workshop has printed for its own store and not yet sold. The store
## sells it while the player is away, so this is stock, not a to-do list.
func _products_section() -> Control:
	var stock := GameState.store_stock()
	var demand := GameState.demand()
	var held: Array = Config.all_products().filter(
		func(p): return int(stock.get(String(p.get("id", "")), 0)) > 0
	)

	var column := UiKit.vbox(UiKit.GAP_MD)
	column.add_child(UiKit.section(I18n.t("products"), held.size()))
	if held.is_empty():
		var card := UiKit.card(12)
		var row := UiKit.hbox(10)
		card.add_child(row)
		row.add_child(UiKit.icon("store", Palette.INK_FAINT, 20.0))
		row.add_child(UiKit.caption(I18n.t("no_products"), Palette.INK_FAINT))
		column.add_child(card)
		return column

	var card := UiKit.card()
	var list := UiKit.vbox(10)
	card.add_child(list)
	var total := 0
	for product in held:
		var product_id := String(product.get("id", ""))
		var count := int(stock.get(product_id, 0))
		var unit := int(round(
			float(product.get("salePrice", 0)) * float(demand.get(product_id, 1.0))
		))
		total += count * unit

		var row := UiKit.hbox(10)
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(36, 36)
		frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		frame.add_theme_stylebox_override("panel", UiKit.flat(Palette.SAND, 10.0))
		frame.add_child(ProductThumb.new(String(product.get("icon", "dino")), Palette.TEAL))
		row.add_child(frame)
		var name_label := UiKit.label(
			I18n.name_of("product", product), UiKit.FONT_SMALL, Palette.INK, false, true
		)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(UiKit.pill("×%d" % count, Palette.SAND, Palette.INK_SOFT))
		row.add_child(UiKit.coin(count * unit, Palette.GREEN_DEEP))
		list.add_child(row)

	var footer := UiKit.hbox(8)
	footer.add_child(UiKit.caption(I18n.t("worth"), Palette.INK_FAINT))
	footer.add_child(UiKit.spacer())
	footer.add_child(UiKit.coin(total, Palette.GREEN_DEEP, UiKit.FONT_BODY))
	list.add_child(footer)
	column.add_child(card)
	return column


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
	var disc := SpoolDisc.new(color, fill, String(spool.get("materialId", "pla")))
	head.add_child(disc)
	var info := UiKit.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label(I18n.name_of("material", material), UiKit.FONT_BODY, Palette.INK, true))
	info.add_child(UiKit.caption(I18n.name_of("color", color_entry)))
	head.add_child(info)
	column.add_child(head)

	column.add_child(UiKit.bar(fill, color, 7.0))
	var foot := UiKit.hbox(6)
	foot.add_child(UiKit.caption("%d / %d %s" % [int(grams), int(capacity), I18n.t("grams")]))
	foot.add_child(UiKit.spacer())
	if grams <= 0.0:
		foot.add_child(UiKit.pill(I18n.t("empty_spool"), Palette.SAND, Palette.INK_FAINT))
	column.add_child(foot)
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
		var name_label := UiKit.label(I18n.name_of("part", part), UiKit.FONT_SMALL, Palette.INK)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(UiKit.pill("×%d" % int(owned.get(part_id, 0)), Palette.SAND, Palette.INK_SOFT))

		var price := int(part.get("price", 0))
		var buy := UiKit.cost_button(price, "secondary", 88.0)
		buy.disabled = GameState.coins() < price
		buy.pressed.connect(func():
			if await GameState.intent("buy_part", {"partId": part_id, "count": 1}):
				Audio.play("purchase"))
		row.add_child(buy)
		column.add_child(row)
	return card
