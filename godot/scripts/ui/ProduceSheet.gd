extends "res://scripts/ui/BottomSheet.gd"
## Producing stock for the store.
##
## The same shape as assigning a customer order — pick a machine, pick the
## filament, pick how many — so the two production paths feel like one system.
##
## Everything the sheet opens on has to be something the server would accept.
## It used to open on white filament and the first machine in the list, so on a
## rack with no white — including the green-only rack every player starts
## with — the first thing a new player saw was "Missing 9 g" on a full spool,
## and a Start button that the server refused.

var product_id: String = ""
var _printer_id: String = ""
var _material_id: String = ""
var _color_id: String = ""
var _qty: int = 1
var _summary: VBoxContainer


func open(next_product_id: String) -> void:
	product_id = next_product_id
	_choose_material()
	_choose_color()
	_choose_printer()
	_rebuild()


## The first material this product takes that the player has reached. Falls
## back to the first listed so the sheet still explains itself when none is
## unlocked yet.
func _choose_material() -> void:
	var product := Config.product(product_id)
	var materials: Array = product.get("materials", [])
	if materials.is_empty():
		return
	for material_id in materials:
		if GameState.level() >= int(Config.material(String(material_id)).get("unlockLevel", 1)):
			_material_id = String(material_id)
			return
	_material_id = String(materials[0])


## The colour there is most of. The picker only draws colours the player owns,
## so anything else leaves no swatch ringed and a stock check against nothing.
func _choose_color() -> void:
	var best := ""
	var most := 0.0
	for entry in Config.all_colors():
		var color_id := String(entry.get("id", ""))
		var grams := GameState.largest_spool(_material_id, color_id)
		if grams > most:
			most = grams
			best = color_id
	_color_id = best


## The first machine that could actually take this job. Never a disabled one:
## the picker greys out machines that cannot print the material, and leaving
## the selection on one of those left Start live over a refusal.
func _choose_printer() -> void:
	var product := Config.product(product_id)
	var fallback := ""
	for printer in GameState.printers():
		if not _supports(printer, product):
			continue
		if fallback == "":
			fallback = String(printer.get("id", ""))
		if String(printer.get("status", "idle")) == "idle":
			_printer_id = String(printer.get("id", ""))
			return
	_printer_id = fallback


## The same test the picker draws with, and the same one the server applies:
## right material, right colour capability, and a machine that can take work.
func _supports(printer: Dictionary, product: Dictionary) -> bool:
	var model := Config.printer_model(String(printer.get("modelId", "")))
	if not Array(model.get("materials", [])).has(_material_id):
		return false
	if bool(product.get("multicolor", false)) and not bool(model.get("multicolor", false)):
		return false
	return not String(printer.get("status", "idle")) in ["failed", "maintenance"]


func _rebuild() -> void:
	if not is_instance_valid(self) or _closing:
		return
	for child in content().get_children():
		child.queue_free()

	var product := Config.product(product_id)
	add_header(I18n.t("print_more"), I18n.name_of("product", product))

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
		var supports := _supports(printer, product)
		var cell := Iso.parse_slot(Val.field_text(printer, "slotId"))
		var station := Iso.slot_label(cell.x, cell.y, int(tier.get("cols", 2))) if cell.x >= 0 else "—"
		var active: bool = printer_id == _printer_id

		var button := Button.new()
		button.custom_minimum_size = Vector2(96, 58)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = not supports
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
		# A busy machine can still take the job — it just starts later — so the
		# cell says how deep the queue is rather than only that it is printing.
		var depth: int = GameState.queued_jobs(printer_id).size()
		var caption := I18n.t(status) if depth == 0 else I18n.tf("queue_depth", [depth])
		var status_label := UiKit.label(caption, UiKit.FONT_CAPTION, Palette.INK_SOFT)
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
		var button := UiKit.button(I18n.name_of("material", material), "secondary")
		button.custom_minimum_size = Vector2(76, 40)
		if active:
			button.add_theme_stylebox_override("normal", UiKit.flat(Palette.TEAL, UiKit.RADIUS))
			button.add_theme_color_override("font_color", Palette.PAPER)
		button.pressed.connect(func():
			_material_id = String(material_id)
			# The colour and the machine were chosen for the old material and
			# may both be impossible for the new one.
			_choose_color()
			if not _supports(GameState.printer_by_id(_printer_id), product):
				_choose_printer()
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
	if printer.is_empty() or not _supports(printer, product):
		_summary.add_child(UiKit.caption(I18n.t("no_machine_for_this"), Palette.CORAL_DEEP))
		return
	if _color_id == "":
		_summary.add_child(UiKit.caption(I18n.t("no_filament_yet"), Palette.ORANGE_DEEP))
		_summary.add_child(_buy_button())
		return

	var material := Config.material(_material_id)
	var grams := int(ceil(
		float(product.get("grams", 0)) * float(_qty) * (1.0 + Config.material_waste(printer))
	))
	# The print's own time, plus everything the machine has to get through
	# first. "Ready in" that ignored the queue was the number a player planned
	# around on a farm where every machine is busy.
	var printing := int(float(product.get("minutes", 0)) * 60000.0 * float(_qty)
		* Config.effective_speed(printer) * float(material.get("timeFactor", 1.0)))
	var waiting := GameState.queue_ms(_printer_id)

	# One spool loads one print: what matters is the fullest spool, not the
	# total on the rack. The server refuses on exactly this.
	var best := int(GameState.largest_spool(_material_id, _color_id))
	var missing: int = maxi(0, grams - best)
	var on_hand := int(GameState.grams_available(_material_id, _color_id))

	var card := UiKit.card(12, Palette.SAND if missing == 0 else Color(0.99, 0.90, 0.88))
	var column := UiKit.vbox(6)
	card.add_child(column)
	column.add_child(_row(
		"clock", Palette.SKY_DEEP, I18n.t("eta"), ServerClock.format_short(printing + waiting)
	))
	if waiting > 0:
		column.add_child(_row(
			"printer", Palette.INK_FAINT, I18n.t("after_queue"), ServerClock.format_short(waiting)
		))
	column.add_child(_row(
		"spool", Palette.TEAL_DEEP, I18n.t("required"), "%d %s" % [grams, I18n.t("grams")]
	))
	column.add_child(_row(
		"spool", Palette.INK_FAINT, I18n.t("available"), "%d %s" % [on_hand, I18n.t("grams")]
	))
	if missing > 0:
		column.add_child(_row(
			"alert", Palette.CORAL, I18n.t("missing"), "%d %s" % [missing, I18n.t("grams")]
		))
		# Enough on the rack but not on any one spool is a different problem
		# from not having enough, and it is not solved by buying more.
		if on_hand >= grams:
			var note := UiKit.caption(I18n.t("one_spool_only"), Palette.CORAL_DEEP)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			column.add_child(note)
	_summary.add_child(card)

	if missing > 0:
		if on_hand < grams:
			_summary.add_child(_buy_button())
		return

	var start := UiKit.button(I18n.t("start_printing"), "primary", true)
	start.pressed.connect(_start)
	_summary.add_child(start)


## Straight to the filament the sheet is short of, rather than to whatever the
## buy sheet happens to open on.
func _buy_button() -> Button:
	var buy := UiKit.button(I18n.t("buy_filament"), "warm", true)
	var material_id := _material_id
	var color_id := _color_id
	buy.pressed.connect(func():
		close_sheet()
		Events.navigate.emit("buy_filament:%s:%s" % [material_id, color_id]))
	return buy


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
