extends "res://scripts/ui/BottomSheet.gd"
## Putting an order into production.
##
## The player picks machines; the game does the arithmetic. Selecting printers
## shows the split, the filament it will consume and when the whole order will
## be finished — before anything is committed. If there is not enough filament
## it says exactly how much is missing and offers to buy it.

var order_id: String = ""
var _selected: Dictionary = {}
var _summary: VBoxContainer
var _confirm: Button


func open(next_order_id: String) -> void:
	order_id = next_order_id
	var order := GameState.order_by_id(order_id)
	if order.is_empty():
		close_sheet()
		return
	_rebuild()


func _rebuild() -> void:
	if not is_instance_valid(self) or _closing:
		return
	for child in content().get_children():
		child.queue_free()

	var order := GameState.order_by_id(order_id)
	if order.is_empty():
		close_sheet()
		return

	var product := Config.product(String(order.get("productId", "")))
	add_header(I18n.t("assign"), "%s ×%d" % [I18n.name_of("product", product), int(order.get("qty", 1))])

	var eligible := _eligible_printers(order)
	if eligible.is_empty():
		content().add_child(UiKit.empty_state(
			"printer", I18n.t("printers"), I18n.t("printer_busy")
		))
		return

	# Default to every free machine — the common case is "just print it".
	if _selected.is_empty():
		for printer in eligible:
			if String(printer.get("status", "")) == "idle":
				_selected[String(printer.get("id", ""))] = true
		if _selected.is_empty():
			_selected[String(eligible[0].get("id", ""))] = true

	for printer in eligible:
		content().add_child(_printer_row(printer, order))

	_summary = UiKit.vbox(8)
	content().add_child(_summary)

	_confirm = UiKit.button(I18n.t("start_printing"), "primary", true)
	_confirm.pressed.connect(_start)
	content().add_child(_confirm)
	_refresh_summary(order)


	refit()

## Machines that can take this job: right material, right capability, free slot
## in the queue. Mirrors eligiblePrinters() on the server.
func _eligible_printers(order: Dictionary) -> Array:
	var product := Config.product(String(order.get("productId", "")))
	return GameState.printers().filter(func(printer):
		var status := String(printer.get("status", ""))
		if status in ["failed", "maintenance", "offline"]:
			return false
		var model := Config.printer_model(String(printer.get("modelId", "")))
		var materials: Array = model.get("materials", [])
		if not materials.has(String(order.get("materialId", ""))):
			return false
		if bool(product.get("multicolor", false)) and not bool(model.get("multicolor", false)):
			return false
		var queue: Array = printer.get("queue", [])
		return queue.size() < int(model.get("queueCapacity", 3)))


func _printer_row(printer: Dictionary, order: Dictionary) -> Control:
	var printer_id := String(printer.get("id", ""))
	var model := Config.printer_model(String(printer.get("modelId", "")))
	var cell := Iso.parse_slot(Val.field_text(printer, "slotId"))
	var tier := Config.workshop_tier(GameState.tier_index())
	var station := Iso.slot_label(cell.x, cell.y, int(tier.get("cols", 2))) if cell.x >= 0 else "—"
	var chosen: bool = _selected.get(printer_id, false)

	var card := UiKit.card(12, Palette.PAPER if not chosen else Palette.SKY_SOFT)
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_stylebox_override("normal", UiKit.flat(Color(1, 1, 1, 0), 0.0))
	button.add_theme_stylebox_override("hover", UiKit.flat(Color(1, 1, 1, 0), 0.0))
	button.add_theme_stylebox_override("pressed", UiKit.flat(Color(1, 1, 1, 0), 0.0))
	card.add_child(button)

	var row := UiKit.hbox(10)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)

	var check := Panel.new()
	check.custom_minimum_size = Vector2(22, 22)
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	check.add_theme_stylebox_override("panel", UiKit.flat(
		Palette.TEAL if chosen else Palette.PAPER, 7.0, Palette.LINE, 2
	))
	if chosen:
		var tick_glyph := UiKit.icon("check", Palette.PAPER, 14.0)
		tick_glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
		check.add_child(tick_glyph)
	row.add_child(check)

	var info := UiKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label("%s · %s" % [station, String(model.get("name", ""))],
		UiKit.FONT_BODY, Palette.INK, true))
	var queue: Array = printer.get("queue", [])
	var status := String(printer.get("status", "idle"))
	info.add_child(UiKit.caption("%s · %s %d" % [I18n.t(status), I18n.t("queue"), queue.size()]))
	row.add_child(info)

	button.pressed.connect(func():
		Audio.play("tap")
		_selected[printer_id] = not _selected.get(printer_id, false)
		_rebuild())
	return card


## The split, worked out the same way the server does it: work is shared out in
## proportion to each machine's speed, so the parts finish together.
func _plan(order: Dictionary) -> Array:
	var chosen: Array = GameState.printers().filter(
		func(p): return _selected.get(String(p.get("id", "")), false)
	)
	if chosen.is_empty():
		return []

	var product := Config.product(String(order.get("productId", "")))
	var material := Config.material(String(order.get("materialId", "")))
	var qty := int(order.get("qty", 1))

	var rates: Array = []
	for printer in chosen:
		var model := Config.printer_model(String(printer.get("modelId", "")))
		var unit_ms: float = float(product.get("minutes", 1)) * 60000.0 \
			* Config.effective_speed(printer) * float(material.get("timeFactor", 1.0))
		rates.append(0.0 if unit_ms <= 0.0 else 1.0 / unit_ms)

	var total_rate: float = 0.0
	for rate in rates:
		total_rate += rate
	if total_rate <= 0.0:
		return []

	var raw: Array = []
	var quantities: Array = []
	var assigned := 0
	for i in chosen.size():
		var share: float = (rates[i] / total_rate) * float(qty)
		raw.append(share)
		quantities.append(int(floor(share)))
		assigned += int(floor(share))

	# The rounding remainder goes to whoever was closest to another whole unit.
	var order_by_fraction: Array = []
	for i in raw.size():
		order_by_fraction.append({"i": i, "frac": float(raw[i]) - floor(float(raw[i]))})
	order_by_fraction.sort_custom(func(a, b): return a["frac"] > b["frac"])
	var k := 0
	while assigned < qty and not order_by_fraction.is_empty():
		quantities[order_by_fraction[k % order_by_fraction.size()]["i"]] += 1
		assigned += 1
		k += 1

	var plan: Array = []
	for i in chosen.size():
		if quantities[i] <= 0:
			continue
		var printer: Dictionary = chosen[i]
		var model := Config.printer_model(String(printer.get("modelId", "")))
		var units: int = quantities[i]
		plan.append({
			"printer": printer,
			"qty": units,
			# Speed and purge waste both move with what is fitted to the machine,
			# so a split preview that used the bare model numbers quoted a time
			# and a weight the server would not agree with.
			"durationMs": int(float(product.get("minutes", 1)) * 60000.0 * float(units)
				* Config.effective_speed(printer) * float(material.get("timeFactor", 1.0))),
			"grams": int(ceil(
				float(product.get("grams", 0)) * float(units)
				* (1.0 + Config.material_waste(printer))
			)),
		})
	return plan


func _refresh_summary(order: Dictionary) -> void:
	for child in _summary.get_children():
		child.queue_free()

	var plan := _plan(order)
	if plan.is_empty():
		_confirm.disabled = true
		_summary.add_child(UiKit.caption(I18n.t("assign"), Palette.INK_FAINT))
		return

	var tier := Config.workshop_tier(GameState.tier_index())
	var eta := 0
	var grams := 0
	var split := UiKit.vbox(4)
	for entry in plan:
		var cell := Iso.parse_slot(Val.field_text(entry["printer"], "slotId"))
		var station := Iso.slot_label(cell.x, cell.y, int(tier.get("cols", 2))) if cell.x >= 0 else "—"
		var row := UiKit.hbox(8)
		row.add_child(UiKit.pill(station, Palette.SKY_DEEP))
		var text := UiKit.label("×%d" % int(entry["qty"]), UiKit.FONT_SMALL, Palette.INK)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var waiting := GameState.queue_ms(String(entry["printer"].get("id", "")))
		row.add_child(UiKit.caption(ServerClock.format_short(int(entry["durationMs"]) + waiting)))
		split.add_child(row)
		# The order is done when the slowest leg is — including the work each
		# machine has to get through before it starts this one.
		eta = maxi(eta, int(entry["durationMs"]) + waiting)
		grams += int(entry["grams"])
	_summary.add_child(split)

	var material_id := String(order.get("materialId", ""))
	var color_id := String(order.get("colorId", ""))
	var available := GameState.grams_available(material_id, color_id)
	# Each leg is loaded from one spool, so the binding constraint is the
	# biggest leg against the fullest spool rather than the total on the rack —
	# which is what the server reserves against, and used to disagree.
	var biggest := 0
	for entry in plan:
		biggest = maxi(biggest, int(entry["grams"]))
	var fullest := int(GameState.largest_spool(material_id, color_id))
	var missing: int = maxi(maxi(0, grams - int(available)), maxi(0, biggest - fullest))

	var card := UiKit.card(12, Palette.SAND if missing == 0 else Color(0.99, 0.90, 0.88))
	var column := UiKit.vbox(6)
	card.add_child(column)
	column.add_child(_summary_row("clock", Palette.SKY_DEEP, I18n.t("eta"), ServerClock.format_short(eta)))
	column.add_child(_summary_row("spool", Palette.TEAL_DEEP, I18n.t("required"),
		"%d %s" % [grams, I18n.t("grams")]))
	column.add_child(_summary_row("box", Palette.INK_SOFT, I18n.t("available"),
		"%d %s" % [int(available), I18n.t("grams")]))
	if missing > 0:
		column.add_child(_summary_row("alert", Palette.CORAL, I18n.t("missing"),
			"%d %s" % [missing, I18n.t("grams")]))
	_summary.add_child(card)

	if missing > 0:
		if int(available) >= grams:
			# Enough filament, just not on one spool — buying more will not fix
			# it, so say what the problem actually is.
			var note := UiKit.caption(I18n.t("one_spool_only"), Palette.CORAL_DEEP)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			column.add_child(note)
		else:
			var buy := UiKit.button(I18n.t("buy_filament"), "warm", true)
			buy.pressed.connect(func():
				close_sheet()
				Events.navigate.emit("buy_filament:%s:%s" % [material_id, color_id]))
			_summary.add_child(buy)
	_confirm.disabled = missing > 0


func _summary_row(icon_name: String, color: Color, label_text: String, value: String) -> Control:
	var row := UiKit.hbox(8)
	row.add_child(UiKit.icon(icon_name, color, 16.0))
	var name_label := UiKit.label(label_text, UiKit.FONT_SMALL, Palette.INK_SOFT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(UiKit.label(value, UiKit.FONT_SMALL, Palette.INK, true))
	return row


## Only the chosen machines are sent. The server re-derives the split itself —
## the client's preview is a preview, never the instruction.
func _start() -> void:
	var printer_ids: Array = []
	for printer_id in _selected.keys():
		if _selected[printer_id]:
			printer_ids.append(printer_id)
	if printer_ids.is_empty():
		return
	var ok := await GameState.intent("assign_order", {"orderId": order_id, "printerIds": printer_ids})
	if ok:
		Audio.play("print_start")
		Events.toast.emit(I18n.t("start_printing"), "success")
		close_sheet()
		Events.navigate.emit("farm")
