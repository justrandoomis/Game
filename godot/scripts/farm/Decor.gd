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
## Decor draws under everything else in the room, so a walkway cell is only
## usable if nothing can cover what stands on it. In this projection cell
## (row, col) sits exactly one tile above cell (row + 1, col + 1) on screen and
## one tile below (row - 1, col - 1), and the things standing on those cells
## are tall: a station's machine reaches about 54 px above the cell in front of
## it, and its table and name plate hang about 42 px below the cell behind it.
##
## What can cover a prop is not only a station. The filament rack occupies
## (-1, cols - 1) and the maintenance bench (rows - 1, -1), and both are drawn
## in the Fixtures layer above this one. Counting the stations alone is how the
## lamp ended up on (rows, 0) with the bench sitting on exactly the (row - 1,
## col - 1) cell the rule requires to be free, slicing the top of its shade.
##
## Count all three, and a room of any size has exactly two cells clear enough
## for something tall — and they are the two outer corners of the walkway,
## (rows, -1) and (-1, cols), which is precisely where the camera does not
## look: it frames the station grid, so the walkway corners sit at the edge of
## the viewport or past it.
##
## The practical consequence is that this room has no home for a tall floor
## prop. A standing lamp was tried on the left walkway, where it looks right in
## an empty workshop and is sliced in half by a machine in a full one, and then
## on each clear corner, where it is drawn correctly and is off screen. It was
## dropped rather than shipped half-visible.
##
## So everything below is under about 40 px, which the front and right walkways
## take anywhere, because only the thing behind such a cell can reach it. The
## back and left walkways take nothing: every cell of them has a machine or a
## fixture standing in front.

const RUG_SCALE := 0.66
## The rug model bakes to an almost unshaded cyan at the same hue as the sky
## behind the room and at full value, which reads as a puddle on the floor
## rather than as a textile. Knocking the value down and warming it slightly
## puts it back where the mat it replaced sat: a muted blue-grey that is
## clearly darker than the background it is seen against.
const RUG_TONE := Color(0.90, 0.84, 0.78)

var rows: int = 2
var cols: int = 2


## Declared for the boot check — see PrinterStation.prop_ids().
func prop_ids() -> PackedStringArray:
	return PackedStringArray([
		"pallet", "crate", "box", "box_taped", "rug",
		"plant_small", "plant_medium",
	])


func _ready() -> void:
	Props.prepare(self)


func configure(next_rows: int, next_cols: int) -> void:
	rows = maxi(1, next_rows)
	cols = maxi(1, next_cols)
	queue_redraw()


func _draw() -> void:
	# The front walkway, left to right. Work waiting to go out sits under the
	# maintenance bench, which is fine: none of it is more than about 30 px
	# tall, so the bench cannot reach it.
	_outgoing(Iso.cell_to_world(rows, 0))
	_rug(Iso.cell_to_world(rows, cols - 1))
	_plant(Iso.cell_to_world(rows, cols), "plant_small", 1.0)

	# The far end of the back walkway, beside the filament rack. One of the two
	# cells tall enough for a full-size plant.
	_plant(Iso.cell_to_world(-1, cols), "plant_medium", 0.95)

	# A longer front walkway earns one more plant. It reuses a texture the room
	# already holds, and it is short enough for any cell of this walkway.
	if rows >= 3:
		_plant(Iso.cell_to_world(rows, cols - 3), "plant_small", 0.88)


func _plant(at: Vector2, prop: String, scale: float) -> void:
	IsoDraw.shadow(self, at, Props.half_width(prop, scale) * 0.62, 0.10)
	Props.draw(self, prop, at, scale)


func _rug(at: Vector2) -> void:
	# Kept under a tile wide, so the rug dresses the walkway without reading as
	# another floor.
	Props.draw(self, "rug", at, RUG_SCALE, RUG_TONE)


## Finished work waiting to go out: a pallet, a crate of parts and two packed
## boxes. This is the only place in the room that says the farm ships anything.
func _outgoing(at: Vector2) -> void:
	IsoDraw.shadow(self, at, 30.0, 0.10)
	Props.draw(self, "pallet", at, 0.62)
	Props.draw(self, "crate", at + Vector2(-14.0, -6.0), 0.42)
	Props.draw(self, "box_taped", at + Vector2(18.0, 2.0), 0.78)
	Props.draw(self, "box", at + Vector2(12.0, -16.0), 0.70)
