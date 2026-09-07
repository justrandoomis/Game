extends Control
## The bottom sheet.
##
## Mobile's answer to a modal dialog: it slides up over the farm, leaves the
## workshop visible behind it, and is dismissed by tapping away or dragging
## down. Nothing in this game opens a full-screen dialog for a simple action.

signal dismissed()

const MAX_HEIGHT_RATIO := 0.82
const DRAG_DISMISS := 90.0
## Grab handle, panel padding and the safe area below the content.
const CHROME_H := 62.0

var _backdrop: ColorRect
var _panel: PanelContainer
var _content: VBoxContainer
var _drag_start: float = 0.0
var _dragging: bool = false
var _closing: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.09, 0.14, 0.22, 0.0)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	# The panel is positioned by hand rather than by anchors: it has to slide,
	# be dragged, and be capped at a fraction of the screen, and doing all
	# three through anchor offsets fights the layout system.
	_panel = PanelContainer.new()
	var box := UiKit.flat(Palette.CREAM, 0.0)
	box.corner_radius_top_left = 26
	box.corner_radius_top_right = 26
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 22
	box.shadow_color = Color(0.09, 0.14, 0.22, 0.22)
	box.shadow_size = 18
	box.shadow_offset = Vector2(0, -4)
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)

	var column := UiKit.vbox(10)
	_panel.add_child(column)

	# Grab handle — the affordance that says "you can drag this away".
	var handle := Panel.new()
	handle.custom_minimum_size = Vector2(44, 5)
	handle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	handle.add_theme_stylebox_override("panel", UiKit.flat(Palette.LINE, 3.0))
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.gui_input.connect(_on_handle_input)
	column.add_child(handle)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_content = UiKit.vbox(12)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)

	UiKit.apply_direction(self)
	resized.connect(_layout_panel)
	_animate_in()


## Size the panel to its content, capped so it never swallows the whole screen,
## and park it against the bottom edge.
func _layout_panel() -> void:
	if _panel == null or size.y <= 0.0:
		return
	# Measure the content, not the panel: a ScrollContainer reports a tiny
	# minimum height by design, so asking the panel would always collapse the
	# sheet to its floor value.
	var desired: float = _content.get_combined_minimum_size().y + CHROME_H
	var height: float = clampf(desired, 180.0, size.y * MAX_HEIGHT_RATIO)
	_panel.size = Vector2(size.x, height)
	if not _closing:
		_panel.position = Vector2(0.0, size.y - height)


func _rest_y() -> float:
	return size.y - _panel.size.y


## Callers fill this. Everything inside is built with UiKit, so every sheet in
## the game shares one visual language. Sheets that rebuild their body call
## `refit()` afterwards so the panel grows or shrinks to match.
func content() -> VBoxContainer:
	return _content


func refit() -> void:
	await get_tree().process_frame
	if is_instance_valid(self) and not _closing:
		_layout_panel()


## A consistent sheet header: title, optional subtitle, and a close button.
func add_header(title_text: String, subtitle: String = "") -> void:
	var row := UiKit.hbox(8)
	var column := UiKit.vbox(2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(UiKit.title(title_text, UiKit.FONT_TITLE))
	if subtitle != "":
		column.add_child(UiKit.caption(subtitle))
	row.add_child(column)

	var close := Button.new()
	close.custom_minimum_size = Vector2(36, 36)
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_stylebox_override("normal", UiKit.flat(Palette.SAND, 18.0))
	close.add_theme_stylebox_override("pressed", UiKit.flat(Palette.LINE, 18.0))
	var glyph := UiKit.icon("close", Palette.INK_SOFT, 16.0)
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	close.add_child(glyph)
	close.pressed.connect(func():
		Audio.play("tap")
		close_sheet())
	row.add_child(close)
	_content.add_child(row)


func _animate_in() -> void:
	# Wait for the parent container to give this sheet a size before measuring
	# the panel; a sheet built in the same frame it is opened has none yet.
	for i in 4:
		await get_tree().process_frame
		if size.y > 0.0 and _content.get_combined_minimum_size().y > 0.0:
			break
	_layout_panel()
	var rest := _rest_y()
	_panel.position.y = size.y
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_backdrop, "color:a", 0.42, 0.22)
	tween.tween_property(_panel, "position:y", rest, 0.30) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close_sheet() -> void:
	if _closing:
		return
	_closing = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_backdrop, "color:a", 0.0, 0.18)
	tween.tween_property(_panel, "position:y", size.y, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
	dismissed.emit()
	queue_free()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed:
		close_sheet()
	elif event is InputEventMouseButton and event.pressed:
		close_sheet()


## Drag the handle down far enough and the sheet goes away.
func _on_handle_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_dragging = true
			_drag_start = _rest_y()
		else:
			_dragging = false
			if _panel.position.y - _drag_start > DRAG_DISMISS:
				close_sheet()
			else:
				var tween := create_tween()
				tween.tween_property(_panel, "position:y", _drag_start, 0.18) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	elif event is InputEventScreenDrag and _dragging:
		_panel.position.y = maxf(_drag_start, _panel.position.y + event.relative.y)
		_backdrop.color.a = lerpf(0.42, 0.1, clampf((_panel.position.y - _drag_start) / 200.0, 0.0, 1.0))
