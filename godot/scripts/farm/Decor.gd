extends Node2D
## Workshop dressing.
##
## Plants, packing crates and a rug, every one of them standing on a cell of
## the service band that surrounds the station grid. Because decor is placed by
## the same grid the stations use, it can never wander into a station's space
## or make the rows look uneven — and it grows outward with the room.
##
## Every piece here is a baked KayKit prop drawn from the shared catalogue, so
## dressing the room costs a few kilobytes and no extra geometry. What is on
## the floor is deliberately sparse: the workshop should read as a place
## someone works, not a showroom.

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
	# Nothing tall ever goes on the back corner cell (-1, -1): in this
	# projection that cell sits directly behind station (0, 0), and anything
	# standing there would appear inside the machine's frame. The corner is
	# left as clear walkway instead.
	#
	# Everything else is anchored to a service-band cell, so decor grows
	# outward with the room and never crowds the grid.
	_rug(Iso.cell_to_world(rows, cols - 1))
	_plant(Iso.cell_to_world(-1, cols), "plant_medium", 0.95)
	_plant(Iso.cell_to_world(rows, cols), "plant_small", 1.0)
	_outgoing(Iso.cell_to_world(rows, -1))

	# A longer left-hand walkway earns the things a growing farm needs: a
	# reading lamp over the aisle, and a cabinet to keep filament dry.
	if rows >= 3:
		Props.draw(self, "lamp", Iso.cell_to_world(rows - 2, -1) + Vector2(6.0, 0.0))
	if rows >= 4:
		Props.draw(self, "dry_cabinet", Iso.cell_to_world(rows - 3, -1))


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
