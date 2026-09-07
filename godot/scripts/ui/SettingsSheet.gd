extends "res://scripts/ui/BottomSheet.gd"
## Settings.
##
## Sound and language, and a look at how the workshop is doing. Account,
## profile and rewards stay with the Levonis platform — the game does not
## duplicate them.


func open() -> void:
	add_header(I18n.t("settings"), I18n.t("app_title"))
	content().add_child(_sound_row())
	content().add_child(_language_row())
	content().add_child(_stats_card())
	refit()


func _sound_row() -> Control:
	var card := UiKit.card()
	var row := UiKit.hbox(10)
	card.add_child(row)
	row.add_child(UiKit.icon("bolt", Palette.YELLOW_DEEP, 20.0))
	var label := UiKit.label(I18n.t("sound"), UiKit.FONT_BODY, Palette.INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var toggle := UiKit.button(I18n.t("off") if Audio.muted else I18n.t("on"), "secondary")
	toggle.custom_minimum_size = Vector2(84, 40)
	toggle.pressed.connect(func():
		var muted := Audio.toggle_mute()
		toggle.text = I18n.t("off") if muted else I18n.t("on")
		if not muted:
			Audio.play("tap"))
	row.add_child(toggle)
	return card


func _language_row() -> Control:
	var card := UiKit.card()
	var column := UiKit.vbox(8)
	card.add_child(column)
	column.add_child(UiKit.label(I18n.t("language"), UiKit.FONT_SMALL, Palette.INK_SOFT, true))

	var row := UiKit.hbox(8)
	for entry in [{"id": "en", "name": "English"}, {"id": "ar", "name": "العربية"}, {"id": "ku", "name": "کوردی"}]:
		var lang_id: String = entry["id"]
		var active: bool = I18n.lang == lang_id
		var button := UiKit.button(String(entry["name"]), "secondary", true)
		if active:
			button.add_theme_stylebox_override("normal", UiKit.flat(Palette.TEAL, UiKit.RADIUS))
			button.add_theme_color_override("font_color", Palette.PAPER)
		button.pressed.connect(func():
			I18n.set_language(lang_id)
			close_sheet())
		row.add_child(button)
	column.add_child(row)
	return card


## A quiet summary of the workshop, rather than a dashboard of everything.
func _stats_card() -> Control:
	var stats := GameState.stats()
	var card := UiKit.card()
	var column := UiKit.vbox(8)
	card.add_child(column)
	column.add_child(UiKit.label(I18n.t("workshop_value"), UiKit.FONT_SMALL, Palette.INK_SOFT, true))

	column.add_child(_row("clipboard", Palette.SKY_DEEP, I18n.t("orders_delivered"),
		I18n.number(int(stats.get("ordersCompleted", 0)))))
	column.add_child(_row("printer", Palette.TEAL_DEEP, I18n.t("prints_done"),
		I18n.number(int(stats.get("printsCompleted", 0)))))
	column.add_child(_row("spool", Palette.ORANGE, I18n.t("grams"),
		I18n.number(int(stats.get("gramsPrinted", 0)))))
	column.add_child(_row("coin", Palette.YELLOW_DEEP, I18n.t("coins_earned"),
		I18n.number(int(stats.get("coinsEarned", 0)))))
	return card


func _row(icon_name: String, color: Color, label_text: String, value: String) -> Control:
	var row := UiKit.hbox(8)
	row.add_child(UiKit.icon(icon_name, color, 17.0))
	var name_label := UiKit.label(label_text, UiKit.FONT_SMALL, Palette.INK_SOFT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(UiKit.label(value, UiKit.FONT_SMALL, Palette.INK, true))
	return row
