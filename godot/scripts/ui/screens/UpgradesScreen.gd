extends MarginContainer
## Upgrades.
##
## Improvements are bought for a specific machine, which is why the screen
## starts with the fleet: pick a printer, then see what can be fitted to it.
## Nothing here is a single linear track — the categories are independent.

var _column: VBoxContainer
var _selected_printer: String = ""
var _active_tile: Control = null


func _ready() -> void:
	# A container root, so the scroll view is fitted to the screen rect exactly
	# and its contents are forced to the phone's width instead of overflowing.
	var parts := UiKit.screen_scroll()
	_column = parts["column"]
	add_child(parts["scroll"])
	GameState.state_changed.connect(rebuild)
	I18n.language_changed.connect(func(_lang): rebuild())
	rebuild()


## Open the board on a particular machine. The printer sheet uses this, so
## "fit an upgrade to this one" means this one and not whichever the board
## happened to be showing.
func select_printer(next_printer_id: String) -> void:
	if GameState.printer_by_id(next_printer_id).is_empty():
		return
	_selected_printer = next_printer_id
	rebuild()


func rebuild() -> void:
	if _column == null:
		return
	for child in _column.get_children():
		child.queue_free()
	UiKit.apply_direction(self)

	if not Config.has_feature(GameState.level(), "upgrades"):
		_column.add_child(UiKit.empty_state(
			"arrow_up", I18n.t("upgrades"),
			I18n.tf("unlocks_at", [Config.feature_level("upgrades")])
		))
		return

	var printers := GameState.printers()
	if printers.is_empty():
		_column.add_child(UiKit.empty_state("printer", I18n.t("printers"), I18n.t("buy_printer")))
		return

	if _selected_printer == "" or GameState.printer_by_id(_selected_printer).is_empty():
		_selected_printer = String(printers[0].get("id", ""))

	var printer := GameState.printer_by_id(_selected_printer)
	var installed: Array = printer.get("upgrades", [])
	var model := Config.printer_model(String(printer.get("modelId", "")))
	var slots := int(model.get("upgradeSlots", 0))

	_column.add_child(UiKit.section(I18n.t("printers"), printers.size()))
	_column.add_child(_printer_picker(printers))
	_column.add_child(_machine_card(printer, model, installed, slots))
	_column.add_child(UiKit.section(I18n.t("upgrades")))

	# Grouped by category so the screen reads as improving a workshop rather
	# than as one long shopping list.
	var by_category: Dictionary = {}
	for upgrade in Config.all_upgrades():
		var category := String(upgrade.get("category", "printer"))
		if not by_category.has(category):
			by_category[category] = []
		by_category[category].append(upgrade)

	for category in by_category.keys():
		_column.add_child(UiKit.label(
			I18n.t("category_" + category), UiKit.FONT_SMALL, Palette.INK_SOFT, true
		))
		for upgrade in by_category[category]:
			_column.add_child(_upgrade_card(upgrade, installed, slots))


## The machine the screen is currently buying for. Without it the upgrade list
## is a shopping page with no idea what it is fitted to — and the two numbers
## that decide every purchase below, how worn the machine is and how many slots
## are left in it, are not on screen anywhere else.
func _machine_card(
	printer: Dictionary, model: Dictionary, installed: Array, slots: int
) -> Control:
	var health := float(printer.get("health", 100.0))
	var thresholds := Config.health_thresholds()
	var health_color := Palette.GREEN_DEEP
	if health <= float(thresholds.get("critical", 20)):
		health_color = Palette.CORAL
	elif health <= float(thresholds.get("warning", 40)):
		health_color = Palette.ORANGE
	elif health <= float(thresholds.get("service", 70)):
		health_color = Palette.YELLOW_DEEP

	var card := UiKit.card(12)
	var column := UiKit.vbox(8)
	card.add_child(column)

	var head := UiKit.hbox(10)
	head.add_child(UiKit.icon("printer", Palette.SKY_DEEP, 24.0))
	var info := UiKit.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The station, then the model. Half a fleet can share a model, so the name
	# alone does not say which machine is about to be paid for.
	var cell := Iso.parse_slot(Val.field_text(printer, "slotId"))
	var tier := Config.workshop_tier(GameState.tier_index())
	var station := Iso.slot_label(cell.x, cell.y, int(tier.get("cols", 2))) if cell.x >= 0 else ""
	info.add_child(UiKit.label("%s %s %s" % [
		station, String(model.get("brand", "")), String(model.get("name", ""))
	], UiKit.FONT_BODY, Palette.INK, true, true))
	info.add_child(UiKit.caption("%.0f %s · %d %s" % [
		float(printer.get("hours", 0.0)), I18n.t("hours"),
		int(printer.get("prints", 0)), I18n.t("prints_made")
	]))
	head.add_child(info)
	var status := String(printer.get("status", "idle"))
	head.add_child(UiKit.pill(I18n.t(status), Palette.status(status)))
	column.add_child(head)

	var health_row := UiKit.hbox(8)
	health_row.add_child(UiKit.caption(I18n.t("health"), Palette.INK_FAINT))
	health_row.add_child(UiKit.spacer())
	health_row.add_child(UiKit.label("%d%%" % int(health), UiKit.FONT_SMALL, health_color, true))
	column.add_child(health_row)
	column.add_child(UiKit.bar(health / 100.0, health_color, 7.0))

	var slots_row := UiKit.hbox(8)
	slots_row.add_child(UiKit.caption(
		I18n.tf("slots_used", [installed.size(), slots]),
		Palette.CORAL_DEEP if installed.size() >= slots else Palette.INK_SOFT
	))
	slots_row.add_child(UiKit.spacer())
	column.add_child(slots_row)
	return card


## A horizontal strip of the fleet — the current selection is highlighted.
func _printer_picker(printers: Array) -> Control:
	var strip := UiKit.strip(76.0, 8)
	var row: HBoxContainer = strip["row"]
	_active_tile = null

	var tier := Config.workshop_tier(GameState.tier_index())
	for printer in printers:
		var printer_id := String(printer.get("id", ""))
		var model := Config.printer_model(String(printer.get("modelId", "")))
		var cell := Iso.parse_slot(Val.field_text(printer, "slotId"))
		var station := Iso.slot_label(cell.x, cell.y, int(tier.get("cols", 2))) if cell.x >= 0 else "—"
		var active: bool = printer_id == _selected_printer

		var button := Button.new()
		# Narrow enough that a fourth tile shows at the edge of a 390 px phone,
		# which is what tells the player the fleet keeps going past the screen.
		button.custom_minimum_size = Vector2(96, 64)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_stylebox_override("normal", UiKit.flat(
			Palette.SKY_SOFT if active else Palette.PAPER, 14.0,
			Palette.SKY_DEEP if active else Palette.LINE, 2
		))
		var column := UiKit.vbox(2)
		column.set_anchors_preset(Control.PRESET_FULL_RECT)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(column)
		var station_label := UiKit.label(station, UiKit.FONT_BODY, Palette.INK, true)
		station_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(station_label)
		var model_label := UiKit.label(String(model.get("name", "")), UiKit.FONT_CAPTION, Palette.INK_SOFT)
		model_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(model_label)

		button.pressed.connect(func():
			Audio.play("tap")
			_selected_printer = printer_id
			rebuild())
		row.add_child(button)
		if active:
			_active_tile = button
	# Bring the selection into view. On a sixteen-machine fleet the strip
	# opened on the first three tiles, so a board deep-linked from a printer
	# sheet showed no highlighted tile at all.
	var scroll: ScrollContainer = strip["scroll"]
	if _active_tile != null:
		scroll.ready.connect(func():
			if is_instance_valid(_active_tile):
				scroll.ensure_control_visible(_active_tile), CONNECT_ONE_SHOT)
	return scroll


func _upgrade_card(upgrade: Dictionary, installed: Array, slots: int) -> Control:
	var upgrade_id := String(upgrade.get("id", ""))
	var is_installed: bool = installed.has(upgrade_id)
	var locked: bool = GameState.level() < int(upgrade.get("unlockLevel", 1))
	var full: bool = installed.size() >= slots

	var card := UiKit.card(12, Palette.SKY_SOFT if is_installed else Palette.PAPER)
	var column := UiKit.vbox(8)
	card.add_child(column)

	var row := UiKit.hbox(10)
	column.add_child(row)
	row.add_child(UiKit.icon("gear", Palette.TEAL_DEEP if is_installed else Palette.SKY_DEEP, 22.0))
	var info := UiKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label(I18n.name_of("upgrade", upgrade), UiKit.FONT_BODY, Palette.INK, true))
	var description := UiKit.caption(I18n.desc_of("upgrade", upgrade))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(description)
	row.add_child(info)

	if is_installed:
		row.add_child(UiKit.pill(I18n.t("installed"), Palette.TEAL))
	elif locked:
		row.add_child(UiKit.pill(
			I18n.tf("unlocks_at", [int(upgrade.get("unlockLevel", 1))]), Palette.SAND, Palette.INK_SOFT
		))
	else:
		var price := int(upgrade.get("price", 0))
		var buy := UiKit.cost_button(price)
		buy.disabled = GameState.coins() < price or full
		buy.pressed.connect(func():
			if await GameState.intent("buy_upgrade", {
				"printerId": _selected_printer, "upgradeId": upgrade_id
			}):
				Audio.play("purchase")
				Events.toast.emit(I18n.t("installed"), "success"))
		row.add_child(buy)

	# What the upgrade actually does, from its own effects. A description says
	# a nozzle "survives abrasive filaments"; this says by how much, which is
	# what a second machine's worth of coins is being weighed against.
	var effects := _effect_chips(upgrade.get("effects", {}))
	if not effects.is_empty():
		var chips := UiKit.hbox(6)
		for chip in effects:
			chips.add_child(chip)
		chips.add_child(UiKit.spacer())
		column.add_child(chips)

	if not is_installed and not locked and full:
		column.add_child(UiKit.caption(I18n.t("no_slots_left"), Palette.CORAL_DEEP))
	return card


## The effects table turned into chips. Most are proportions where less is
## better — fewer failures, less wear, less waste, less time — so the sign is
## read against what the field means rather than against zero.
const EFFECTS := {
	"failure": {"key": "effect_failure", "percent": true, "less_is_better": true},
	"healthDecay": {"key": "effect_wear", "percent": true, "less_is_better": true},
	"materialWaste": {"key": "effect_waste", "percent": true, "less_is_better": true},
	"speed": {"key": "effect_speed", "percent": true, "less_is_better": true},
	"quality": {"key": "effect_quality", "percent": false, "less_is_better": false},
	"queueCapacity": {"key": "effect_queue", "percent": false, "less_is_better": false},
}


func _effect_chips(effects: Dictionary) -> Array:
	var out: Array = []
	for field in EFFECTS.keys():
		if not effects.has(field):
			continue
		var value := float(effects[field])
		if is_zero_approx(value):
			continue
		var spec: Dictionary = EFFECTS[field]
		var good: bool = (value < 0.0) == bool(spec["less_is_better"])
		var color: Color = Palette.GREEN_DEEP if good else Palette.ORANGE_DEEP
		var text := (
			"%+d%% %s" % [int(round(value * 100.0)), I18n.t(String(spec["key"]))]
			if bool(spec["percent"])
			else "%+d %s" % [int(round(value)), I18n.t(String(spec["key"]))]
		)
		out.append(UiKit.pill(text, Color(color.r, color.g, color.b, 0.14), color))
	return out
