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
	var missed: Array = by_status["failed"]

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

	# And last, what was missed. An order whose deadline passed with work
	# outstanding costs reputation and pays nothing, and used to vanish off the
	# board without a word — the player was left to notice the reputation had
	# dropped and guess why. The server keeps these for a day.
	if not missed.is_empty():
		_column.add_child(UiKit.section(I18n.t("missed"), missed.size()))
		for order in missed:
			_column.add_child(_card(order, true))


## The board split by what has to happen next, with the closest deadline first
## inside each group.
func _by_status() -> Dictionary:
	var out := {"offered": [], "accepted": [], "in_progress": [], "ready": [], "failed": []}
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
	# Against the cap, because the cap is what refuses the next accept and the
	# board never mentioned it existed.
	var cap := Config.accepted_capacity(GameState.level()) if Config.is_loaded else in_hand
	info.add_child(UiKit.label(
		I18n.tf("orders_capacity", [in_hand, cap]), UiKit.FONT_BODY, Palette.INK, true
	))
	if ready.is_empty():
		info.add_child(UiKit.caption(
			I18n.t("hands_full") if in_hand >= cap else I18n.t("nothing_ready"),
			Palette.ORANGE_DEEP if in_hand >= cap else Palette.INK_FAINT
		))
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
## Collect every finished order in one go. Sent one at a time and in order,
## because each is a separate server-side payment.
##
## The coins that fly up come from the server's own reply to each collection,
## routed through Main._on_fx — not from adding up the rewards printed on the
## cards. A late delivery pays a fraction of its reward, so the card's figure
## is not what was earned, and showing it here put a second, wrong burst on
## screen beside the right one.
func _collect_all(order_ids: PackedStringArray) -> void:
	var collected := 0
	for order_id in order_ids:
		if GameState.order_by_id(order_id).is_empty():
			continue
		if await GameState.intent("collect_order", {"orderId": order_id}):
			collected += 1
	if collected > 0:
		Audio.play("coin")


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
			# The burst is the server's, not ours — see _collect_all().
			if await GameState.intent("collect_order", {"orderId": order_id}):
				Audio.play("coin")


## One-second tick for countdowns and progress, without rebuilding the board.
func tick() -> void:
	for card in _cards:
		if is_instance_valid(card):
			card.tick()
