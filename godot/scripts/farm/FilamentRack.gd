extends Node2D
## The filament rack on the workshop wall.
##
## Filament does not only exist in a menu: what the player owns is what stands
## on this rack. Spools fill the shelves as stock grows, so buying filament is
## visible in the room.
##
## The shelving is one baked shelf model drawn three times — the rack costs the
## game a single texture however tall it gets. The spools on it are still drawn
## by hand, because each one shows a real colour and a real remaining weight
## that came from the server; a baked sprite could not say that.

const SHELF := "shelf"
const SHELVES := 3
const PER_SHELF := 5
## Vertical pitch between shelves. Comfortably clears a full spool, and three
## of them stay inside the wall they are fixed to.
const SHELF_GAP := 28.0
const BOTTOM_Y := -20.0

## The rack stands on a cell of the back walkway, but it is fixed to the wall
## behind that cell — half a tile up and to the right, which is where the
## right-hand wall runs. Deriving it from the tile rather than typing an offset
## is what keeps the rack on the wall when the room is re-tiled.
const ON_WALL := Vector2(Iso.TILE_W * 0.25, -Iso.TILE_H * 0.25)

const TAP_RECT := Rect2(-56.0, -136.0, 140.0, 162.0)

var _spools: Array = []


func _ready() -> void:
	Props.prepare(self)


## `spools` is the raw server list; only colour and material are used here.
func set_spools(spools: Array) -> void:
	_spools = spools
	queue_redraw()


func contains_point(local_point: Vector2) -> bool:
	return TAP_RECT.has_point(local_point)


func _draw() -> void:
	# The shelves run along the
	# same axis that wall does. Half the shelf's own length is how far a spool
	# at the end sits from the middle — measured from the model, not guessed.
	var reach: Vector2 = Props.along(SHELF, "x") * 0.5
	var plank := Props.top(SHELF)

	# The empty rack, always all of it: an empty shelf is what tells the player
	# there is room for more filament.
	for shelf in SHELVES:
		Props.draw(self, SHELF, _shelf_base(shelf))

	# Spools fill the bottom shelf first, so the rack visibly grows with stock
	# rather than appearing full from the start.
	for index in mini(_spools.size(), SHELVES * PER_SHELF):
		var spool: Dictionary = _spools[index]
		var column: int = index % PER_SHELF
		# Evenly spaced along the plank, inset so none overhangs the end.
		var t := lerpf(-0.80, 0.80, (float(column) + 0.5) / float(PER_SHELF))
		var at := _shelf_base(index / PER_SHELF) + reach * t + Vector2(0, -plank - 8.0)
		var color := Palette.filament(String(spool.get("colorId", "white")))
		var remaining := clampf(
			float(spool.get("grams", 0.0)) / maxf(1.0, float(spool.get("capacity", 1000.0))),
			0.05, 1.0
		)
		IsoDraw.spool(self, at, 5.5 + 3.0 * remaining, color)


func _shelf_base(shelf: int) -> Vector2:
	return ON_WALL + Vector2(0, BOTTOM_Y - float(shelf) * SHELF_GAP)
