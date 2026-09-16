extends MarginContainer
## The order board.
##
## A task board, not a table. Work is grouped by what the player has to do
## about it, in that order: collect what is finished, chase what has no machine
## yet, watch what is running, then answer the requests waiting. Deadlines get
## stronger colours as they close in, and the only two decisions on an offer
## are accept and reject.
##
## Only offers show their full stats. An order already accepted has had that
## decision made, so it is drawn compact — which is what lets a board of live
## work fit on a phone rather than two cards at a time.

var _column: VBoxContainer
var _cards: Array = []


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
	_cards.clear()
	UiKit.apply_direction(self)

	var by_status := _by_status()
	var offers: Array = by_status["offered"]
	var ready: Array = by_status["ready"]
	var waiting: Array = by_status["accepted"]
	var running: Array = by_status["in_progress"]

	_column.add_child(_summary(ready, waiting.size() + running.size()))

	# Finished work first: it is coins the player already earned and has not
	# been paid for, so nothing else on the board outranks it.
	if not ready.is_empty():
		_column.add_child(UiKit.section(I18n.t("ready"), ready.size()))
		for order in ready:
			_column.add_child(_card(order, true))

	# Then the accepted orders that have no machine on them yet — the one state
	# on this board that stalls silently if nobody looks at it.
	if not waiting.is_empty():
		_column.add_child(UiKit.section(I18n.t("waiting_to_assign"), waiting.size()))
		for order in waiting:
			_column.add_child(_card(order, true))

	if not running.is_empty():
		_column.add_child(UiKit.section(I18n.t("in_progress"), running.size()))
		for order in running:
			_column.add_child(_card(order, true))

	_column.add_child(UiKit.section(I18n.t("customer_orders"), offers.size()))
	if offers.is_empty():
		_column.add_child(UiKit.empty_state(
			"clipboard", I18n.t("no_orders"), I18n.t("no_orders_hint")
		))
	else:
		for order in offers:
			_column.add_child(_card(order, false))


## The board split by what has to happen next, with the closest deadline first
## inside each group.
func _by_status() -> Dictionary:
	var out := {"offered": [], "accepted": [], "in_progress": [], "ready": []}
	for order in GameState.orders():
		var status := String(order.get("status", ""))
		if out.has(status):
			out[status].append(order)
	for key in out.keys():
		out[key].sort_custom(func(a, b):
			return Val.field_int(a, "dueAt", 0) < Val.field_int(b, "dueAt", 0))
	return out


## What the board adds up to: how much is waiting to be collected, and how much
## work is in hand. Collecting is one tap from here when anything is finished.
func _summary(ready: Array, in_hand: int) -> Control:
	var payout := 0
	for order in ready:
		payout += int(order.get("reward", 0))

	var card := UiKit.card(12, Palette.SAND)
	var row := UiKit.hbox(10)
	card.add_child(row)
	row.add_child(UiKit.icon("clipboard", Palette.SKY_DEEP, 22.0))

	var info := UiKit.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label(
		I18n.tn("orders_in_hand", in_hand), UiKit.FONT_BODY, Palette.INK, true
	))
	if ready.is_empty():
		info.add_child(UiKit.caption(I18n.t("nothing_ready"), Palette.INK_FAINT))
		row.add_child(info)
		return card

	info.add_child(UiKit.coin(payout, Palette.GREEN_DEEP))
	row.add_child(info)

	var collect := UiKit.button(I18n.t("collect_all"), "warm")
	collect.custom_minimum_size = Vector2(112, 40)
	var ids := PackedStringArray()
	for order in ready:
		ids.append(String(order.get("id", "")))
	collect.pressed.connect(func(): _collect_all(ids))
	row.add_child(collect)
	return card


## Collect every finished order in one go. Sent one at a time and in order,
## because each is a separate server-side payment and the server is the only
## thing that decides what any of them is worth.
func _collect_all(order_ids: PackedStringArray) -> void:
	var earned := 0
	for order_id in order_ids:
		var order := GameState.order_by_id(order_id)
		if order.is_empty():
			continue
		var reward := int(order.get("reward", 0))
		if await GameState.intent("collect_order", {"orderId": order_id}):
			earned += reward
	if earned > 0:
		Audio.play("coin")
		Events.coins_earned.emit(earned, get_global_rect().get_center())


func _card(order: Dictionary, compact: bool) -> Control:
	var card := PanelContainer.new()
	card.set_script(load("res://scripts/ui/OrderPopup.gd"))
	card.setup(order, compact)
	card.action.connect(_on_action)
	_cards.append(card)
	return card


func _on_action(kind: String, order_id: String) -> void:
	match kind:
		"accept":
			var accepted := await GameState.intent("accept_order", {"orderId": order_id})
			if accepted:
				Audio.play("order_new")
				Events.toast.emit(I18n.t("accept"), "success")
		"reject":
			await GameState.intent("reject_order", {"orderId": order_id})
		"assign":
			Events.navigate.emit("assign:" + order_id)
		"deliver":
			var order := GameState.order_by_id(order_id)
			var reward := int(order.get("reward", 0))
			var delivered := await GameState.intent("collect_order", {"orderId": order_id})
			if delivered:
				Audio.play("coin")
				Events.coins_earned.emit(reward, get_global_rect().get_center())


## One-second tick for countdowns and progress, without rebuilding the board.
func tick() -> void:
	for card in _cards:
		if is_instance_valid(card):
			card.tick()
