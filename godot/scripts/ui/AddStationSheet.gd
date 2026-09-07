extends "res://scripts/ui/BottomSheet.gd"
## Adding to the workshop.
##
## Two things happen here: unlocking the next station on the grid, and putting
## a machine on a station that is already unlocked. Expanding to a bigger
## workshop appears once every station in the current room is filled, so growth
## always reads as "this room is full" rather than an arbitrary upsell.

var slot_id: String = ""


func open(next_slot_id: String) -> void:
	slot_id = next_slot_id
	_rebuild()
	GameState.state_changed.connect(_rebuild)


func _rebuild() -> void:
	if not is_instance_valid(self) or _closing:
		return
	for child in content().get_children():
		child.queue_free()

	var unlocked: Array = GameState.unlocked_slots()
	if unlocked.has(slot_id):
		_build_buy_printer()
	else:
		_build_unlock_slot()


	refit()

## The next station on the grid: what it costs and what it needs.
func _build_unlock_slot() -> void:
	var unlocked: Array = GameState.unlocked_slots()
	var cost := Config.slot_cost(unlocked.size())
	var level_required := Config.slot_level(unlocked.size())
	var tier := Config.workshop_tier(GameState.tier_index())
	var cell := Iso.parse_slot(slot_id)

	add_header(
		I18n.t("unlock_station"),
		Iso.slot_label(cell.x, cell.y, int(tier.get("cols", 2))) if cell.x >= 0 else ""
	)

	var card := UiKit.card()
	var column := UiKit.vbox(10)
	card.add_child(column)
	column.add_child(_stat_row("plus", Palette.TEAL, I18n.t("capacity"), "%d / %d %s" % [
		unlocked.size(), int(tier.get("slots", 0)), I18n.t("stations")
	]))
	column.add_child(_stat_row("arrow_up", Palette.SKY_DEEP, I18n.t("required_level"), str(level_required)))
	column.add_child(_stat_row("coin", Palette.YELLOW_DEEP, I18n.t("cost"), I18n.number(cost)))
	content().add_child(card)

	var blocked := ""
	if GameState.level() < level_required:
		blocked = I18n.t("level_too_low")
	elif GameState.coins() < cost:
		blocked = I18n.t("not_enough_coins")

	var unlock := UiKit.button(
		"%s · %s" % [I18n.t("unlock_station"), I18n.number(cost)], "primary", true
	)
	unlock.disabled = blocked != ""
	unlock.pressed.connect(func(): _send("unlock_slot", {"slotId": slot_id}, "expand"))
	content().add_child(unlock)
	if blocked != "":
		var note := UiKit.caption(blocked, Palette.CORAL_DEEP)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content().add_child(note)

	_maybe_add_expansion()


## The printer catalogue, filtered to what this workshop can actually use.
func _build_buy_printer() -> void:
	var tier := Config.workshop_tier(GameState.tier_index())
	var cell := Iso.parse_slot(slot_id)
	add_header(
		I18n.t("buy_printer"),
		Iso.slot_label(cell.x, cell.y, int(tier.get("cols", 2))) if cell.x >= 0 else ""
	)

	var any := false
	for model in Config.all_printers():
		var unlock_level := int(model.get("unlockLevel", 1))
		# Show the next tier of machine too, so there is something to aim at.
		if unlock_level > GameState.level() + 4:
			continue
		any = true
		content().add_child(_printer_card(model, unlock_level))

	if not any:
		content().add_child(UiKit.empty_state("printer", I18n.t("printers"), I18n.t("level_too_low")))


func _printer_card(model: Dictionary, unlock_level: int) -> Control:
	var card := UiKit.card()
	var column := UiKit.vbox(10)
	card.add_child(column)

	var head := UiKit.hbox(10)
	head.add_child(UiKit.icon("printer", Palette.SKY_DEEP, 28.0))
	var info := UiKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label(
		"%s %s" % [String(model.get("brand", "")), String(model.get("name", ""))],
		UiKit.FONT_BODY, Palette.INK, true
	))
	var build: Array = model.get("build", [0, 0, 0])
	info.add_child(UiKit.caption("%d×%d×%d mm · %s" % [
		int(build[0]), int(build[1]), int(build[2]), String(model.get("family", ""))
	]))
	head.add_child(info)
	if bool(model.get("multicolor", false)):
		head.add_child(UiKit.pill("AMS", Palette.TEAL))
	column.add_child(head)

	# The three stats that decide whether a machine is worth it.
	var stats := UiKit.hbox(12)
	stats.add_child(_mini_stat("bolt", Palette.ORANGE, "%.0f%%" % ((2.0 - float(model.get("speed", 1.0))) * 100.0 * 0.5)))
	stats.add_child(_mini_stat("star", Palette.YELLOW, "%d" % int(model.get("quality", 0))))
	stats.add_child(_mini_stat("wrench", Palette.GREEN_DEEP, "%d" % int(model.get("reliability", 0))))
	stats.add_child(UiKit.spacer())
	column.add_child(stats)

	var materials: Array = model.get("materials", [])
	var chips := UiKit.hbox(4)
	for material_id in materials:
		var material := Config.material(String(material_id))
		chips.add_child(UiKit.pill(String(material.get("name", "")), Palette.SAND, Palette.INK_SOFT))
	column.add_child(chips)

	var price := int(model.get("price", 0))
	var locked := GameState.level() < unlock_level
	var buy := UiKit.button(
		I18n.tf("unlocks_at", [unlock_level]) if locked else "%s · %s" % [I18n.t("buy"), I18n.number(price)],
		"primary", true
	)
	buy.disabled = locked or GameState.coins() < price
	var model_id := String(model.get("id", ""))
	buy.pressed.connect(func(): _send("buy_printer", {"modelId": model_id, "slotId": slot_id}, "purchase"))
	column.add_child(buy)
	return card


## Once the room is full, the only way forward is a bigger room.
func _maybe_add_expansion() -> void:
	var tier_index := GameState.tier_index()
	var tier := Config.workshop_tier(tier_index)
	var next_tier := Config.workshop_tier(tier_index + 1)
	if next_tier.is_empty():
		return
	if GameState.unlocked_slots().size() < int(tier.get("slots", 0)):
		return

	content().add_child(UiKit.vspace(4.0))
	var card := UiKit.card(14, Palette.SKY_SOFT)
	var column := UiKit.vbox(8)
	card.add_child(column)
	column.add_child(UiKit.label(I18n.t("expand_workshop"), UiKit.FONT_BODY, Palette.INK, true))
	column.add_child(UiKit.caption("%s → %s · %d %s" % [
		String(tier.get("name", "")), String(next_tier.get("name", "")),
		int(next_tier.get("slots", 0)), I18n.t("stations")
	]))
	var cost := int(next_tier.get("cost", 0))
	var expand := UiKit.button("%s · %s" % [I18n.t("expand_workshop"), I18n.number(cost)], "warm", true)
	expand.disabled = GameState.coins() < cost or GameState.level() < int(next_tier.get("unlockLevel", 1))
	expand.pressed.connect(func(): _send("expand_workshop", {}, "expand"))
	column.add_child(expand)
	content().add_child(card)


func _stat_row(icon_name: String, color: Color, label_text: String, value: String) -> Control:
	var row := UiKit.hbox(8)
	row.add_child(UiKit.icon(icon_name, color, 18.0))
	var name_label := UiKit.label(label_text, UiKit.FONT_SMALL, Palette.INK_SOFT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(UiKit.label(value, UiKit.FONT_BODY, Palette.INK, true))
	return row


func _mini_stat(icon_name: String, color: Color, value: String) -> Control:
	var row := UiKit.hbox(4)
	row.add_child(UiKit.icon(icon_name, color, 14.0))
	row.add_child(UiKit.label(value, UiKit.FONT_CAPTION, Palette.INK_SOFT))
	return row


func _send(intent: String, payload: Dictionary, cue: String) -> void:
	var ok := await GameState.intent(intent, payload)
	if ok:
		Audio.play(cue)
		if intent == "buy_printer":
			Events.focus_slot.emit(slot_id)
			close_sheet()
		elif intent == "expand_workshop":
			close_sheet()
