extends Control
## Feedback.
##
## Coin bursts, toasts and the level-up banner. Short, snappy, and never in the
## way: nothing here blocks input and nothing runs longer than a second, so
## rewards feel good without slowing the game down.

const TOAST_LIFE := 2.4
const COIN_COUNT := 7

var _toast_slot: VBoxContainer
var hud_anchor: Callable = func(): return Vector2(180, 46)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_toast_slot = UiKit.vbox(6)
	_toast_slot.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast_slot.offset_top = 74.0
	_toast_slot.offset_left = 16.0
	_toast_slot.offset_right = -16.0
	_toast_slot.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_slot)

	Events.toast.connect(show_toast)
	Events.coins_earned.connect(burst_coins)
	Events.level_up.connect(show_level_up)
	GameState.intent_failed.connect(_on_intent_failed)


## A short message. Errors are phrased as sentences, never as error codes.
func show_toast(message: String, kind: String = "info") -> void:
	var color := Palette.INK
	match kind:
		"success": color = Palette.GREEN_DEEP
		"error": color = Palette.CORAL_DEEP
		"warn": color = Palette.ORANGE_DEEP

	var card := PanelContainer.new()
	var box := UiKit.flat(Palette.PAPER, UiKit.RADIUS, Color(color.r, color.g, color.b, 0.35), 2)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	box.shadow_color = Color(0.14, 0.20, 0.29, 0.16)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 3)
	card.add_theme_stylebox_override("panel", box)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := UiKit.hbox(8)
	card.add_child(row)
	row.add_child(UiKit.icon(
		"check" if kind == "success" else ("alert" if kind == "error" else "clock"), color, 18.0
	))
	var label := UiKit.label(message, UiKit.FONT_SMALL, Palette.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	_toast_slot.add_child(card)
	card.modulate.a = 0.0
	card.scale = Vector2(0.94, 0.94)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "modulate:a", 1.0, 0.16)
	tween.tween_property(card, "scale", Vector2.ONE, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(TOAST_LIFE).timeout
	if not is_instance_valid(card):
		return
	var out := create_tween()
	out.tween_property(card, "modulate:a", 0.0, 0.22)
	await out.finished
	if is_instance_valid(card):
		card.queue_free()


## Coins fly from where they were earned to the HUD counter.
func burst_coins(amount: int, from: Vector2) -> void:
	var target: Vector2 = hud_anchor.call()
	for i in COIN_COUNT:
		var coin := UiKit.icon("coin", Palette.YELLOW_DEEP, 20.0)
		coin.position = from + Vector2(randf_range(-18.0, 18.0), randf_range(-12.0, 12.0))
		add_child(coin)

		var delay: float = float(i) * 0.035
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.set_parallel(true)
		tween.tween_property(coin, "position", target, 0.55) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(coin, "scale", Vector2(0.5, 0.5), 0.55).set_delay(0.1)
		tween.chain().tween_callback(coin.queue_free)

	var label := UiKit.label("+%s" % I18n.number(amount), UiKit.FONT_TITLE, Palette.YELLOW_DEEP, true)
	label.position = from + Vector2(-24.0, -20.0)
	add_child(label)
	var float_up := create_tween()
	float_up.set_parallel(true)
	float_up.tween_property(label, "position:y", label.position.y - 46.0, 0.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	float_up.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.2)
	float_up.chain().tween_callback(label.queue_free)


## A brief banner, not a cutscene.
func show_level_up(level: int) -> void:
	Audio.play("level_up")
	var card := PanelContainer.new()
	var box := UiKit.flat(Palette.TEAL, UiKit.RADIUS_LG)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	box.shadow_color = Color(0.14, 0.20, 0.29, 0.24)
	box.shadow_size = 14
	card.add_theme_stylebox_override("panel", box)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column := UiKit.vbox(4)
	card.add_child(column)
	var title := UiKit.label(I18n.tf("level_up", [level]), UiKit.FONT_HERO, Palette.PAPER, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var sub := UiKit.label(I18n.t("new_unlock"), UiKit.FONT_SMALL, Color(1, 1, 1, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(sub)

	add_child(card)
	await get_tree().process_frame
	card.position = (size - card.size) * 0.5 - Vector2(0, 60.0)
	card.scale = Vector2(0.7, 0.7)
	card.pivot_offset = card.size * 0.5
	card.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "modulate:a", 1.0, 0.18)
	tween.tween_property(card, "scale", Vector2.ONE, 0.42) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(card):
		return
	var out := create_tween()
	out.set_parallel(true)
	out.tween_property(card, "modulate:a", 0.0, 0.3)
	out.tween_property(card, "position:y", card.position.y - 24.0, 0.3)
	await out.finished
	if is_instance_valid(card):
		card.queue_free()


## Server refusals become a readable sentence and a sound, never a raw code.
func _on_intent_failed(_intent: String, error: String) -> void:
	Audio.play("failure", 1.2)
	show_toast(I18n.error_text(error), "error")
