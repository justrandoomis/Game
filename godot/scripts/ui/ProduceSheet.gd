extends "res://scripts/ui/BottomSheet.gd"
## Producing stock for the store.
##
## The same shape as assigning a customer order — pick a machine, pick the
## filament, pick how many — so the two production paths feel like one system.

var product_id: String = ""
var _printer_id: String = ""
var _material_id: String = ""
var _color_id: String = "white"
var _qty: int = 1
var _summary: VBoxContainer


func open(next_product_id: String) -> void:
	product_id = next_product_id
	var product := Config.product(product_id)
	var materials: Array = product.get("materials", [])
	if not materials.is_empty():
		_material_id = String(materials[0])
	var idle := GameState.idle_printers()
	var pool: Array = idle if not idle.is_empty() else GameState.printers()
	if not pool.is_empty():
		_printer_id = String(pool[0].get("id", ""))
	_rebuild()


func _rebuild() -> void:
	if not is_instance_valid(self) or _closing:
		return
	for child in content().get_children():
		child.queue_free()

	var product := Config.product(product_id)
	add_header(I18n.t("print_more"), String(product.get("name", "")))

	content().add_child(_printer_picker(product))
	content().add_child(_material_picker(product))
	content().add_child(_quantity_picker())
	_summary = UiKit.vbox(10)
	content().add_child(_summary)
	_refresh_summary(product)


	refit()

func _printer_picker(product: Dictionary) -> Control:
	var column := UiKit.vbox(6)
	column.add_child(UiKit.label(I18n.t("printers"), UiKit.FONT_SMALL, Palette.INK_SOFT, true))

	var strip := UiKit.strip(66.0, 8)
	var row: HBoxContainer = strip["row"]
	var tier := Config.workshop_tier(GameState.tier_index())
	for printer in GameState.printers():
		var printer_id := String(printer.get("id", ""))
		var model := Config.printer_model(String(printer.get("modelId", "")))
		var status := String(printer.get("status", "idle"))
		var supports: bool = Array(model.get("materials", [])).has(_material_id)
		if bool(product.get("multicolor", false)) and not bool(model.get("multicolor", false)):
			supports = false
		var cell := Iso.parse_slot(Val.field_text(printer, "slotId"))
		var station := Iso.slot_label(cell.x, cell.y, int(tier.get("cols", 2))) if cell.x >= 0 else "—"
		var active: bool = printer_id == _printer_id

		var button := Button.new()
		button.custom_minimum_size = Vector2(96, 58)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = not supports or status in ["failed", "maintenance"]
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
		var station_label := UiKit.label(station, UiKit.FONT_BODY, Palette.INK, true)
		station_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(station_label)
		var status_label := UiKit.label(I18n.t(status), UiKit.FONT_CAPTION, Palette.INK_SOFT)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(status_label)

		button.pressed.connect(func():
			Audio.play("tap")
			_printer_id = printer_id
			_rebuild())
		row.add_child(button)

	column.add_child(strip["scroll"])
	return column


func _material_picker(product: Dictionary) -> Control:
	var column := UiKit.vbox(6)
	column.add_child(UiKit.label(I18n.t("material"), UiKit.FONT_SMALL, Palette.INK_SOFT, true))

	var row := UiKit.hbox(8)
	for material_id in product.get("materials", []):
		var material := Config.material(String(material_id))
		if GameState.level() < int(material.get("unlockLevel", 1)):
			continue
		var active: bool = String(material_id) == _material_id
		var button := UiKit.button(String(material.get("name", "")), "secondary")
		button.custom_minimum_size = Vector2(76, 40)
		if active:
			button.add_theme_stylebox_override("normal", UiKit.flat(Palette.TEAL, UiKit.RADIUS))
			button.add_theme_color_override("font_color", Palette.PAPER)
		button.pressed.connect(func():
			_material_id = String(material_id)
			_rebuild())
		row.add_child(button)
	column.add_child(row)

	var colors := UiKit.hbox(6)
	for entry in Config.all_colors():
		var color_id := String(entry.get("id", ""))
		var owned := GameState.grams_available(_material_id, color_id)
		if owned <= 0.0:
			continue
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(34, 34)
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.add_theme_stylebox_override("normal", UiKit.flat(
			Palette.filament(color_id), 17.0,
			Palette.SKY_DEEP if color_id == _color_id else Palette.LINE,
			3 if color_id == _color_id else 1
		))
		swatch.pressed.connect(func():
			_color_id = color_id
			_rebuild())
		colors.add_child(swatch)
	column.add_child(colors)
	return column


func _quantity_picker() -> Control:
	var row := UiKit.hbox(8)
	row.add_child(UiKit.label(I18n.t("quantity"), UiKit.FONT_SMALL, Palette.INK_SOFT))
	row.add_child(UiKit.spacer())
	for amount in [1, 5, 10, 25]:
		var button := UiKit.button(str(amount), "secondary")
		button.custom_minimum_size = Vector2(52, 40)
		if amount == _qty:
			button.add_theme_stylebox_override("normal", UiKit.flat(Palette.TEAL, UiKit.RADIUS))
			button.add_theme_color_override("font_color", Palette.PAPER)
		button.pressed.connect(func():
			_qty = amount
			_rebuild())
		row.add_child(button)
	return row


func _refresh_summary(product: Dictionary) -> void:
	for child in _summary.get_children():
		child.queue_free()

	var printer := GameState.printer_by_id(_printer_id)
	if printer.is_empty():
		_summary.add_child(UiKit.caption(I18n.t("printer_busy"), Palette.CORAL_DEEP))
		return

	var model := Config.printer_model(String(printer.get("modelId", "")))
	var material := Config.material(_material_id)
	var duration := int(float(product.get("minutes", 0)) * 60000.0 * float(_qty)
		* float(model.get("speed", 1.0)) * float(material.get("timeFactor", 1.0)))
	var grams := int(ceil(float(product.get("grams", 0)) * float(_qty) * 1.04))
	var available := int(GameState.grams_available(_material_id, _color_id))
	var missing: int = maxi(0, grams - available)

	var card := UiKit.card(12, Palette.SAND if missing == 0 else Color(0.99, 0.90, 0.88))
	var column := UiKit.vbox(6)
	card.add_child(column)
	column.add_child(_row("clock", Palette.SKY_DEEP, I18n.t("eta"), ServerClock.format_short(duration)))
	column.add_child(_row("spool", Palette.TEAL_DEEP, I18n.t("required"), "%d %s" % [grams, I18n.t("grams")]))
	if missing > 0:
		column.add_child(_row("alert", Palette.CORAL, I18n.t("missing"), "%d %s" % [missing, I18n.t("grams")]))
	_summary.add_child(card)

	if missing > 0:
		var buy := UiKit.button(I18n.t("buy_filament"), "warm", true)
		buy.pressed.connect(func():
			close_sheet()
			Events.navigate.emit("buy_filament"))
		_summary.add_child(buy)
		return

	var start := UiKit.button(I18n.t("start_printing"), "primary", true)
	start.pressed.connect(_start)
	_summary.add_child(start)


func _row(icon_name: String, color: Color, label_text: String, value: String) -> Control:
	var row := UiKit.hbox(8)
	row.add_child(UiKit.icon(icon_name, color, 16.0))
	var name_label := UiKit.label(label_text, UiKit.FONT_SMALL, Palette.INK_SOFT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(UiKit.label(value, UiKit.FONT_SMALL, Palette.INK, true))
	return row


func _start() -> void:
	var ok := await GameState.intent("start_store_job", {
		"printerId": _printer_id,
		"productId": product_id,
		"qty": _qty,
		"materialId": _material_id,
		"colorId": _color_id,
	})
	if ok:
		Audio.play("print_start")
		close_sheet()
		Events.navigate.emit("farm")
