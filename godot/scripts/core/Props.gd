extends Node
## BAKED WORKSHOP PROPS.
##
## The furniture of the farm — tables, walls, shelves, crates, plants — comes
## from KayKit low-poly models that tools/BakeProps.gd has already rendered
## from this game's own fixed 2:1 dimetric camera. What ships is a folder of
## small PNGs, so the workshop costs a phone nothing more than the flat
## polygons it is drawn beside.
##
## Every prop is drawn the same way a hand-drawn solid is: give it a point on
## the grid and it stands on that cell. `draw()` takes the position where the
## middle of the prop's base should land, which is exactly what
## Iso.cell_to_world() returns — so props are placed by the grid and can no
## more drift out of alignment than a station can.
##
##     Props.draw(self, "station_table", Vector2.ZERO)
##     Props.draw(self, "crate", Iso.cell_to_world(row, col), 0.42)
##
## One texture per prop, however many times it is drawn: a workshop of twelve
## stations holds one table image, not twelve.

const CATALOG := "res://assets/props/props.json"
const DIR := "res://assets/props"

## Where one model unit goes on screen, along each of the three model axes.
##
## These are the projection Iso.gd draws by hand, written out once: yaw 45,
## pitch 30, orthographic. Moving a model unit along +X travels down and to the
## right, along +Z down and to the left, along +Y straight up — and the two
## ground axes cover twice the width they do height, which is the game's 148x74
## floor tile. Multiply by a prop's px_per_unit to get pixels.
const AXIS_X := Vector2(0.7071068, 0.3535534)
const AXIS_Z := Vector2(-0.7071068, 0.3535534)
const AXIS_Y := Vector2(0.0, -0.8660254)

var _props: Dictionary = {}
var _textures: Dictionary = {}
## Sprites are baked at this multiple of their on-screen size, so they stay
## sharp when the player pinches in. Everything below divides it back out.
var _supersample: float = 2.0


func _ready() -> void:
	var file := FileAccess.open(CATALOG, FileAccess.READ)
	if file == null:
		push_error("Props: %s is missing — run tools/BakeProps.tscn" % CATALOG)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		push_error("Props: %s is not readable" % CATALOG)
		return
	_supersample = maxf(1.0, float(parsed.get("supersample", 2.0)))
	_props = parsed.get("props", {})


func has(id: String) -> bool:
	return _props.has(id)


func count() -> int:
	return _props.size()


## Of the ids a node says it draws, the ones the catalogue does not have.
## draw() is deliberately silent on an unknown id — it must never crash the
## farm — so this is what turns a renamed or dropped prop into a build failure
## instead of a hole in the room.
func unknown(ids: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for id in ids:
		if not _props.has(id) and not out.has(id):
			out.append(id)
	return out


## The other direction: props that were baked but nothing draws. Not a
## failure — a prop is usually baked a moment before it is wired up — but the
## boot check reports it, because an asset nobody draws is weight in the
## download and a thing the next reader assumes is used somewhere.
func unused(declared: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for id in _props.keys():
		if not declared.has(String(id)):
			out.append(String(id))
	return out


## Catalogued props whose sprite will not load. Empty is the only good answer:
## anything listed here would silently draw nothing in the farm, so the boot
## check (Main.gd, `--selftest`) fails the build on it rather than shipping a
## workshop with a hole in it.
func missing() -> PackedStringArray:
	var out := PackedStringArray()
	for id in _props.keys():
		if _texture(String(id)) == null:
			out.append(String(id))
	return out


## On-screen size of a prop's sprite, before any scaling.
func size(id: String) -> Vector2:
	if not _props.has(id):
		return Vector2.ZERO
	var entry: Dictionary = _props[id]
	return Vector2(float(entry["w"]), float(entry["h"])) / _supersample


## How tall the prop stands above the floor, in screen pixels. A station uses
## this to mount a printer exactly on its table top, so the mount height is
## measured from the model rather than guessed.
func top(id: String, scale: float = 1.0) -> float:
	if not _props.has(id):
		return 0.0
	return float(_props[id]["top"]) * scale


## Half the width of a prop's sprite — enough to size a contact shadow or a
## tap rectangle from the prop itself.
func half_width(id: String, scale: float = 1.0) -> float:
	return size(id).x * 0.5 * scale


## The screen vector spanning a prop from one end to the other along one of its
## own axes. `axis` is "x", "y" or "z".
##
## This is how anything gets laid out on top of a prop without measuring
## pixels: half of along("shelf", "x") is the offset from the middle of a shelf
## to its end, in the same perspective as everything else in the room.
func along(id: String, axis: String, scale: float = 1.0) -> Vector2:
	if not _props.has(id):
		return Vector2.ZERO
	var entry: Dictionary = _props[id]
	var step := AXIS_X
	var extent := float(entry.get("sx", 0.0))
	match axis:
		"y":
			step = AXIS_Y
			extent = float(entry.get("sy", 0.0))
		"z":
			step = AXIS_Z
			extent = float(entry.get("sz", 0.0))
	return step * (extent * float(entry["px_per_unit"]) * scale)


## Draw a prop standing on `at`, which is where the middle of its base lands.
##
## `scale` is for props whose model is not the size the scene wants — a produce
## crate makes a good small parts bin at 0.4 — and costs nothing, because it is
## the same texture drawn smaller.
func draw(
	canvas: CanvasItem,
	id: String,
	at: Vector2,
	scale: float = 1.0,
	modulate: Color = Color.WHITE
) -> void:
	if not _props.has(id):
		return
	var texture := _texture(id)
	if texture == null:
		return
	var entry: Dictionary = _props[id]
	var factor := scale / _supersample
	var origin := at - Vector2(float(entry["ax"]), float(entry["ay"])) * factor
	var extent := Vector2(float(entry["w"]), float(entry["h"])) * factor
	canvas.draw_texture_rect(texture, Rect2(origin, extent), false, modulate)


## Props are baked larger than they are shown, so they need mipmaps to stay
## quiet while the camera zooms. Nodes that draw props call this once.
func prepare(canvas: CanvasItem) -> void:
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _texture(id: String) -> Texture2D:
	if _textures.has(id):
		return _textures[id]
	var path := "%s/%s.png" % [DIR, id]
	if not ResourceLoader.exists(path):
		push_error("Props: %s has no sprite — run tools/BakeProps.tscn" % id)
		_textures[id] = null
		return null
	var texture: Texture2D = load(path)
	_textures[id] = texture
	return texture
