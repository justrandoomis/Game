extends Node2D
## THE FARM.
##
## Builds the workshop from the grid and keeps it in step with the server's
## snapshot. It owns no game rules: it reads state, positions things by their
## slot, and turns taps into intents for the UI to act on.
##
## Placement is entirely deterministic. Stations come from Iso.room_slots(),
## fixtures and decor are anchored to the room's own bounds, and Y-sorting does
## the depth ordering — which works because screen Y is proportional to
## isometric depth in this projection.

const PrinterStationScene := preload("res://scenes/farm/PrinterStation.tscn")
const EmptySlotScene := preload("res://scenes/farm/EmptySlot.tscn")
const WorkerScene := preload("res://scenes/farm/Worker.tscn")

## Progress bars and countdowns refresh on a timer, not every frame: a print
## takes hours, so 5 Hz is smooth and costs almost nothing on a phone.
const TICK_HZ := 5.0

@onready var camera: Camera2D = $Camera
@onready var world: Node2D = $World
@onready var floor_layer: Node2D = $World/Floor
@onready var decor: Node2D = $World/Decor
@onready var fixtures: Node2D = $World/Fixtures
@onready var stations_root: Node2D = $World/Stations
@onready var workers_root: Node2D = $World/Workers
@onready var rack: Node2D = $World/Fixtures/FilamentRack
@onready var bench: Node2D = $World/Fixtures/MaintenanceBench

var _stations: Dictionary = {}
var _empty_slots: Dictionary = {}
var _rows: int = 1
var _cols: int = 2
var _tier_index: int = -1
var _tick_accumulator: float = 0.0
var _pending_focus: String = ""


func _ready() -> void:
	camera.tapped.connect(_on_tapped)
	GameState.state_changed.connect(_on_state_changed)
	Events.focus_slot.connect(_on_focus_slot)
	Events.station_event.connect(_on_station_event)
	get_viewport().size_changed.connect(_on_viewport_resized)
	if GameState.ready_state:
		_on_state_changed()


func _process(delta: float) -> void:
	_tick_accumulator += delta
	if _tick_accumulator < 1.0 / TICK_HZ:
		return
	_tick_accumulator = 0.0
	_refresh_live_stations()


# ------------------------------------------------------------------- build

func _on_state_changed() -> void:
	var tier := GameState.tier_index()
	if tier != _tier_index:
		_rebuild_room(tier)
	_sync_stations()
	_sync_fixtures()
	_sync_workers()


## Lay out a room from scratch. Called on boot and whenever the workshop is
## expanded to a bigger tier.
func _rebuild_room(tier_index: int) -> void:
	var tier := Config.workshop_tier(tier_index)
	_tier_index = tier_index
	_rows = int(tier.get("rows", 1))
	_cols = int(tier.get("cols", 2))

	floor_layer.call("configure", _rows, _cols, String(tier.get("floor", "tile")))
	decor.call("configure", _rows, _cols)
	_place_fixtures()

	for child in stations_root.get_children():
		child.queue_free()
	_stations.clear()
	_empty_slots.clear()

	# One node per grid cell, positioned only by the grid.
	for cell in Iso.room_slots(_rows, _cols):
		var id := Iso.slot_id(cell.x, cell.y)
		var station: Node2D = PrinterStationScene.instantiate()
		station.position = Iso.cell_to_world(cell.x, cell.y)
		station.setup(id, Iso.slot_label(cell.x, cell.y, _cols))
		station.visible = false
		stations_root.add_child(station)
		_stations[id] = station

		var empty: Node2D = EmptySlotScene.instantiate()
		empty.position = station.position
		empty.visible = false
		stations_root.add_child(empty)
		_empty_slots[id] = empty

	_frame_room(_tier_index > 0)


## Chrome that overlays the scene, so the camera can keep the room clear of it.
const HUD_TOP := 62.0
const NAV_BOTTOM := 132.0


func _frame_room(animate: bool) -> void:
	# Frame the working area — the station grid plus half a tile of breathing
	# room — rather than the whole floor. Fitting the walkways and the back
	# walls as well would shrink the machines into the middle of the screen;
	# the walkways are still there to pan over, they just are not what the
	# player is looking at.
	var fit := _grid_bounds()
	# Grown symmetrically, so the room stays centred on the station grid rather
	# than drifting upward because of the headroom left for status bubbles.
	fit = fit.grow_individual(
		Iso.TILE_W * 0.5, Iso.TILE_H * 0.5 + 40.0,
		Iso.TILE_W * 0.5, Iso.TILE_H * 0.5 + 40.0
	)
	camera.call(
		"frame_room", fit, _floor_bounds(), _usable_viewport(), animate,
		(NAV_BOTTOM - HUD_TOP) * 0.5
	)


## Bounding box of the station cells alone.
func _grid_bounds() -> Rect2:
	var half := Vector2(Iso.TILE_W * 0.5, Iso.TILE_H * 0.5)
	var n := Iso.cell_to_world(0, 0) + Vector2(0, -half.y)
	var e := Iso.cell_to_world(0, _cols - 1) + Vector2(half.x, 0)
	var s := Iso.cell_to_world(_rows - 1, _cols - 1) + Vector2(0, half.y)
	var w := Iso.cell_to_world(_rows - 1, 0) + Vector2(-half.x, 0)
	return Rect2(Vector2(w.x, n.y), Vector2(e.x - w.x, s.y - n.y))


## The floor's world-space bounding box, band included.
func _floor_bounds() -> Rect2:
	var half := Vector2(Iso.TILE_W * 0.5, Iso.TILE_H * 0.5)
	var n := Iso.cell_to_world(-1, -1) + Vector2(0, -half.y)
	var e := Iso.cell_to_world(-1, _cols) + Vector2(half.x, 0)
	var s := Iso.cell_to_world(_rows, _cols) + Vector2(0, half.y)
	var w := Iso.cell_to_world(_rows, -1) + Vector2(-half.x, 0)
	return Rect2(
		Vector2(w.x, n.y),
		Vector2(e.x - w.x, s.y - n.y)
	)


## The screen area not covered by the HUD or the navigation bar.
func _usable_viewport() -> Vector2:
	var viewport := get_viewport_rect().size
	return Vector2(viewport.x, maxf(200.0, viewport.y - HUD_TOP - NAV_BOTTOM))


func _on_viewport_resized() -> void:
	_frame_room(false)


## Fixtures stand on cells of the service band that rings the station grid.
## Using grid cells rather than free offsets is what keeps them on the same
## isometric lattice as the machines — they can never float off the floor, take
## a station's cell, or shift when the workshop is expanded.
func _place_fixtures() -> void:
	# Rack against the right-hand wall, at the far end of the back walkway.
	rack.position = Iso.cell_to_world(-1, _cols - 1)
	# Bench against the left-hand wall, toward the front so it is easy to reach.
	bench.position = Iso.cell_to_world(_rows - 1, -1)


# -------------------------------------------------------------------- sync

func _sync_stations() -> void:
	var unlocked: Array = GameState.unlocked_slots()
	var next_unlock := _next_unlockable_slot(unlocked)

	for slot_id in _stations.keys():
		var station: Node2D = _stations[slot_id]
		var empty: Node2D = _empty_slots[slot_id]
		var printer := GameState.printer_at_slot(slot_id)

		if not printer.is_empty():
			station.visible = true
			empty.visible = false
			_apply_printer(station, printer)
			continue

		station.visible = false
		empty.visible = true
		var is_unlocked: bool = unlocked.has(slot_id)
		var available: bool = is_unlocked or slot_id == next_unlock
		if is_unlocked:
			# The bay is paid for and standing empty: it wants a machine.
			empty.setup(slot_id, true, I18n.t("buy_printer"), 0)
		elif slot_id == next_unlock:
			empty.setup(slot_id, true, I18n.t("unlock_station"), Config.slot_cost(unlocked.size()))
		else:
			# Locked cells are visible but silent — the eye should land on the
			# one slot the player can actually buy next.
			empty.setup(slot_id, false, "", 0)


## The one slot the player may buy next. Unlocking in reading order is what
## keeps the workshop filling out as even rows rather than a scatter.
func _next_unlockable_slot(unlocked: Array) -> String:
	var tier := Config.workshop_tier(_tier_index)
	if unlocked.size() >= int(tier.get("slots", 0)):
		return ""
	for cell in Iso.room_slots(_rows, _cols):
		var id := Iso.slot_id(cell.x, cell.y)
		if not unlocked.has(id):
			return id
	return ""


func _apply_printer(station: Node2D, printer: Dictionary) -> void:
	var job := GameState.active_job(String(printer.get("id", "")))
	var progress := 0.0
	if not job.is_empty() and String(job.get("status", "")) == "printing":
		progress = ServerClock.progress(Val.field_int(job, "startedAt", 0), int(job.get("durationMs", 0)))
	station.apply(printer, job, progress)


## Cheap per-tick refresh: only machines that are actually printing.
func _refresh_live_stations() -> void:
	if not GameState.ready_state:
		return
	for printer in GameState.printers():
		if String(printer.get("status", "")) != "printing":
			continue
		var slot_id := Val.field_text(printer, "slotId")
		if _stations.has(slot_id):
			_apply_printer(_stations[slot_id], printer)


func _sync_fixtures() -> void:
	rack.call("set_spools", GameState.spools())
	var servicing := GameState.printers().any(
		func(p): return String(p.get("status", "")) == "maintenance"
	)
	bench.call("set_busy", servicing)


## Employees appear in the room once the system unlocks — an early workshop is
## deliberately empty so hiring is something the player sees happen.
func _sync_workers() -> void:
	var unlocked := Config.has_feature(GameState.level(), "employees")
	var wanted := 0
	if unlocked:
		wanted = mini(3, 1 + int(GameState.printers().size() / 4.0))
	if workers_root.get_child_count() == wanted:
		return

	for child in workers_root.get_children():
		child.queue_free()
	for i in wanted:
		var worker: Node2D = WorkerScene.instantiate()
		worker.role = i % 4
		workers_root.add_child(worker)
		worker.call("set_route", _worker_route(i))


## Fixed patrol routes between the aisles, the rack and the bench. Predefined
## points, no pathfinding.
func _worker_route(index: int) -> Array[Vector2]:
	# Routes run along the service band, so nobody walks through a work table.
	var front_left := Iso.cell_to_world(_rows, -1)
	var front_right := Iso.cell_to_world(_rows, _cols)
	var back_right := Iso.cell_to_world(-1, _cols - 1) + Vector2(0, Iso.TILE_H * 0.55)
	var bench_side := Iso.cell_to_world(_rows - 1, -1) + Vector2(Iso.TILE_W * 0.42, 0)
	match index % 3:
		0:
			return [front_left, front_right, bench_side]
		1:
			return [front_right, back_right, front_left]
		_:
			return [front_left.lerp(front_right, 0.5), front_right, bench_side]


# --------------------------------------------------------------------- input

## Hit testing runs front to back in the same order things are drawn, and each
## piece tests its own local shape — so a tap lands on what the player can see,
## not on the floor tile hidden behind it.
func _on_tapped(world_position: Vector2) -> void:
	var local := world.to_local(world_position)

	var ordered: Array = []
	for slot_id in _stations.keys():
		var station: Node2D = _stations[slot_id]
		if station.visible:
			ordered.append({"node": station, "id": slot_id, "y": station.position.y})
	ordered.sort_custom(func(a, b): return a["y"] > b["y"])

	for entry in ordered:
		var station: Node2D = entry["node"]
		if station.contains_point(local - station.position):
			Audio.play("tap")
			station.play_tap()
			Events.station_tapped.emit(entry["id"], station.printer_id)
			return

	if rack.contains_point(local - rack.position):
		Audio.play("tap")
		Events.fixture_tapped.emit("rack")
		return
	if bench.contains_point(local - bench.position):
		Audio.play("tap")
		Events.fixture_tapped.emit("bench")
		return

	for slot_id in _empty_slots.keys():
		var empty: Node2D = _empty_slots[slot_id]
		if empty.visible and empty.contains_point(local - empty.position):
			Audio.play("tap")
			Events.empty_slot_tapped.emit(slot_id)
			return


func _on_focus_slot(slot_id: String) -> void:
	if _stations.has(slot_id):
		camera.call("focus", _stations[slot_id].position)
	else:
		_pending_focus = slot_id


func _on_station_event(slot_id: String, event: String) -> void:
	if event == "arrived" and _stations.has(slot_id):
		var station: Node2D = _stations[slot_id]
		station.visible = true
		station.play_arrival()
		camera.call("focus", station.position)
		Audio.play("purchase")


## Screen position of a slot, so the HUD can fly coins from the right place.
func slot_screen_position(slot_id: String) -> Vector2:
	if not _stations.has(slot_id):
		return get_viewport_rect().size * 0.5
	var station: Node2D = _stations[slot_id]
	return station.get_global_transform_with_canvas().origin
