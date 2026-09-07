extends "res://scripts/ui/BottomSheet.gd"
## The printer sheet.
##
## Tapping a station opens this: what the machine is, what it is printing, how
## healthy it is, and what is queued behind. Compact by design — a printer is
## something you glance at and act on, not a settings page.

var printer_id: String = ""
var _progress_bar: ProgressBar
var _remaining_label: Label


func open(next_printer_id: String) -> void:
	printer_id = next_printer_id
	_rebuild()
	GameState.state_changed.connect(_rebuild)


func _rebuild() -> void:
	if not is_instance_valid(self) or _closing:
		return
	var printer := GameState.printer_by_id(printer_id)
	if printer.is_empty():
		close_sheet()
		return

	for child in content().get_children():
		child.queue_free()

	var model := Config.printer_model(String(printer.get("modelId", "")))
	var slot := Val.field_text(printer, "slotId")
	var cell := Iso.parse_slot(slot)
	var tier := Config.workshop_tier(GameState.tier_index())
	var station_name := Iso.slot_label(cell.x, cell.y, int(tier.get("cols", 2))) if cell.x >= 0 else ""

	add_header(
		"%s %s" % [String(model.get("brand", "")), String(model.get("name", "Printer"))],
		station_name
	)

	content().add_child(_status_section(printer))
	content().add_child(_health_section(printer))
	content().add_child(_queue_section(printer))
	content().add_child(_actions_section(printer))


	refit()

## What the machine is doing right now, with the live countdown.
func _status_section(printer: Dictionary) -> Control:
	var status := String(printer.get("status", "idle"))
	var job := GameState.active_job(printer_id)
	var card := UiKit.card()
	var column := UiKit.vbox(10)
	card.add_child(column)

	var head := UiKit.hbox(8)
	head.add_child(UiKit.pill(I18n.t(status), Palette.status(status)))
	head.add_child(UiKit.spacer())
	if status == "printing" and not job.is_empty():
		_remaining_label = UiKit.label("", UiKit.FONT_SMALL, Palette.INK_SOFT)
		head.add_child(_remaining_label)
	column.add_child(head)

	if job.is_empty():
		column.add_child(UiKit.caption(
			I18n.t("no_orders_hint") if status == "idle" else I18n.t(status)
		))
		return card

	var product := Config.product(String(job.get("productId", "")))
	var row := UiKit.hbox(10)
	var thumb := ProductThumb.new(
		String(product.get("icon", "dino")), Palette.filament(String(job.get("colorId", "green")))
	)
	thumb.custom_minimum_size = Vector2(44, 44)
	row.add_child(thumb)

	var info := UiKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var qty := int(job.get("qty", 1))
	var name_text: String = String(product.get("name", "Part"))
	if qty > 1:
		name_text += " ×%d" % qty
	info.add_child(UiKit.label(name_text, UiKit.FONT_BODY, Palette.INK, true))
	var material := Config.material(String(job.get("materialId", "")))
	var color := Config.color(String(job.get("colorId", "")))
	info.add_child(UiKit.caption("%s · %s · %s %s" % [
		String(material.get("name", "")), String(color.get("name", "")),
		I18n.number(int(job.get("grams", 0))), I18n.t("grams")
	]))
	row.add_child(info)
	column.add_child(row)

	if status == "printing":
		var progress := ServerClock.progress(Val.field_int(job, "startedAt", 0), int(job.get("durationMs", 0)))
		_progress_bar = UiKit.bar(progress, Palette.SKY_DEEP, 10.0)
		column.add_child(_progress_bar)
		var pct := UiKit.caption("%d%%" % int(progress * 100.0))
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		column.add_child(pct)
	elif status == "failed":
		var kind := String(job.get("failure", "spaghetti"))
		var alert := UiKit.hbox(8)
		alert.add_child(UiKit.icon("alert", Palette.CORAL, 20.0))
		alert.add_child(UiKit.label(_failure_text(kind), UiKit.FONT_SMALL, Palette.CORAL_DEEP))
		column.add_child(alert)

	return card


func _failure_text(kind: String) -> String:
	match kind:
		"spaghetti": return "Spaghetti — the part came loose mid-print"
		"first_layer": return "First layer did not stick"
		"clogged_nozzle": return "Nozzle clogged"
		"filament_runout": return "Filament ran out"
		"ams_jam": return "AMS jam"
		"part_detached": return "Part detached from the plate"
		_: return "Mechanical fault"


## Health, and only the detail that matters: the band it is in and the hours.
func _health_section(printer: Dictionary) -> Control:
	var health := float(printer.get("health", 100.0))
	var thresholds := Config.health_thresholds()
	var color := Palette.GREEN_DEEP
	if health <= float(thresholds.get("critical", 20)):
		color = Palette.CORAL
	elif health <= float(thresholds.get("warning", 40)):
		color = Palette.ORANGE
	elif health <= float(thresholds.get("service", 70)):
		color = Palette.YELLOW_DEEP

	var card := UiKit.card()
	var column := UiKit.vbox(8)
	card.add_child(column)

	var row := UiKit.hbox(8)
	row.add_child(UiKit.icon("wrench", color, 18.0))
	row.add_child(UiKit.label(I18n.t("health"), UiKit.FONT_SMALL, Palette.INK_SOFT))
	row.add_child(UiKit.spacer())
	row.add_child(UiKit.label("%d%%" % int(health), UiKit.FONT_BODY, color, true))
	column.add_child(row)
	column.add_child(UiKit.bar(health / 100.0, color, 8.0))

	var model := Config.printer_model(String(printer.get("modelId", "")))
	column.add_child(UiKit.caption("%.0f %s · %d %s" % [
		float(printer.get("hours", 0.0)), I18n.t("hours"),
		int(printer.get("prints", 0)), I18n.t("printers").to_lower()
	], Palette.INK_FAINT))
	return card


## The queue, in order, with the head marked as the one running now.
func _queue_section(printer: Dictionary) -> Control:
	var jobs := GameState.queued_jobs(printer_id)
	var card := UiKit.card()
	var column := UiKit.vbox(8)
	card.add_child(column)
	column.add_child(UiKit.label(I18n.t("queue"), UiKit.FONT_SMALL, Palette.INK_SOFT, true))

	if jobs.is_empty():
		column.add_child(UiKit.caption(I18n.t("idle"), Palette.INK_FAINT))
		return card

	for i in jobs.size():
		var job: Dictionary = jobs[i]
		var product := Config.product(String(job.get("productId", "")))
		var row := UiKit.hbox(8)
		row.add_child(UiKit.pill(
			I18n.t("printing") if i == 0 else "%d" % (i + 1),
			Palette.SKY_DEEP if i == 0 else Palette.SAND,
			Palette.PAPER if i == 0 else Palette.INK_SOFT
		))
		var name_label := UiKit.label(
			"%s ×%d" % [String(product.get("name", "Part")), int(job.get("qty", 1))],
			UiKit.FONT_SMALL, Palette.INK
		)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(UiKit.caption(ServerClock.format_short(int(job.get("durationMs", 0)))))

		# Anything not already running can be pulled back out of the queue.
		if i > 0 or String(job.get("status", "")) == "queued":
			var remove := Button.new()
			remove.custom_minimum_size = Vector2(30, 30)
			remove.focus_mode = Control.FOCUS_NONE
			remove.add_theme_stylebox_override("normal", UiKit.flat(Palette.SAND, 15.0))
			var glyph := UiKit.icon("close", Palette.INK_FAINT, 13.0)
			glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
			remove.add_child(glyph)
			var job_id := String(job.get("id", ""))
			remove.pressed.connect(func(): _send("cancel_job", {"jobId": job_id}))
			row.add_child(remove)
		column.add_child(row)
	return card


func _actions_section(printer: Dictionary) -> Control:
	var status := String(printer.get("status", "idle"))
	var column := UiKit.vbox(8)

	if status == "failed":
		var clear := UiKit.button(I18n.t("clear"), "warm", true)
		clear.pressed.connect(func(): _send("clear_failure", {"printerId": printer_id}))
		column.add_child(clear)

	var row := UiKit.hbox(8)
	if Config.has_feature(GameState.level(), "maintenance"):
		var service := UiKit.button(I18n.t("service"), "secondary", true)
		service.disabled = status == "printing" or status == "maintenance"
		service.pressed.connect(func(): _open_service(printer))
		row.add_child(service)

	var print_more := UiKit.button(I18n.t("print_more"), "primary", true)
	print_more.disabled = status == "failed" or status == "maintenance"
	print_more.pressed.connect(func():
		close_sheet()
		Events.navigate.emit("shop"))
	row.add_child(print_more)
	column.add_child(row)

	if Config.has_feature(GameState.level(), "upgrades"):
		var upgrades := UiKit.button(I18n.t("upgrades"), "ghost", true)
		upgrades.pressed.connect(func():
			close_sheet()
			Events.navigate.emit("upgrades"))
		column.add_child(upgrades)
	return column


## Servicing swaps the sheet's body for the bench's action list, rather than
## stacking a second modal on top of the first.
func _open_service(printer: Dictionary) -> void:
	for child in content().get_children():
		child.queue_free()
	add_header(I18n.t("service"), I18n.t("health"))

	var health := float(printer.get("health", 100.0))
	content().add_child(UiKit.bar(health / 100.0, Palette.ORANGE, 8.0))

	for action in Config.maintenance_actions():
		if GameState.level() < int(action.get("minLevel", 1)):
			continue
		var card := UiKit.card(12)
		var row := UiKit.hbox(10)
		card.add_child(row)

		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiKit.label(String(action.get("name", "")), UiKit.FONT_BODY, Palette.INK, true))
		var detail := "+%d%% · %s" % [
			int(action.get("restores", 0)),
			ServerClock.format_short(int(action.get("durationMs", 0)))
		]
		var part_id := String(action.get("partId", ""))
		if part_id != "":
			var owned := int(GameState.parts().get(part_id, 0))
			detail += " · %s ×%d" % [_part_name(part_id), owned]
		info.add_child(UiKit.caption(detail))
		row.add_child(info)

		var cost := int(action.get("cost", 0))
		var buy := UiKit.button(I18n.number(cost), "secondary")
		buy.custom_minimum_size = Vector2(88, 40)
		buy.disabled = GameState.coins() < cost or (part_id != "" and int(GameState.parts().get(part_id, 0)) < 1)
		var action_id := String(action.get("id", ""))
		buy.pressed.connect(func(): _send("service_printer", {"printerId": printer_id, "actionId": action_id}))
		row.add_child(buy)
		content().add_child(card)

	var back := UiKit.button(I18n.t("close"), "ghost", true)
	back.pressed.connect(_rebuild)
	content().add_child(back)


func _part_name(part_id: String) -> String:
	for part in Config.all_parts():
		if String(part.get("id", "")) == part_id:
			return String(part.get("name", part_id))
	return part_id


func _send(intent: String, payload: Dictionary) -> void:
	var ok := await GameState.intent(intent, payload)
	if ok:
		if intent == "service_printer":
			Audio.play("purchase")
		elif intent == "clear_failure":
			Audio.play("tap")


## Called once a second by Main so the countdown ticks without a full rebuild.
func tick() -> void:
	var job := GameState.active_job(printer_id)
	if job.is_empty():
		return
	var started := Val.field_int(job, "startedAt", 0)
	var duration := int(job.get("durationMs", 0))
	if _progress_bar != null and is_instance_valid(_progress_bar):
		_progress_bar.value = ServerClock.progress(started, duration)
	if _remaining_label != null and is_instance_valid(_remaining_label):
		_remaining_label.text = "%s %s" % [
			I18n.t("remaining"), ServerClock.format_duration(ServerClock.remaining(started + duration))
		]
