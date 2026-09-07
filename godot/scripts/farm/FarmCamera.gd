extends Camera2D
## Farm camera.
##
## Drag to pan, pinch to zoom, and nothing else. The angle is fixed — there is
## no rotation and no free look — because every sprite in the workshop is drawn
## for one projection. Panning is clamped to the room, so the player can never
## lose the farm off-screen.

signal tapped(world_position: Vector2)

const ZOOM_MIN := 0.40
const ZOOM_MAX := 1.7
## A press shorter and tighter than this counts as a tap, not a drag.
const TAP_MAX_DISTANCE := 14.0
const TAP_MAX_TIME := 0.35

var _bounds: Rect2 = Rect2(-400, -300, 800, 600)
var _touches: Dictionary = {}
var _press_start: Vector2 = Vector2.ZERO
var _press_time: float = 0.0
var _dragging: bool = false
var _pinch_distance: float = 0.0
var _pinch_zoom: float = 1.0
## Vertical nudge, in screen pixels, that keeps the room clear of the chrome.
var _screen_shift: float = 0.0


func _ready() -> void:
	make_current()


## Tell the camera how big the room is and frame it. Called whenever the
## workshop is expanded, so a new tier is immediately visible in full.
## `fit_bounds` is what should be on screen when the room is framed — the
## station grid and a little breathing room. `pan_bounds` is how far the player
## may drag, which is the whole floor including the walkways and fixtures.
func frame_room(
	fit_bounds: Rect2,
	pan_bounds: Rect2,
	viewport: Vector2,
	animate: bool = true,
	screen_shift: float = 0.0
) -> void:
	_bounds = pan_bounds
	_screen_shift = screen_shift
	var bounds := fit_bounds
	# Fit the room's width to the screen. Width is what makes a workshop feel
	# like a room on a phone; if it is also short enough to fit vertically the
	# whole floor is visible, and if not the player pans down to the front row.
	var fit_width: float = viewport.x / maxf(1.0, bounds.size.x)
	var fit_height: float = viewport.y / maxf(1.0, bounds.size.y)
	var fit: float = fit_width if fit_height >= fit_width else maxf(fit_height, fit_width * 0.78)
	# Camera2D zoom is a scale factor: larger means closer.
	var target_zoom: float = clampf(fit, ZOOM_MIN, ZOOM_MAX)
	# Push the view down by half the difference between the HUD and the nav bar
	# so the room sits centred in the strip of screen the player can actually
	# see, not centred behind the chrome.
	offset = Vector2(0.0, _screen_shift / target_zoom)
	var target_position: Vector2 = bounds.get_center()

	if animate and is_node_ready():
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "zoom", Vector2(target_zoom, target_zoom), 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "position", target_position, 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		zoom = Vector2(target_zoom, target_zoom)
		position = target_position
	_clamp_position()


## Glide to a slot — used after buying a machine or unlocking a station.
func focus(world_position: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "position", _clamped(world_position), 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMagnifyGesture:
		_apply_zoom(zoom.x * event.factor)
	elif event is InputEventMouseButton and event.pressed:
		# Desktop convenience; phones use the pinch path above.
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(zoom.x * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(zoom.x * 0.9)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_press_start = event.position
			_press_time = 0.0
			_dragging = false
		elif _touches.size() == 2:
			var points: Array = _touches.values()
			_pinch_distance = points[0].distance_to(points[1])
			_pinch_zoom = zoom.x
	else:
		var was_single := _touches.size() == 1
		_touches.erase(event.index)
		if was_single and not _dragging and _press_time <= TAP_MAX_TIME:
			tapped.emit(get_canvas_transform().affine_inverse() * event.position)


func _handle_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position

	if _touches.size() >= 2:
		var points: Array = _touches.values()
		var distance: float = points[0].distance_to(points[1])
		if _pinch_distance > 1.0:
			_apply_zoom(_pinch_zoom * (distance / _pinch_distance))
		return

	if event.position.distance_to(_press_start) > TAP_MAX_DISTANCE:
		_dragging = true
	# Drag moves the world with the finger, so the pan follows the content.
	position -= event.relative / zoom.x
	_clamp_position()


func _process(delta: float) -> void:
	if _touches.size() == 1 and not _dragging:
		_press_time += delta


func _apply_zoom(next: float) -> void:
	var clamped := clampf(next, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(clamped, clamped)
	offset = Vector2(0.0, _screen_shift / clamped)
	_clamp_position()


## Keep the room on screen. When the room is smaller than the view in an axis,
## lock that axis to the room's centre rather than letting it drift.
func _clamped(target: Vector2) -> Vector2:
	var half := get_viewport_rect().size * 0.5 / zoom.x
	var out := target
	if _bounds.size.x <= half.x * 2.0:
		out.x = _bounds.get_center().x
	else:
		out.x = clampf(out.x, _bounds.position.x + half.x, _bounds.end.x - half.x)
	if _bounds.size.y <= half.y * 2.0:
		out.y = _bounds.get_center().y
	else:
		out.y = clampf(out.y, _bounds.position.y + half.y, _bounds.end.y - half.y)
	return out


func _clamp_position() -> void:
	position = _clamped(position)
