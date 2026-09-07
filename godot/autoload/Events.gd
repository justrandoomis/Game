extends Node
## Signal bus.
##
## Keeps the farm scene and the UI from having to know about each other: the
## scene emits what the player touched, the UI decides what to open, and the
## FX layer listens for things worth celebrating.

## A station in the farm was tapped. `slot_id` is the grid key.
signal station_tapped(slot_id: String, printer_id: String)
## An empty expansion slot was tapped.
signal empty_slot_tapped(slot_id: String)
## The filament rack or maintenance bench was tapped.
signal fixture_tapped(fixture: String)

## Navigation between the five main screens.
signal navigate(screen: String)
## Ask the camera to centre on a slot (after buying a printer, say).
signal focus_slot(slot_id: String)

## Transient feedback.
signal toast(message: String, kind: String)
## Coins earned somewhere in the world — drives the coin burst toward the HUD.
signal coins_earned(amount: int, world_position: Vector2)
signal level_up(level: int)
## A printer finished, failed or changed state; the station animates.
signal station_event(slot_id: String, event: String)
