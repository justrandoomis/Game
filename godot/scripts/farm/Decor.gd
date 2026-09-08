extends Node2D
## Workshop dressing.
##
## Plants, packing crates, a rug and a lamp, every one of them standing on a
## cell of the service band that surrounds the station grid. Because decor is
## placed by the same grid the stations use, it can never wander into a
## station's space or make the rows look uneven — and it grows outward with
## the room.
##
## Every piece here is a baked KayKit prop drawn from the shared catalogue, so
## dressing the room costs a few kilobytes and no extra geometry. What is on
## the floor is deliberately sparse: the workshop should read as a place
## someone works, not a showroom.
##
## WHERE DECOR MAY STAND
##
## Decor draws under every station, so a band cell is only usable if no machine
## can cover what stands on it. In this projection cell (row, col) sits exactly
## one tile above cell (row + 1, col + 1) on screen and one tile below
## (row - 1, col - 1), and a station is tall: its machine reaches about 54 px
## above the cell in front of it, and its table and name plate hang about 42 px
## below the cell behind it. So a band cell is clear only when
##
##     (row + 1, col + 1) is not a station    or the bottom of the prop goes
##     (row - 1, col - 1) is not a station    or the top of it does
##
## which leaves exactly six cells, and they are the six this file and the two
## fixtures use:
##
##     (-1, cols - 1)   filament rack        (rows - 1, -1)   maintenance bench
##     (-1, cols)       plant                (rows, -1)       work going out
##     (0, cols)        spare                (rows, 0)        lamp
##
## Everywhere else on the front and right walkways takes anything under ~40 px
## tall — the rug and the small plants — because only the machine behind can
## reach them. The back and left walkways take nothing at all: every cell of
## them has a machine standing in front of it.
##
## This is not theoretical. The lamp used to stand on the left walkway under
## the window, which looks right in an empty workshop and disappears behind
## the machine in front of it as soon as the player fills the room.

const RUG_SCALE := 0.66

var rows: int = 2
var cols: int = 2


func _ready() -> void:
	Props.prepare(self)


func configure(next_rows: int, next_cols: int) -> void:
	rows = maxi(1, next_rows)
	cols = maxi(1, next_cols)
	queue_redraw()


func _draw() -> void:
	# The front walkway, left to right: work waiting to go out, a rug, and
	# something green on the corner.
	_outgoing(Iso.cell_to_world(rows, -1))
	_rug(Iso.cell_to_world(rows, cols - 1))
	_plant(Iso.cell_to_world(rows, cols), "plant_small", 1.0)

	# The far end of the back walkway, beside the filament rack.
	_plant(Iso.cell_to_world(-1, cols), "plant_medium", 0.95)

	# A workshop with room to walk about in earns a lamp — the one tall thing
	# on the floor, so it goes on one of the six cells nothing can cover.
	if rows >= 3:
		Props.draw(self, "lamp", Iso.cell_to_world(rows, 0))


func _plant(at: Vector2, prop: String, scale: float) -> void:
	IsoDraw.shadow(self, at, Props.half_width(prop, scale) * 0.62, 0.10)
	Props.draw(self, prop, at, scale)


func _rug(at: Vector2) -> void:
	# Kept under a tile wide, so the rug dresses the walkway without reading as
	# another floor.
	Props.draw(self, "rug", at, RUG_SCALE)


## Finished work waiting to go out: a pallet, a crate of parts and two packed
## boxes. This is the only place in the room that says the farm ships anything.
func _outgoing(at: Vector2) -> void:
	IsoDraw.shadow(self, at, 30.0, 0.10)
	Props.draw(self, "pallet", at, 0.62)
	Props.draw(self, "crate", at + Vector2(-14.0, -6.0), 0.42)
	Props.draw(self, "box_taped", at + Vector2(18.0, 2.0), 0.78)
	Props.draw(self, "box", at + Vector2(12.0, -16.0), 0.70)
