extends MarginContainer
## The store.
##
## Products the workshop can make and sell on its own, with what they cost to
## produce, what they fetch, and how demand is moving. Demand is a trend chip,
## not a trading terminal.

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

	_column.add_child(UiKit.title(I18n.t("shop")))

	var stock := GameState.store_stock()
	var demand := GameState.demand()
	var any := false
	for product in Config.all_products():
		if int(product.get("unlockLevel", 1)) > GameState.level():
			continue
		any = true
		_column.add_child(_product_card(product, stock, demand))

	if not any:
		_column.add_child(UiKit.empty_state("store", I18n.t("shop"), I18n.t("level_too_low")))


func _product_card(product: Dictionary, stock: Dictionary, demand: Dictionary) -> Control:
	var product_id := String(product.get("id", ""))
	var card := UiKit.card()
	var column := UiKit.vbox(10)
	card.add_child(column)

	var head := UiKit.hbox(10)
	var thumb_frame := PanelContainer.new()
	thumb_frame.custom_minimum_size = Vector2(48, 48)
	thumb_frame.add_theme_stylebox_override("panel", UiKit.flat(Palette.SAND, 12.0))
	thumb_frame.add_child(ProductThumb.new(String(product.get("icon", "dino")), Palette.TEAL))
	head.add_child(thumb_frame)

	var info := UiKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label(String(product.get("name", "")), UiKit.FONT_BODY, Palette.INK, true))
	info.add_child(UiKit.caption("%s %d · %s" % [
		I18n.t("stock"), int(stock.get(product_id, 0)),
		ServerClock.format_short(int(product.get("minutes", 0)) * 60000)
	]))
	head.add_child(info)
	head.add_child(_demand_chip(float(demand.get(product_id, 1.0))))
	column.add_child(head)

	var multiplier := float(demand.get(product_id, 1.0))
	var sale := int(round(float(product.get("salePrice", 0)) * multiplier))
	var prices := UiKit.hbox(14)
	prices.add_child(_price("production_cost", _cost_estimate(product), Palette.INK_SOFT))
	prices.add_child(_price("sale_price", sale, Palette.GREEN_DEEP))
	prices.add_child(UiKit.spacer())
	column.add_child(prices)

	var produce := UiKit.button(I18n.t("print_more"), "secondary", true)
	produce.pressed.connect(func(): Events.navigate.emit("produce:" + product_id))
	column.add_child(produce)
	return card


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
	var row := UiKit.hbox(4)
	row.add_child(UiKit.icon("coin", color, 14.0))
	row.add_child(UiKit.label(I18n.number(value), UiKit.FONT_SMALL, color, true))
	column.add_child(row)
	return column


## Demand as a simple trend: rising, steady or slipping.
func _demand_chip(multiplier: float) -> Control:
	var text: String
	var color: Color
	if multiplier >= 1.35:
		text = "+%d%%" % int((multiplier - 1.0) * 100.0)
		color = Palette.GREEN_DEEP
	elif multiplier <= 0.8:
		text = "%d%%" % int((multiplier - 1.0) * 100.0)
		color = Palette.CORAL_DEEP
	else:
		text = I18n.t("demand")
		color = Palette.INK_FAINT
	return UiKit.pill(text, Color(color.r, color.g, color.b, 0.14), color)
