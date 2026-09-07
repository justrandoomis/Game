extends PanelContainer
## An order card.
##
## The one place a customer order is rendered, used by the order board, by the
## printer sheet and by the popup that announces a new request. Designed like a
## task card in a game, not a row in a CRM: a picture of the part, who wants it,
## what it is made of, what it pays, and how long is left.

signal action(kind: String, order_id: String)

const THUMB := 54.0

var order: Dictionary = {}
var _deadline_label: Label
var _deadline_pill: PanelContainer
var _progress_bar: ProgressBar


func setup(next_order: Dictionary, compact: bool = false) -> void:
	order = next_order
	for child in get_children():
		child.queue_free()

	add_theme_stylebox_override("panel", _card_box())
	var row := UiKit.hbox(12)
	add_child(row)

	row.add_child(_build_thumb())
	row.add_child(_build_body(compact))
	UiKit.apply_direction(self)


func _card_box() -> StyleBoxFlat:
	var box := UiKit.flat(Palette.PAPER, UiKit.RADIUS, Palette.LINE, 1)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	box.shadow_color = Color(0.14, 0.20, 0.29, 0.09)
	box.shadow_size = 5
	box.shadow_offset = Vector2(0, 2)
	# An urgent job carries a coloured edge rather than a flashing animation.
	var band := _deadline_color()
	if _urgency() != "normal":
		box.border_color = band
		box.set_border_width_all(2)
	return box


## A little picture of the part, drawn in the filament colour it is ordered in.
func _build_thumb() -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(THUMB, THUMB)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.add_theme_stylebox_override("panel", UiKit.flat(Palette.SAND, 14.0))

	var product := Config.product(String(order.get("productId", "")))
	var thumb := ProductThumb.new(
		String(product.get("icon", "dino")),
		Palette.filament(String(order.get("colorId", "green")))
	)
	frame.add_child(thumb)
	return frame


func _build_body(compact: bool) -> Control:
	var column := UiKit.vbox(6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var product := Config.product(String(order.get("productId", "")))
	var qty := int(order.get("qty", 1))
	var title_text: String = String(product.get("name", "Part"))
	if qty > 1:
		title_text += " ×%d" % qty

	# Title row: what it is, and how urgent.
	var head := UiKit.hbox(6)
	var name_label := UiKit.label(title_text, UiKit.FONT_BODY, Palette.INK, true, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	if _urgency() == "critical" or _urgency() == "urgent":
		head.add_child(UiKit.pill(I18n.t("urgent"), _deadline_color()))
	column.add_child(head)

	# Material, colour and customer.
	var material := Config.material(String(order.get("materialId", "")))
	var color := Config.color(String(order.get("colorId", "")))
	var meta := UiKit.hbox(6)
	meta.add_child(_swatch(Palette.filament(String(order.get("colorId", "green")))))
	meta.add_child(UiKit.caption("%s · %s" % [
		String(material.get("name", "PLA")), String(color.get("name", ""))
	]))
	meta.add_child(UiKit.spacer())
	# The customer's name is the first thing to give up room if space is tight.
	var customer_label := UiKit.label(
		String(order.get("customerName", "")), UiKit.FONT_SMALL, Palette.INK_FAINT, false, true
	)
	customer_label.custom_minimum_size = Vector2(48, 0)
	meta.add_child(customer_label)
	column.add_child(meta)

	if not compact:
		column.add_child(_build_stats())

	column.add_child(_build_footer())
	return column


func _swatch(color: Color) -> Control:
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.add_theme_stylebox_override("panel", UiKit.flat(color, 7.0, Palette.LINE, 1))
	return dot


## Reward, print time, filament and reputation — the four numbers a player
## actually decides on.
func _build_stats() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)

	grid.add_child(_stat("coin", Palette.YELLOW_DEEP, I18n.number(int(order.get("reward", 0)))))
	grid.add_child(_stat("clock", Palette.SKY_DEEP, ServerClock.format_short(int(order.get("printMs", 0)))))
	grid.add_child(_stat("spool", Palette.TEAL_DEEP, "%s %s" % [
		I18n.number(int(order.get("grams", 0))), I18n.t("grams")
	]))
	grid.add_child(_stat("star", Palette.YELLOW, "+%d" % int(order.get("repReward", 0))))
	return grid


func _stat(icon_name: String, color: Color, text: String) -> Control:
	var row := UiKit.hbox(5)
	row.add_child(UiKit.icon(icon_name, color, 15.0))
	var value := UiKit.label(text, UiKit.FONT_SMALL, Palette.INK)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	return row


## The footer changes with the order's state: offers get accept/reject, live
## orders get progress, finished ones get a deliver button.
func _build_footer() -> Control:
	var status := String(order.get("status", "offered"))
	var row := UiKit.hbox(8)

	match status:
		"offered":
			_deadline_pill = UiKit.pill(
				ServerClock.format_short(int(order.get("printMs", 0))), Palette.SAND, Palette.INK_SOFT
			)
			row.add_child(_deadline_pill)
			row.add_child(UiKit.spacer())
			var reject := UiKit.button(I18n.t("reject"), "ghost")
			reject.custom_minimum_size = Vector2(56, 40)
			reject.pressed.connect(func(): action.emit("reject", String(order.get("id", ""))))
			row.add_child(reject)
			var accept := UiKit.button(I18n.t("accept"), "primary")
			accept.custom_minimum_size = Vector2(84, 40)
			accept.pressed.connect(func(): action.emit("accept", String(order.get("id", ""))))
			row.add_child(accept)
		"accepted":
			row.add_child(_deadline_chip())
			row.add_child(UiKit.spacer())
			var assign := UiKit.button(I18n.t("assign"), "primary")
			assign.custom_minimum_size = Vector2(104, 40)
			assign.pressed.connect(func(): action.emit("assign", String(order.get("id", ""))))
			row.add_child(assign)
		"in_progress":
			var column := UiKit.vbox(6)
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var head := UiKit.hbox(8)
			head.add_child(UiKit.pill(I18n.t("in_progress"), Palette.SKY_DEEP))
			head.add_child(UiKit.spacer())
			head.add_child(_deadline_chip())
			column.add_child(head)
			_progress_bar = UiKit.bar(_order_progress(), Palette.SKY_DEEP, 8.0)
			column.add_child(_progress_bar)
			return column
		"ready":
			row.add_child(UiKit.pill(I18n.t("ready"), Palette.GREEN_DEEP))
			row.add_child(UiKit.spacer())
			var deliver := UiKit.button(I18n.t("deliver"), "warm")
			deliver.custom_minimum_size = Vector2(104, 40)
			deliver.pressed.connect(func(): action.emit("deliver", String(order.get("id", ""))))
			row.add_child(deliver)
		_:
			row.add_child(UiKit.pill(I18n.t(status), Palette.INK_FAINT))
	return row


## Countdown chip whose colour strengthens as the deadline approaches.
func _deadline_chip() -> Control:
	var due := Val.field_int(order, "dueAt", 0)
	var text := ServerClock.format_short(ServerClock.remaining(due)) if due > 0 else "—"
	if due > 0 and ServerClock.remaining(due) <= 0:
		text = I18n.t("overdue")
	_deadline_pill = UiKit.pill(text, _deadline_color())
	return _deadline_pill


## Mirrors deadlineBand() on the server: normal, soon, urgent, critical.
func _urgency() -> String:
	var due := Val.field_int(order, "dueAt", 0)
	if due <= 0:
		return "normal"
	var accepted := Val.field_int(order, "acceptedAt", Val.field_int(order, "offeredAt"))
	var total: float = maxf(1.0, float(due - accepted))
	var fraction: float = float(due - ServerClock.now()) / total
	if fraction <= 0.10:
		return "critical"
	if fraction <= 0.25:
		return "urgent"
	if fraction <= 0.50:
		return "soon"
	return "normal"


func _deadline_color() -> Color:
	return Palette.DEADLINE.get(_urgency(), Palette.SKY_DEEP)


## Share of the order's jobs that have finished printing.
func _order_progress() -> float:
	var job_ids: Array = order.get("jobIds", [])
	if job_ids.is_empty():
		return 0.0
	var total := 0.0
	for job_id in job_ids:
		var job := GameState.job_by_id(String(job_id))
		if job.is_empty():
			continue
		var status := String(job.get("status", ""))
		if status == "done" or status == "collected":
			total += 1.0
		elif status == "printing":
			total += ServerClock.progress(Val.field_int(job, "startedAt", 0), int(job.get("durationMs", 0)))
	return clampf(total / float(job_ids.size()), 0.0, 1.0)


## Cheap per-second refresh of just the numbers that move.
func tick() -> void:
	if _progress_bar != null and is_instance_valid(_progress_bar):
		_progress_bar.value = _order_progress()
	if _deadline_pill != null and is_instance_valid(_deadline_pill):
		var due := Val.field_int(order, "dueAt", 0)
		if due > 0:
			var text := ServerClock.format_short(ServerClock.remaining(due))
			if ServerClock.remaining(due) <= 0:
				text = I18n.t("overdue")
			for child in _deadline_pill.get_children():
				if child is Label:
					child.text = text
