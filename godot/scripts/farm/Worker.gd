extends Node2D
## A workshop employee.
##
## Lightweight on purpose: no navigation mesh, no AI. A worker walks a fixed
## route between points the farm hands it, pauses to "work", and moves on. That
## is enough to make the room feel staffed, and it costs one moving transform.
##
## Employees unlock with the Employees system, so an early workshop is empty
## and hiring is something the player can see happen.

enum Role { OPERATOR, TECHNICIAN, PACKER, MANAGER }

const SPEED := 42.0
const PAUSE_MIN := 2.5
const PAUSE_MAX := 6.0

@export var role: Role = Role.OPERATOR

var _route: Array[Vector2] = []
var _target: int = 0
var _paused: float = 0.0
var _bob: float = 0.0
var _facing: int = 1

const SHIRTS := {
	Role.OPERATOR: Color("4EA8DE"),
	Role.TECHNICIAN: Color("F79B3E"),
	Role.PACKER: Color("5FC98A"),
	Role.MANAGER: Color("A97BD6"),
}


func _ready() -> void:
	set_process(false)


## Give the worker somewhere to walk. Points are in the farm's world space.
func set_route(points: Array[Vector2]) -> void:
	_route = points
	if _route.size() > 1:
		position = _route[0]
		_target = 1
		set_process(true)
	else:
		set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_bob += delta
	if _paused > 0.0:
		_paused -= delta
		queue_redraw()
		return

	var destination: Vector2 = _route[_target]
	var to_target := destination - position
	if to_target.length() < 3.0:
		_target = (_target + 1) % _route.size()
		_paused = randf_range(PAUSE_MIN, PAUSE_MAX)
		return

	var step := to_target.normalized() * SPEED * delta
	position += step
	if absf(step.x) > 0.01:
		_facing = 1 if step.x >= 0.0 else -1
	queue_redraw()


func _draw() -> void:
	var shirt: Color = SHIRTS.get(role, Palette.SKY_DEEP)
	# A gentle bob only while actually walking.
	var walking := _paused <= 0.0
	var bob := (sin(_bob * 9.0) * 1.2) if walking else 0.0

	IsoDraw.shadow(self, Vector2.ZERO, 9.0, 0.16)
	# Legs, body, head — a small readable figure, not a character rig.
	draw_rect(Rect2(-4.0, -15.0 + bob, 3.0, 8.0), Palette.INK_SOFT)
	draw_rect(Rect2(1.0, -15.0 + bob, 3.0, 8.0), Palette.INK_SOFT)
	IsoDraw.chip(self, Rect2(-6.0, -27.0 + bob, 12.0, 14.0), shirt, 4.0)
	draw_circle(Vector2(0, -31.0 + bob), 5.2, Color("F2C9A0"))
	# Cap, tipped in the direction of travel.
	draw_circle(Vector2(0, -33.0 + bob), 5.2, Palette.shade(shirt, 0.15))
	draw_rect(Rect2(_facing * 2.0 - 3.0, -34.0 + bob, 6.0, 2.0), Palette.shade(shirt, 0.25))
