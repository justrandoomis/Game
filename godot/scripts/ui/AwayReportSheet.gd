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

	# Every line the server sends, in the order a player wants them: what got
	# done, what it earned, then what went wrong. The report used to drop the
	# expired offers, the missed orders and the level-up entirely, so a player
	# could come back to a farm that had lost reputation overnight and be told
	# only how many prints finished.
	var lines := [
		["printer", Palette.TEAL_DEEP, int(report.get("printsCompleted", 0)), I18n.t("prints_done")],
		["clipboard", Palette.SKY_DEEP, int(report.get("ordersDelivered", 0)), I18n.t("orders_delivered")],
		["store", Palette.CORAL, int(report.get("storeSales", 0)), I18n.t("store_sales")],
		["coin", Palette.YELLOW_DEEP, int(report.get("coinsEarned", 0)), I18n.t("coins_earned")],
		["clipboard", Palette.SKY_DEEP, int(report.get("newOrders", 0)), I18n.t("new_offers")],
		["alert", Palette.ORANGE, int(report.get("printsFailed", 0)), I18n.t("prints_failed_away")],
		["alert", Palette.CORAL, int(report.get("ordersFailed", 0)), I18n.t("orders_missed")],
		["clock", Palette.INK_FAINT, int(report.get("ordersExpired", 0)), I18n.t("orders_expired")],
		["wrench", Palette.ORANGE, int(report.get("maintenanceNeeded", 0)), I18n.t("needs_service")],
	]
	for line in lines:
		if int(line[2]) > 0:
			column.add_child(_line(String(line[0]), line[1], int(line[2]), String(line[3])))

	content().add_child(card)

	# A level reached while the game was closed is the one thing in the report
	# that is good news and easy to miss.
	var leveled := int(report.get("leveledUpTo", 0))
	if leveled > 0:
		var banner := UiKit.card(12, Palette.TEAL)
		var row := UiKit.hbox(10)
		banner.add_child(row)
		row.add_child(UiKit.icon("star", Palette.PAPER, 22.0))
		row.add_child(UiKit.label(
			I18n.tf("level_up", [leveled]), UiKit.FONT_BODY, Palette.PAPER, true
		))
		content().add_child(banner)

	var confirm := UiKit.button(I18n.t("close"), "primary", true)
	confirm.pressed.connect(close_sheet)
	content().add_child(confirm)
	refit()


func _line(icon_name: String, color: Color, value: int, text: String) -> Control:
	var row := UiKit.hbox(10)
	row.add_child(UiKit.icon(icon_name, color, 22.0))
	# Fixed-width figure column, so a report of one-digit and four-digit lines
	# does not stagger its labels down the card.
	var figure := UiKit.label(I18n.number(value), UiKit.FONT_TITLE, Palette.INK, true)
	figure.custom_minimum_size = Vector2(46, 0)
	row.add_child(figure)
	var label := UiKit.label(text, UiKit.FONT_SMALL, Palette.INK_SOFT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row
