extends Node2D
## Workshop dressing.
##
## Plants, boxes and a doormat, every one of them standing on a cell of the
## service band that surrounds the station grid. Because decor is placed by the
## same grid the stations use, it can never wander into a station's space or
## make the rows look uneven — and it grows outward with the room.

var rows: int = 2
var cols: int = 2


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
	_plant(Iso.cell_to_world(-1, cols), 0.95)
	_plant(Iso.cell_to_world(rows, cols), 0.84)
	_mat(Iso.cell_to_world(rows, cols - 1))
	_boxes(Iso.cell_to_world(rows, -1))
	# A longer left-hand walkway earns one more plant.
	if rows >= 3:
		_plant(Iso.cell_to_world(rows - 2, -1), 0.78)


func _plant(at: Vector2, scale_factor: float) -> void:
	IsoDraw.shadow(self, at, 16.0 * scale_factor, 0.10)
	IsoDraw.solid(self, at, 14.0 * scale_factor, 7.0 * scale_factor, 16.0 * scale_factor, Palette.CREAM)
	IsoDraw.diamond(self, at + Vector2(0, -16.0 * scale_factor),
		12.0 * scale_factor, 6.0 * scale_factor, Color("6E5B45"))

	# A fixed fan of leaves — the plant looks the same every time it is drawn.
	var leaves := [
		Vector2(-12.0, -32.0), Vector2(-4.0, -43.0), Vector2(5.0, -41.0),
		Vector2(13.0, -30.0), Vector2(0.0, -26.0),
	]
	var greens := [Color("4FA96E"), Color("5FC98A"), Color("74D69B"), Color("4FA96E"), Color("3F8F5C")]
	var base := at + Vector2(0, -16.0 * scale_factor)
	for i in leaves.size():
		var tip: Vector2 = at + leaves[i] * scale_factor
		draw_colored_polygon(PackedVector2Array([
			base,
			base.lerp(tip, 0.55) + Vector2(-5.5 * scale_factor, 0),
			tip,
			base.lerp(tip, 0.55) + Vector2(5.5 * scale_factor, 0),
		]), greens[i])


func _mat(at: Vector2) -> void:
	IsoDraw.diamond(self, at, 50.0, 25.0, Color("BFD9E6"))
	IsoDraw.diamond(self, at, 43.0, 21.5, Color("A8C9DB"))


func _boxes(at: Vector2) -> void:
	IsoDraw.shadow(self, at, 26.0, 0.10)
	IsoDraw.solid(self, at + Vector2(-6.0, 4.0), 23.0, 11.5, 23.0, Color("D9B487"))
	IsoDraw.solid(self, at + Vector2(-6.0, -19.0), 18.0, 9.0, 18.0, Color("CFA97A"))
	draw_line(at + Vector2(-20.0, -45.0), at + Vector2(8.0, -45.0), Color("B8905F"), 2.0)
