extends "res://scripts/ui/BottomSheet.gd"
## "While you were away".
##
## The workshop keeps running when the game is closed — the server resolves it
## from timestamps — so coming back should show what happened. Only lines with
## something in them are listed; an empty report is never shown at all.


func open(report: Dictionary) -> void:
	add_header(I18n.t("while_away"), ServerClock.format_short(int(report.get("elapsedMs", 0))))

	var card := UiKit.card()
	var column := UiKit.vbox(10)
	card.add_child(column)

	var prints := int(report.get("printsCompleted", 0))
	var delivered := int(report.get("ordersDelivered", 0))
	var coins := int(report.get("coinsEarned", 0))
	var sales := int(report.get("storeSales", 0))
	var failures := int(report.get("printsFailed", 0))
	var service := int(report.get("maintenanceNeeded", 0))

	if prints > 0:
		column.add_child(_line("printer", Palette.TEAL_DEEP, prints, I18n.t("prints_done")))
	if delivered > 0:
		column.add_child(_line("clipboard", Palette.SKY_DEEP, delivered, I18n.t("orders_delivered")))
	if sales > 0:
		column.add_child(_line("store", Palette.CORAL, sales, I18n.t("stock")))
	if coins > 0:
		column.add_child(_line("coin", Palette.YELLOW_DEEP, coins, I18n.t("coins_earned")))
	if failures > 0:
		column.add_child(_line("alert", Palette.CORAL, failures, I18n.t("failed")))
	if service > 0:
		column.add_child(_line("wrench", Palette.ORANGE, service, I18n.t("needs_service")))

	content().add_child(card)

	var confirm := UiKit.button(I18n.t("close"), "primary", true)
	confirm.pressed.connect(close_sheet)
	content().add_child(confirm)
	refit()


func _line(icon_name: String, color: Color, value: int, text: String) -> Control:
	var row := UiKit.hbox(10)
	row.add_child(UiKit.icon(icon_name, color, 22.0))
	row.add_child(UiKit.label(I18n.number(value), UiKit.FONT_TITLE, Palette.INK, true))
	var label := UiKit.label(text, UiKit.FONT_SMALL, Palette.INK_SOFT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row
