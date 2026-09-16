class_name Reel
extends RefCounted
## THE REEL A FILAMENT COMES ON.
##
## Nine colours are easy to tell apart and eight materials are not: at the
## twenty-odd pixels a spool occupies on the workshop rack, a swatch is a
## couple of pixels and every material looks like the same object painted
## differently. So the material is carried by the reel's shape as well as its
## colour, the way it is on a real shelf — commodity filament on a thin clear
## reel you can see the wind through, styrenics on a moulded reel with spokes,
## engineering filament on a heavy ribbed reel that shows almost none of it.
##
## Three reels, not eight: they are classes of filament, and which class a
## material falls into is read off the catalogue (Config.material_reel) rather
## than listed anywhere, so a material added on the server arrives with a reel.
##
## The farm draws reels as baked sprites and the UI draws them as vectors, so
## the numbers that define each one live here and both sides read the same
## ones. tools/PropModels.gd builds the sprites from these same proportions.

## The baked sprite for each class — see tools/prop_recipes.json.
const PROPS := {
	"clear": "spool_reel_clear",
	"solid": "spool_reel_solid",
	"tech": "spool_reel_tech",
}

## Where the flange plate's inner edge sits, as a fraction of the reel radius.
## A heavier reel covers more of the wind.
const INNER := {"clear": 0.84, "solid": 0.70, "tech": 0.58}
## Spokes across the window.
const SPOKES := {"clear": 0, "solid": 4, "tech": 6}
## How much the window over the wind veils the filament colour behind it.
const PANE := {"clear": 0.14, "solid": 0.22, "tech": 0.30}


## The class of reel a material ships on.
static func style(material_id: String) -> String:
	var kind := Config.material_reel(material_id)
	return kind if PROPS.has(kind) else "clear"


## The baked prop the farm draws for a material's spools.
static func prop(material_id: String) -> String:
	return String(PROPS[style(material_id)])


## Every reel sprite, for the boot check.
static func prop_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id in PROPS.values():
		out.append(String(id))
	return out


## The colour a material's reel is moulded in.
static func tint(material_id: String) -> Color:
	return Palette.reel(Config.material_tint(material_id))


## Draw a spool face-on, at `centre` with radius `r`: the wind in the filament
## colour, then the material's reel over it. This is the UI's copy of what the
## farm draws with sprites, and it is the one place a spool icon is drawn, so a
## spool in the inventory, in the shop and on a job card are the same object.
static func draw_face(
	ci: CanvasItem, centre: Vector2, r: float, material_id: String,
	color: Color, fill: float
) -> void:
	var kind := style(material_id)
	var reel: Color = tint(material_id)
	var inner: float = float(INNER[kind])
	var spokes: int = int(SPOKES[kind])

	# The wind, shrinking toward the hub as the spool is used. Drawn first and
	# full width, because the reel in front is what crops it.
	ci.draw_circle(centre, r * 0.92, Palette.shade(color, 0.22))
	var wind: float = lerpf(r * 0.36, r * 0.90, clampf(fill, 0.0, 1.0))
	ci.draw_circle(centre, wind, color)

	# The reel over it: the window first, so the wind reads through the
	# material's own colour, then the flange plate, then the bead on its edge.
	ci.draw_circle(centre, r * inner, Color(reel.r, reel.g, reel.b, float(PANE[kind])))
	ci.draw_arc(centre, r * (1.0 + inner) * 0.5, 0.0, TAU, 40, reel, r * (1.0 - inner))
	ci.draw_arc(centre, r * 0.98, 0.0, TAU, 40, Palette.shade(reel, 0.18), maxf(1.0, r * 0.07))
	for i in spokes:
		var a := TAU * float(i) / float(spokes) + PI * 0.25
		ci.draw_line(
			centre + Vector2(cos(a), sin(a)) * r * 0.30,
			centre + Vector2(cos(a), sin(a)) * r * inner,
			reel, maxf(1.0, r * 0.13)
		)
	# Hub and the hole through it.
	ci.draw_circle(centre, r * 0.30, Palette.shade(reel, 0.10))
	ci.draw_circle(centre, r * 0.16, Palette.CREAM)
	ci.draw_arc(centre, r * 0.16, 0.0, TAU, 20, Palette.LINE, 1.0)
