extends MarginContainer
## The order board.
##
## A task board, not a table: work in hand at the top, then the requests
## waiting for an answer. Deadlines get stronger colours as they close in, and
## the only two decisions on an offer are accept and reject.

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

	var active := GameState.active_orders()
	var offers := GameState.offered_orders()

	if not active.is_empty():
		_column.add_child(_section_header(I18n.t("in_progress"), active.size()))
		for order in active:
			_column.add_child(_card(order))

	_column.add_child(_section_header(I18n.t("customer_orders"), offers.size()))
	if offers.is_empty():
		_column.add_child(UiKit.empty_state(
			"clipboard", I18n.t("no_orders"), I18n.t("no_orders_hint")
		))
	else:
		for order in offers:
			_column.add_child(_card(order))


func _section_header(text: String, count: int) -> Control:
	var row := UiKit.hbox(8)
	row.add_child(UiKit.title(text, UiKit.FONT_TITLE))
	row.add_child(UiKit.spacer())
	row.add_child(UiKit.pill(str(count), Palette.SAND, Palette.INK_SOFT))
	return row


func _card(order: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.set_script(load("res://scripts/ui/OrderPopup.gd"))
	card.setup(order)
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
