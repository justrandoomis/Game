extends MarginContainer
## Upgrades.
##
## Improvements are bought for a specific machine, which is why the screen
## starts with the fleet: pick a printer, then see what can be fitted to it.
## Nothing here is a single linear track — the categories are independent.

var _column: VBoxContainer
var _selected_printer: String = ""


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

	_column.add_child(UiKit.title(I18n.t("printers")))
	_column.add_child(_printer_picker(printers))
	_column.add_child(UiKit.vspace(4.0))
	_column.add_child(UiKit.title(I18n.t("upgrades")))

	var printer := GameState.printer_by_id(_selected_printer)
	var installed: Array = printer.get("upgrades", [])
	var model := Config.printer_model(String(printer.get("modelId", "")))
	var slots := int(model.get("upgradeSlots", 0))
	_column.add_child(UiKit.caption("%d / %d %s" % [installed.size(), slots, I18n.t("install")]))

	# Grouped by category so the screen reads as improving a workshop rather
	# than as one long shopping list.
	var by_category: Dictionary = {}
	for upgrade in Config.all_upgrades():
		var category := String(upgrade.get("category", "printer"))
		if not by_category.has(category):
			by_category[category] = []
		by_category[category].append(upgrade)

	for category in by_category.keys():
		_column.add_child(UiKit.label(category.capitalize(), UiKit.FONT_SMALL, Palette.INK_SOFT, true))
		for upgrade in by_category[category]:
			_column.add_child(_upgrade_card(upgrade, installed, slots))


## A horizontal strip of the fleet — the current selection is highlighted.
func _printer_picker(printers: Array) -> Control:
	var strip := UiKit.strip(76.0, 8)
	var row: HBoxContainer = strip["row"]

	var tier := Config.workshop_tier(GameState.tier_index())
	for printer in printers:
		var printer_id := String(printer.get("id", ""))
		var model := Config.printer_model(String(printer.get("modelId", "")))
		var cell := Iso.parse_slot(Val.field_text(printer, "slotId"))
		var station := Iso.slot_label(cell.x, cell.y, int(tier.get("cols", 2))) if cell.x >= 0 else "—"
		var active: bool = printer_id == _selected_printer

		var button := Button.new()
		button.custom_minimum_size = Vector2(112, 64)
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
	return strip["scroll"]


func _upgrade_card(upgrade: Dictionary, installed: Array, slots: int) -> Control:
	var upgrade_id := String(upgrade.get("id", ""))
	var is_installed: bool = installed.has(upgrade_id)
	var locked: bool = GameState.level() < int(upgrade.get("unlockLevel", 1))

	var card := UiKit.card(12, Palette.PAPER if not is_installed else Palette.SKY_SOFT)
	var row := UiKit.hbox(10)
	card.add_child(row)

	row.add_child(UiKit.icon("gear", Palette.SKY_DEEP if not is_installed else Palette.TEAL_DEEP, 24.0))
	var info := UiKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label(String(upgrade.get("name", "")), UiKit.FONT_BODY, Palette.INK, true))
	var description := UiKit.caption(String(upgrade.get("description", "")))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(description)
	row.add_child(info)

	if is_installed:
		row.add_child(UiKit.pill(I18n.t("installed"), Palette.TEAL))
		return card

	var price := int(upgrade.get("price", 0))
	var buy := UiKit.button(
		I18n.tf("unlocks_at", [int(upgrade.get("unlockLevel", 1))]) if locked else I18n.number(price),
		"secondary"
	)
	buy.custom_minimum_size = Vector2(92, 40)
	buy.disabled = locked or GameState.coins() < price or installed.size() >= slots
	buy.pressed.connect(func():
		if await GameState.intent("buy_upgrade", {"printerId": _selected_printer, "upgradeId": upgrade_id}):
			Audio.play("purchase")
			Events.toast.emit(I18n.t("installed"), "success"))
	row.add_child(buy)
	return card
