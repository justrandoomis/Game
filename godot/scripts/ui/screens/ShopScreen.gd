extends MarginContainer
## The store.
##
## Products the workshop can make and sell on its own, with what they cost to
## produce, what they fetch, and how demand is moving. Demand is a trend chip,
## not a trading terminal.
##
## Every line quotes a margin, because the decision the screen exists for is
## which product is worth the machine time — not which one sells for the most.

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

	# The store is a level unlock: before then the screen says so rather than
	# showing an empty shell.
	if not Config.has_feature(GameState.level(), "store"):
		_column.add_child(UiKit.empty_state(
			"store", I18n.t("shop"), I18n.tf("unlocks_at", [Config.feature_level("store")])
		))
		return

	var stock := GameState.store_stock()
	var demand := GameState.demand()
	var products: Array = Config.all_products().filter(
		func(p): return int(p.get("unlockLevel", 1)) <= GameState.level()
	)

	_column.add_child(UiKit.section(I18n.t("shop"), products.size()))
	_column.add_child(_shelf_summary(stock, demand))

	for product in products:
		_column.add_child(_product_card(product, stock, demand))

	if products.is_empty():
		_column.add_child(UiKit.empty_state("store", I18n.t("shop"), I18n.t("level_too_low")))
	else:
		_column.add_child(_locked_hint())


## What is on the shelf right now, and what it is worth at today's prices. The
## store sells by itself while the player is away, so this is the line that
## says whether there is anything there to sell.
func _shelf_summary(stock: Dictionary, demand: Dictionary) -> Control:
	var units := 0
	var value := 0
	for product in Config.all_products():
		var product_id := String(product.get("id", ""))
		var count := int(stock.get(product_id, 0))
		if count <= 0:
			continue
		units += count
		value += count * int(round(
			float(product.get("salePrice", 0)) * float(demand.get(product_id, 1.0))
		))

	var card := UiKit.card(12, Palette.SAND)
	var row := UiKit.hbox(10)
	card.add_child(row)
	row.add_child(UiKit.icon("store", Palette.CORAL_DEEP, 22.0))
	var info := UiKit.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label(
		"%s %d" % [I18n.t("on_the_shelf"), units], UiKit.FONT_BODY, Palette.INK, true
	))
	info.add_child(UiKit.caption(I18n.t("store_sells_itself")))
	row.add_child(info)
	row.add_child(UiKit.coin(value, Palette.GREEN_DEEP, UiKit.FONT_BODY))
	return card


## The next product the player has not reached yet, so the shop always shows
## there is more coming rather than ending on the last unlocked line.
func _locked_hint() -> Control:
	var best := {}
	for product in Config.all_products():
		var level := int(product.get("unlockLevel", 1))
		if level <= GameState.level():
			continue
		if best.is_empty() or level < int(best.get("unlockLevel", 1)):
			best = product
	if best.is_empty():
		return UiKit.vspace(0.0)

	var card := UiKit.card(12, Palette.SAND)
	var row := UiKit.hbox(10)
	card.add_child(row)
	row.add_child(UiKit.icon("store", Palette.INK_FAINT, 20.0))
	var name_label := UiKit.label(
		I18n.name_of("product", best), UiKit.FONT_SMALL, Palette.INK_FAINT
	)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(UiKit.pill(
		I18n.tf("unlocks_at", [int(best.get("unlockLevel", 1))]), Palette.LINE, Palette.INK_SOFT
	))
	return card


func _product_card(product: Dictionary, stock: Dictionary, demand: Dictionary) -> Control:
	var product_id := String(product.get("id", ""))
	var multiplier := float(demand.get(product_id, 1.0))
	var sale := int(round(float(product.get("salePrice", 0)) * multiplier))
	var cost := _cost_estimate(product)
	var card := UiKit.card(12)
	var column := UiKit.vbox(8)
	card.add_child(column)

	var head := UiKit.hbox(10)
	var thumb_frame := PanelContainer.new()
	thumb_frame.custom_minimum_size = Vector2(44, 44)
	thumb_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	thumb_frame.add_theme_stylebox_override("panel", UiKit.flat(Palette.SAND, 12.0))
	thumb_frame.add_child(ProductThumb.new(String(product.get("icon", "dino")), Palette.TEAL))
	head.add_child(thumb_frame)

	var info := UiKit.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label(
		I18n.name_of("product", product), UiKit.FONT_BODY, Palette.INK, true, true
	))
	info.add_child(UiKit.caption("%s %d · %s · %d %s" % [
		I18n.t("stock"), int(stock.get(product_id, 0)),
		ServerClock.format_short(int(product.get("minutes", 0)) * 60000),
		int(product.get("grams", 0)), I18n.t("grams")
	]))
	head.add_child(info)
	head.add_child(_demand_chip(multiplier))
	column.add_child(head)

	# Cost, price and what is left of the difference. The margin is the only
	# number here the player cannot work out at a glance, so it is the one
	# given a colour.
	var prices := UiKit.hbox(12)
	prices.add_child(_price("production_cost", cost, Palette.INK_SOFT))
	prices.add_child(_price("sale_price", sale, Palette.INK))
	prices.add_child(UiKit.spacer())
	prices.add_child(_price(
		"margin", sale - cost, Palette.GREEN_DEEP if sale > cost else Palette.CORAL_DEEP
	))
	column.add_child(prices)

	var running := _in_production(product_id)
	if running > 0:
		var note := UiKit.hbox(6)
		note.add_child(UiKit.icon("printer", Palette.SKY_DEEP, 15.0))
		note.add_child(UiKit.caption(
			I18n.tn("printing_now", running), Palette.SKY_DEEP
		))
		column.add_child(note)

	var produce := UiKit.button(I18n.t("print_more"), "secondary", true)
	produce.custom_minimum_size = Vector2(0, 42.0)
	produce.pressed.connect(func(): Events.navigate.emit("produce:" + product_id))
	column.add_child(produce)
	return card


## Units of this product already on the machines, so the shop does not invite
## the player to print a second batch of something they are halfway through.
func _in_production(product_id: String) -> int:
	var total := 0
	for job in GameState.jobs():
		if String(job.get("productId", "")) != product_id:
			continue
		var status := String(job.get("status", ""))
		if status == "queued" or status == "printing":
			total += int(job.get("qty", 1))
	return total


## Rough cost of one unit: filament plus machine time.
func _cost_estimate(product: Dictionary) -> int:
	var materials: Array = product.get("materials", [])
	if materials.is_empty():
		return 0
	var material := Config.material(String(materials[0]))
	var spool_size: float = maxf(1.0, float(material.get("spoolSize", 1000)))
	return int(round(
		float(product.get("grams", 0)) / spool_size * float(material.get("pricePerSpool", 0))
		+ float(product.get("minutes", 0)) / 60.0 * 8.0
	))


func _price(key: String, value: int, color: Color) -> Control:
	var column := UiKit.vbox(1)
	column.add_child(UiKit.label(I18n.t(key), UiKit.FONT_CAPTION, Palette.INK_FAINT))
	column.add_child(UiKit.coin(value, color))
	return column


## Demand as a trend, and always as a figure. It used to fall back to the word
## "Demand" whenever the multiplier was near one, which reads as a chip that
## failed to load rather than as a market holding steady.
func _demand_chip(multiplier: float) -> Control:
	var percent := int(round((multiplier - 1.0) * 100.0))
	var color := Palette.INK_SOFT
	var glyph := ""
	if percent >= 5:
		color = Palette.GREEN_DEEP
		glyph = "trend_up"
	elif percent <= -5:
		color = Palette.CORAL_DEEP
		glyph = "trend_down"

	var row := UiKit.hbox(4)
	if glyph != "":
		row.add_child(UiKit.icon(glyph, color, 11.0))
	row.add_child(UiKit.label("%+d%%" % percent, UiKit.FONT_CAPTION, color, true))
	var chip := UiKit.chip(row, Color(color.r, color.g, color.b, 0.14))
	chip.tooltip_text = I18n.t("demand")
	return chip
