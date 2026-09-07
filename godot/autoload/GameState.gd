extends Node
## AUTHORITATIVE STATE.
##
## The single copy of the farm the client holds, and it is always the server's
## copy: every mutation goes out as an intent and comes back as a whole fresh
## snapshot, which replaces this one. Nothing here is ever edited locally to
## "predict" a result, because the server owns coins, filament, jobs, rewards
## and reputation.
##
## Simulation stays on the server; this node is the seam between it and the
## presentation layer.

signal state_changed()
signal away_report(report: Dictionary)
signal intent_failed(intent: String, error: String)
signal fx(kind: String, value: Variant, at: String)
signal busy_changed(busy: bool)

var state: Dictionary = {}
var ready_state: bool = false

var _busy: bool = false
var _pending: int = 0
## Slot ids that were empty last snapshot, so new arrivals can animate in.
var _known_printers: Dictionary = {}
var _last_level: int = 0


func _set_busy(value: bool) -> void:
	if _busy == value:
		return
	_busy = value
	busy_changed.emit(_busy)


func is_busy() -> bool:
	return _busy


## Boot: fetch balancing data, then the farm.
func boot() -> bool:
	var ok := await Config.load_config()
	if not ok:
		return false
	return await refresh(true)


## Pull the farm. The server resolves everything that fell due while away and
## returns what the player missed.
func refresh(show_report: bool = false) -> bool:
	_pending += 1
	_set_busy(true)
	var response := await Net.get_json("/api/game/state")
	_pending -= 1
	_set_busy(_pending > 0)

	if not response.get("success", false):
		return false
	_adopt(response.get("state", {}))
	if show_report and response.has("report"):
		var report: Dictionary = response["report"]
		if _report_worth_showing(report):
			away_report.emit(report)
	return true


## Send one player action. The reply is the new snapshot.
func intent(name: String, payload: Dictionary = {}) -> bool:
	_pending += 1
	_set_busy(true)
	var response := await Net.post_json("/api/game/intent", {"intent": name, "payload": payload})
	_pending -= 1
	_set_busy(_pending > 0)

	if not response.get("success", false):
		var error := String(response.get("error", "unknown"))
		intent_failed.emit(name, error)
		var hint = response.get("fx", null)
		if typeof(hint) == TYPE_DICTIONARY:
			fx.emit(String(hint.get("kind", "")), hint.get("value", null), String(hint.get("at", "")))
		return false

	_adopt(response.get("state", {}))
	var effect = response.get("fx", null)
	if typeof(effect) == TYPE_DICTIONARY:
		fx.emit(String(effect.get("kind", "")), effect.get("value", null), String(effect.get("at", "")))
	return true


func _adopt(next: Dictionary) -> void:
	if next.is_empty():
		return
	var previous_level := _last_level
	state = next
	ready_state = true
	_last_level = level()

	# Newly arrived machines get their unboxing animation once.
	for printer in printers():
		var id := String(printer.get("id", ""))
		if id != "" and not _known_printers.has(id):
			_known_printers[id] = true
			if previous_level > 0:
				Events.station_event.emit(Val.field_text(printer, "slotId"), "arrived")

	if previous_level > 0 and _last_level > previous_level:
		Events.level_up.emit(_last_level)

	state_changed.emit()


func _report_worth_showing(report: Dictionary) -> bool:
	if int(report.get("elapsedMs", 0)) < 5 * 60 * 1000:
		return false
	return (
		int(report.get("printsCompleted", 0)) > 0
		or int(report.get("printsFailed", 0)) > 0
		or int(report.get("ordersDelivered", 0)) > 0
		or int(report.get("coinsEarned", 0)) > 0
		or int(report.get("storeSales", 0)) > 0
	)


# ----------------------------------------------------------------- accessors

func level() -> int:
	return int(state.get("level", 1))


func xp() -> int:
	return int(state.get("xp", 0))


func coins() -> int:
	return int(state.get("coins", 0))


func reputation() -> float:
	return float(state.get("reputation", 0.0))


func tier_index() -> int:
	return int(state.get("tier", 0))


func unlocked_slots() -> Array:
	return state.get("unlockedSlots", [])


func printers() -> Array:
	return state.get("printers", [])


func spools() -> Array:
	return state.get("spools", [])


func jobs() -> Array:
	return state.get("jobs", [])


func orders() -> Array:
	return state.get("orders", [])


func store_stock() -> Dictionary:
	return state.get("storeStock", {})


func demand() -> Dictionary:
	return state.get("demand", {})


func parts() -> Dictionary:
	return state.get("parts", {})


func stats() -> Dictionary:
	return state.get("stats", {})


func tutorial_step() -> int:
	return int(state.get("tutorialStep", 0))


func printer_by_id(id: String) -> Dictionary:
	for p in printers():
		if String(p.get("id", "")) == id:
			return p
	return {}


func printer_at_slot(slot_id: String) -> Dictionary:
	for p in printers():
		if Val.field_text(p, "slotId") == slot_id:
			return p
	return {}


func job_by_id(id: String) -> Dictionary:
	for j in jobs():
		if String(j.get("id", "")) == id:
			return j
	return {}


func order_by_id(id: String) -> Dictionary:
	for o in orders():
		if String(o.get("id", "")) == id:
			return o
	return {}


## The job a machine is printing right now, if any.
func active_job(printer_id: String) -> Dictionary:
	var printer := printer_by_id(printer_id)
	var queue: Array = printer.get("queue", [])
	if queue.is_empty():
		return {}
	return job_by_id(String(queue[0]))


func queued_jobs(printer_id: String) -> Array:
	var printer := printer_by_id(printer_id)
	var out: Array = []
	for job_id in printer.get("queue", []):
		var job := job_by_id(String(job_id))
		if not job.is_empty():
			out.append(job)
	return out


func offered_orders() -> Array:
	return orders().filter(func(o): return String(o.get("status", "")) == "offered")


func active_orders() -> Array:
	return orders().filter(func(o):
		var s := String(o.get("status", ""))
		return s == "accepted" or s == "in_progress" or s == "ready")


## Grams of a material+colour on hand across every spool.
func grams_available(material_id: String, color_id: String = "") -> float:
	var total := 0.0
	for s in spools():
		if String(s.get("materialId", "")) != material_id:
			continue
		if color_id != "" and String(s.get("colorId", "")) != color_id:
			continue
		total += float(s.get("grams", 0.0))
	return total


## Machines that are free to take work right now.
func idle_printers() -> Array:
	return printers().filter(func(p): return String(p.get("status", "")) == "idle")
