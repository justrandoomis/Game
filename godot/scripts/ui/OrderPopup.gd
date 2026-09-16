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
	var title_text: String = I18n.name_of("product", product)
	if qty > 1:
		title_text += " ×%d" % qty

	# Title row: what it is, and how urgent.
	var head := UiKit.hbox(6)
	var name_label := UiKit.label(title_text, UiKit.FONT_BODY, Palette.INK, true, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	# An order past its deadline says so once, on the countdown chip in the
	# footer beside the button — the card already carries a red edge, and a
	# second red word two centimetres above the first is noise, not emphasis.
	if _urgency() == "critical" or _urgency() == "urgent":
		if not _overdue():
			head.add_child(UiKit.pill(I18n.t("urgent"), _deadline_color()))
	column.add_child(head)

	# Material, colour and customer.
	var material := Config.material(String(order.get("materialId", "")))
	var color := Config.color(String(order.get("colorId", "")))
	var meta := UiKit.hbox(6)
	meta.add_child(_swatch(Palette.filament(String(order.get("colorId", "green")))))
	meta.add_child(UiKit.caption("%s · %s" % [
		I18n.name_of("material", material), I18n.name_of("color", color)
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
			# How long the offer itself lasts, not how long the print takes —
			# the print time is already a stat two lines above, and an offer
			# that quietly expires with no countdown is the one thing on this
			# card the player cannot plan around.
			_deadline_pill = UiKit.pill(_offer_text(), Palette.SAND, Palette.INK_SOFT)
			row.add_child(_deadline_pill)
			row.add_child(UiKit.spacer())
			var reject := UiKit.button(I18n.t("reject"), "ghost")
			reject.custom_minimum_size = Vector2(64, UiKit.TAP_MIN)
			# Turning work away is not free, and nothing said so.
			reject.tooltip_text = I18n.t("reject_cost")
			reject.pressed.connect(func(): action.emit("reject", String(order.get("id", ""))))
			row.add_child(reject)
			var accept := UiKit.button(I18n.t("accept"), "primary")
			accept.custom_minimum_size = Vector2(88, UiKit.TAP_MIN)
			accept.pressed.connect(func(): action.emit("accept", String(order.get("id", ""))))
			row.add_child(accept)
		"accepted":
			row.add_child(_deadline_chip())
			row.add_child(UiKit.spacer())
			var assign := UiKit.button(I18n.t("assign"), "primary")
			assign.custom_minimum_size = Vector2(108, UiKit.TAP_MIN)
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
			# A leg lost to a cancellation or a failure leaves the order short.
			# The server will not take it as delivered until the shortfall is
			# printed, so the card has to offer somewhere to put it.
			var owed := _outstanding()
			if owed > 0:
				var short_row := UiKit.hbox(8)
				short_row.add_child(UiKit.caption(
					I18n.tn("units_left", owed), Palette.ORANGE_DEEP
				))
				short_row.add_child(UiKit.spacer())
				var top_up := UiKit.button(I18n.t("assign"), "secondary")
				top_up.custom_minimum_size = Vector2(108, UiKit.TAP_MIN)
				top_up.pressed.connect(func(): action.emit("assign", String(order.get("id", ""))))
				short_row.add_child(top_up)
				column.add_child(short_row)
			return column
		"ready":
			# A finished order is drawn compact on the board, so its reward is
			# not in the stats block above — and the reward is the whole reason
			# to press the button beside it. Past its deadline it pays a
			# fraction, which the card has to say before the coins land at a
			# number the player was not expecting.
			var late := _overdue() or bool(order.get("late", false))
			if late:
				row.add_child(UiKit.pill(
					I18n.tf("late_pay", [int(round(Config.late_penalty() * 100.0))]),
					Palette.CORAL_DEEP
				))
			else:
				row.add_child(UiKit.pill(I18n.t("ready"), Palette.GREEN_DEEP))
			row.add_child(UiKit.coin(
				_payout(), Palette.CORAL_DEEP if late else Palette.GREEN_DEEP
			))
			row.add_child(UiKit.spacer())
			var deliver := UiKit.button(I18n.t("deliver"), "warm")
			deliver.custom_minimum_size = Vector2(108, UiKit.TAP_MIN)
			deliver.pressed.connect(func(): action.emit("deliver", String(order.get("id", ""))))
			row.add_child(deliver)
		"failed":
			row.add_child(UiKit.pill(I18n.t("failed_order"), Palette.CORAL_DEEP))
			row.add_child(UiKit.spacer())
			row.add_child(UiKit.caption(
				"%s %d" % [I18n.t("reputation"), -int(order.get("repReward", 0))], Palette.CORAL_DEEP
			))
		"delivered", "expired", "rejected":
			row.add_child(UiKit.pill(I18n.t(status), Palette.INK_FAINT))
		_:
			row.add_child(UiKit.pill(status.capitalize(), Palette.INK_FAINT))
	return row


## Units of the order that no live job covers. Mirrors outstandingQty() on the
## server, which is what decides whether the order can be delivered.
func _outstanding() -> int:
	var covered := 0
	for job_id in order.get("jobIds", []):
		var job := GameState.job_by_id(String(job_id))
		if not job.is_empty():
			covered += int(job.get("qty", 0))
	return maxi(0, int(order.get("qty", 1)) - covered)


## What this order pays if it is collected now. A quote from the same number
## the server uses, so the card and the coins agree; the server still decides.
func _payout() -> int:
	var reward := int(order.get("reward", 0))
	if _overdue() or bool(order.get("late", false)):
		return int(round(float(reward) * Config.late_penalty()))
	return reward


## How long an offer stays on the board. Falls back to the print time only if
## the server did not send an expiry.
func _offer_text() -> String:
	var expires := Val.field_int(order, "expiresAt", 0)
	if expires <= 0:
		return ServerClock.format_short(int(order.get("printMs", 0)))
	var left := ServerClock.remaining(expires)
	return ServerClock.format_short(left) if left > 0 else I18n.t("expired")


## Countdown chip whose colour strengthens as the deadline approaches.
func _deadline_chip() -> Control:
	var due := Val.field_int(order, "dueAt", 0)
	var text := ServerClock.format_short(ServerClock.remaining(due)) if due > 0 else "—"
	if due > 0 and ServerClock.remaining(due) <= 0:
		text = I18n.t("overdue")
	_deadline_pill = UiKit.pill(text, _deadline_color())
	return _deadline_pill


## Past its delivery window. Still deliverable — it pays the reduced rate.
func _overdue() -> bool:
	var due := Val.field_int(order, "dueAt", 0)
	return due > 0 and ServerClock.remaining(due) <= 0


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
	if _deadline_pill == null or not is_instance_valid(_deadline_pill):
		return
	# An offer counts down to when it leaves the board; everything accepted
	# counts down to its delivery deadline.
	var text := ""
	if String(order.get("status", "")) == "offered":
		text = _offer_text()
	else:
		var due := Val.field_int(order, "dueAt", 0)
		if due <= 0:
			return
		text = I18n.t("overdue") if ServerClock.remaining(due) <= 0 \
			else ServerClock.format_short(ServerClock.remaining(due))
	for child in _deadline_pill.get_children():
		if child is Label:
			child.text = text
