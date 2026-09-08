extends Node2D
## The game shell.
##
## Owns the farm, the HUD, the five screens and the sheets, and routes what the
## player touches to the right place. It holds no game rules: every action is
## an intent sent to the server, and every number on screen came back from it.

const FarmScene := preload("res://scenes/farm/Farm.tscn")
const PrinterSheetScript := preload("res://scripts/ui/PrinterSheet.gd")
const AddStationSheetScript := preload("res://scripts/ui/AddStationSheet.gd")
const AssignSheetScript := preload("res://scripts/ui/AssignSheet.gd")
const BuyFilamentSheetScript := preload("res://scripts/ui/BuyFilamentSheet.gd")
const ProduceSheetScript := preload("res://scripts/ui/ProduceSheet.gd")
const SettingsSheetScript := preload("res://scripts/ui/SettingsSheet.gd")
const AwayReportSheetScript := preload("res://scripts/ui/AwayReportSheet.gd")

## How often the client asks the server for a fresh snapshot. Prints run for
## hours, so this is about picking up finished work, not about smoothness —
## progress bars interpolate locally from the server's timestamps.
const REFRESH_SECONDS := 45.0

@onready var farm: Node2D = $Farm
@onready var ui: CanvasLayer = $UI
@onready var screens: Control = $UI/Screens
@onready var hud: Control = $UI/TopHUD
@onready var nav: Control = $UI/BottomNav
@onready var sheets: Control = $UI/Sheets
@onready var fx: Control = $UI/Fx
@onready var tutorial: Control = $UI/Tutorial
@onready var boot_overlay: Control = $UI/Boot

var _screens: Dictionary = {}
var _current: String = "farm"
var _tick := 0.0
var _refresh_timer := 0.0
var _active_sheet: Control = null


func _ready() -> void:
	_build_screens()
	hud.settings_pressed.connect(_open_settings)
	nav.selected.connect(_show_screen)
	fx.hud_anchor = func(): return hud.coin_anchor()

	Events.navigate.connect(_on_navigate)
	Events.station_tapped.connect(_on_station_tapped)
	Events.empty_slot_tapped.connect(_on_empty_slot_tapped)
	Events.fixture_tapped.connect(_on_fixture_tapped)
	GameState.away_report.connect(_on_away_report)
	GameState.fx.connect(_on_fx)
	Net.unauthorized.connect(_on_unauthorized)
	I18n.language_changed.connect(func(_lang): UiKit.apply_direction(screens))

	_show_screen("farm")
	_boot()


## `--  --selftest` boots the client against the configured backend, prints what
## it got back and exits. Used by CI to prove the client and server still agree
## without needing a display.
func _run_selftest() -> void:
	var missing_props := Props.missing()
	var unknown_props := Props.unknown(_declared_prop_ids(farm))
	var summary := {
		"api": Net.base_url(),
		"config_loaded": Config.is_loaded,
		"props": Props.count(),
		"props_missing": missing_props,
		"props_unknown": unknown_props,
		"state_loaded": GameState.ready_state,
		"clock_synced": ServerClock.has_sync(),
		"level": GameState.level(),
		"coins": GameState.coins(),
		"printers": GameState.printers().size(),
		"spools": GameState.spools().size(),
		"offers": GameState.offered_orders().size(),
		"slots": GameState.unlocked_slots().size(),
		"stations_built": farm.get_node("World/Stations").get_child_count(),
	}
	print("SELFTEST ", JSON.stringify(summary))
	# A workshop with unbaked props renders holes rather than failing, so the
	# boot check is where that has to be caught.
	var ok := GameState.ready_state and Props.count() > 0 \
		and missing_props.is_empty() and unknown_props.is_empty()
	get_tree().quit(0 if ok else 1)


## `-- --screenshot=path.png [--screen=orders]` renders one frame to disk.
## Used to review the game's look without a device attached.
func _capture(path: String) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screen="):
			_on_navigate(arg.substr(9))
	# Give tweens, layout and the first live tick a moment to settle.
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if OS.get_cmdline_user_args().has("--debug-ui"):
		var screen: Control = _screens.get(_current, null)
		print("DEBUG current=", _current, " screens.visible=", screens.visible)
		if screen != null:
			print("DEBUG screen rect=", screen.get_rect(), " visible=", screen.visible,
				" children=", screen.get_child_count())
			for child in screen.get_children():
				print("   child ", child.get_class(), " rect=", (child as Control).get_rect() if child is Control else "-")
				if child.get_child_count() > 0:
					var g := child.get_child(0)
					print("      inner ", g.get_class(), " rect=", (g as Control).get_rect() if g is Control else "-",
						" kids=", g.get_child_count())
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	print("SCREENSHOT ", path)
	get_tree().quit()


## Every prop id the farm says it draws. Nodes declare them in prop_ids();
## the boot check then proves each one is in the baked catalogue.
func _declared_prop_ids(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if node.has_method("prop_ids"):
		out.append_array(node.call("prop_ids"))
	for child in node.get_children():
		out.append_array(_declared_prop_ids(child))
	return out


## Bring the game up: balancing data, then the farm.
func _boot() -> void:
	_set_boot_state(I18n.t("loading"), false)
	var ok := await GameState.boot()
	if ok:
		boot_overlay.visible = false
	else:
		_set_boot_state(I18n.t("connection_error"), true)
	var args := OS.get_cmdline_user_args()
	if args.has("--selftest"):
		await get_tree().process_frame
		_run_selftest()
	for arg in args:
		if arg.begins_with("--screenshot="):
			await _capture(arg.substr(13))


func _set_boot_state(message: String, show_retry: bool) -> void:
	boot_overlay.visible = true
	for child in boot_overlay.get_children():
		child.queue_free()

	var backdrop := ColorRect.new()
	backdrop.color = Palette.SKY_SOFT
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	boot_overlay.add_child(backdrop)

	# A CenterContainer does the centring, so nothing here depends on measuring
	# the column after a frame has passed.
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	boot_overlay.add_child(centre)

	var column := UiKit.vbox(14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(column)

	var glyph := UiKit.icon("printer", Palette.SKY_DEEP, 64.0)
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(glyph)

	var label := UiKit.label(message, UiKit.FONT_BODY, Palette.INK_SOFT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)

	if show_retry:
		var retry := UiKit.button(I18n.t("retry"), "primary")
		retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		retry.pressed.connect(_boot)
		column.add_child(retry)


func _build_screens() -> void:
	for entry in [
		{"id": "orders", "script": "res://scripts/ui/screens/OrdersScreen.gd"},
		{"id": "shop", "script": "res://scripts/ui/screens/ShopScreen.gd"},
		{"id": "inventory", "script": "res://scripts/ui/screens/InventoryScreen.gd"},
		{"id": "upgrades", "script": "res://scripts/ui/screens/UpgradesScreen.gd"},
	]:
		var node := MarginContainer.new()
		node.set_script(load(String(entry["script"])))
		node.visible = false
		screens.add_child(node)
		_screens[String(entry["id"])] = node


## The farm is a scene, the other four are screens over it. Hiding the farm
## while a screen is open keeps a phone from drawing a workshop nobody can see.
func _show_screen(id: String) -> void:
	_current = id
	farm.visible = id == "farm"
	farm.process_mode = Node.PROCESS_MODE_INHERIT if id == "farm" else Node.PROCESS_MODE_DISABLED
	screens.visible = id != "farm"
	tutorial.visible = id == "farm"
	for key in _screens.keys():
		_screens[key].visible = key == id
	if id != "farm" and nav.current != id:
		nav.select(id)


## Navigation requests can carry an argument, which is how a screen asks for a
## sheet without knowing anything about how sheets are built.
func _on_navigate(target: String) -> void:
	if target.begins_with("assign:"):
		var sheet: Control = _open_sheet(AssignSheetScript)
		sheet.open(target.substr(7))
		return
	if target.begins_with("produce:"):
		var sheet: Control = _open_sheet(ProduceSheetScript)
		sheet.open(target.substr(8))
		return
	if target == "buy_filament":
		_open_sheet(BuyFilamentSheetScript).open()
		return
	_show_screen(target)


func _on_station_tapped(_slot_id: String, printer_id: String) -> void:
	if printer_id == "":
		return
	var sheet: Control = _open_sheet(PrinterSheetScript)
	sheet.open(printer_id)


func _on_empty_slot_tapped(slot_id: String) -> void:
	var sheet: Control = _open_sheet(AddStationSheetScript)
	sheet.open(slot_id)


func _on_fixture_tapped(fixture: String) -> void:
	match fixture:
		"rack":
			_show_screen("inventory")
		"bench":
			# The bench opens the machine that most needs looking at.
			var printers := GameState.printers().duplicate()
			printers.sort_custom(func(a, b): return float(a.get("health", 100)) < float(b.get("health", 100)))
			if printers.is_empty():
				return
			var sheet: Control = _open_sheet(PrinterSheetScript)
			sheet.open(String(printers[0].get("id", "")))


## One sheet at a time. Opening a second closes the first.
func _open_sheet(script: Script) -> Control:
	if _active_sheet != null and is_instance_valid(_active_sheet):
		_active_sheet.close_sheet()
	var sheet := Control.new()
	sheet.set_script(script)
	sheets.add_child(sheet)
	_active_sheet = sheet
	sheet.dismissed.connect(func(): _active_sheet = null)
	return sheet


func _open_settings() -> void:
	_open_sheet(SettingsSheetScript).open()


func _on_away_report(report: Dictionary) -> void:
	_open_sheet(AwayReportSheetScript).open(report)


## Small hints the server attaches to a successful intent.
func _on_fx(kind: String, value: Variant, at: String) -> void:
	match kind:
		"coins":
			if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
				Events.coins_earned.emit(int(value), get_viewport_rect().size * Vector2(0.5, 0.55))
		"job_started":
			Audio.play("print_start")
		"slot_unlocked":
			Audio.play("expand")
			if at != "":
				Events.focus_slot.emit(at)
		"printer_delivered":
			if at != "":
				Events.focus_slot.emit(at)
		"workshop_expanded":
			Audio.play("expand")
			Events.toast.emit(I18n.t("expand_workshop"), "success")


func _on_unauthorized() -> void:
	_set_boot_state(I18n.t("connection_error"), true)


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 1.0:
		_tick = 0.0
		_tick_screens()

	# Poll for work the server has finished while the app was open. Prints run
	# for hours; there is nothing to gain from asking more often than this.
	_refresh_timer += delta
	if _refresh_timer >= REFRESH_SECONDS and GameState.ready_state and not GameState.is_busy():
		_refresh_timer = 0.0
		await GameState.refresh()


func _tick_screens() -> void:
	var screen: Control = _screens.get(_current, null)
	if screen != null and screen.visible and screen.has_method("tick"):
		screen.tick()
	if _active_sheet != null and is_instance_valid(_active_sheet) and _active_sheet.has_method("tick"):
		_active_sheet.tick()


## Coming back from the background is the moment offline progress lands.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and GameState.ready_state:
		_refresh_timer = 0.0
		GameState.refresh(true)
