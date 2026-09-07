extends Node
## SERVER TIME.
##
## The device clock is never trusted. Printing progress, deadlines and offline
## catch-up are all measured against the server's clock, which arrives with
## every snapshot as `serverNow`.
##
## Between syncs the clock advances on the engine's monotonic tick counter, not
## on wall time, so changing the phone's date — or the phone sleeping — cannot
## move a print forward or make a deadline pass.

signal synced(server_ms: int)

var _server_ms: int = 0
var _ticks_at_sync: int = 0
var _has_sync: bool = false

## Round-trip of the last sync, used to correct for network latency.
var last_latency_ms: int = 0


## Adopt a server timestamp. `request_started_ticks` lets us credit half the
## round trip so a slow connection does not run the farm behind.
func sync(server_ms: int, request_started_ticks: int = -1) -> void:
	var now_ticks := Time.get_ticks_msec()
	var half_trip := 0
	if request_started_ticks >= 0:
		last_latency_ms = now_ticks - request_started_ticks
		half_trip = int(last_latency_ms / 2.0)
	_server_ms = server_ms + half_trip
	_ticks_at_sync = now_ticks
	_has_sync = true
	synced.emit(_server_ms)


## Current server time in milliseconds.
func now() -> int:
	if not _has_sync:
		return 0
	return _server_ms + (Time.get_ticks_msec() - _ticks_at_sync)


func has_sync() -> bool:
	return _has_sync


## Progress 0..1 of something that started at `started_ms` and runs `duration_ms`.
func progress(started_ms: int, duration_ms: int) -> float:
	if duration_ms <= 0 or started_ms <= 0 or not _has_sync:
		return 0.0
	return clampf(float(now() - started_ms) / float(duration_ms), 0.0, 1.0)


## Milliseconds left, floored at zero.
func remaining(end_ms: int) -> int:
	if not _has_sync:
		return 0
	return maxi(0, end_ms - now())


## "01:14:22" / "14:22" — the countdown format used on stations and orders.
func format_duration(ms: int) -> String:
	var total := int(maxi(0, ms) / 1000.0)
	var hours := int(total / 3600.0)
	var minutes := int(total / 60.0) % 60
	var seconds := total % 60
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, seconds]
	return "%02d:%02d" % [minutes, seconds]


## "2h 15m" — the compact form used on order cards.
func format_short(ms: int) -> String:
	var total := int(maxi(0, ms) / 1000.0)
	var hours := int(total / 3600.0)
	var minutes := int(total / 60.0) % 60
	if hours >= 24:
		return "%dd %dh" % [int(hours / 24.0), hours % 24]
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	if minutes > 0:
		return "%dm" % minutes
	return "%ds" % total
