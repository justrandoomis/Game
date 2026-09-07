class_name Shapes
extends RefCounted
## Printed-model silhouettes.
##
## A model on the build plate is drawn as a stack of thin isometric slabs, and
## only the layers printed so far are drawn. That gives the part genuinely
## appearing layer by layer as the job runs — the satisfying bit of watching a
## printer — without slicing anything or rendering a mesh.
##
## Each profile is a radius per layer, bottom to top, in units of the plate's
## half-width. Purely visual: the server decides what was actually produced.

const LAYERS := 10

const PROFILES := {
	# Flat, wide, done in a couple of layers.
	"keychain":    [0.72, 0.70, 0.30],
	"clip":        [0.42, 0.44, 0.40, 0.20],
	# Creature shapes: a body that tapers to a head.
	"dino":        [0.60, 0.72, 0.68, 0.52, 0.30, 0.26, 0.30, 0.46, 0.40, 0.18],
	"figure":      [0.46, 0.42, 0.34, 0.32, 0.36, 0.34, 0.24, 0.40, 0.36, 0.16],
	"articulated": [0.58, 0.64, 0.44, 0.56, 0.42, 0.54, 0.40, 0.50, 0.34, 0.20],
	# Vessels flare outward toward the rim.
	"pot":         [0.44, 0.50, 0.56, 0.62, 0.66, 0.70, 0.72, 0.74, 0.76, 0.72],
	"lamp":        [0.34, 0.42, 0.52, 0.60, 0.66, 0.72, 0.76, 0.78, 0.80, 0.78],
	"bin":         [0.78, 0.78, 0.78, 0.78, 0.76, 0.76, 0.74, 0.74, 0.72, 0.66],
	"tray":        [0.80, 0.80, 0.78, 0.76, 0.40, 0.36, 0.30],
	# Wedges and brackets: a broad base leaning back.
	"stand":       [0.72, 0.68, 0.60, 0.52, 0.44, 0.36, 0.30, 0.24, 0.18, 0.12],
	"bracket":     [0.70, 0.66, 0.44, 0.40, 0.36, 0.34, 0.32, 0.30, 0.26, 0.20],
	"case":        [0.66, 0.66, 0.64, 0.62, 0.60, 0.58, 0.54, 0.48, 0.36, 0.20],
	# Mechanical parts stay squat and even.
	"gear":        [0.68, 0.70, 0.70, 0.66, 0.30, 0.28],
	"frame":       [0.80, 0.78, 0.72, 0.40, 0.36, 0.32, 0.30],
	"enclosure":   [0.74, 0.74, 0.72, 0.70, 0.68, 0.66, 0.64, 0.60, 0.52, 0.34],
	# The little test boat: a hull with a cabin.
	"boat":        [0.56, 0.70, 0.74, 0.48, 0.36, 0.34, 0.32, 0.20],
}

const DEFAULT_PROFILE := [0.60, 0.62, 0.58, 0.52, 0.46, 0.40, 0.34, 0.28, 0.22, 0.14]


static func profile(icon: String) -> Array:
	return PROFILES.get(icon, DEFAULT_PROFILE)


## How tall the finished part stands, so the printhead can ride above it.
static func height(icon: String, layer_height: float) -> float:
	return profile(icon).size() * layer_height


## Draw the part on a plate centred at `origin`, revealed to `progress` (0..1).
## `half_width` is the plate's horizontal half-diagonal.
static func draw_model(
	ci: CanvasItem,
	origin: Vector2,
	half_width: float,
	icon: String,
	color: Color,
	progress: float,
	layer_height: float = 3.4
) -> void:
	var prof: Array = profile(icon)
	var total: int = prof.size()
	var shown: int = clampi(int(ceil(progress * total)), 0, total)
	if shown <= 0:
		return

	var top := Palette.tint(color, 0.20)
	var right := Palette.shade(color, 0.08)
	var left := Palette.shade(color, 0.26)

	for i in shown:
		var r: float = float(prof[i])
		var hw: float = half_width * r
		var hh: float = hw * 0.5
		var y: float = origin.y - float(i) * layer_height
		# Only the topmost visible slab needs its lit face; the ones below are
		# hidden by the slab above, so we skip their top polygon.
		if i == shown - 1:
			IsoDraw.box(ci, Vector2(origin.x, y), hw, hh, layer_height, top, right, left)
		else:
			IsoDraw.box(ci, Vector2(origin.x, y), hw, hh, layer_height, right, right, left)


## Compact icon of a product for order cards and shop rows, drawn flat-on.
static func draw_icon(ci: CanvasItem, centre: Vector2, size: float, icon: String, color: Color) -> void:
	var prof: Array = profile(icon)
	var layer_h: float = size / float(maxi(1, prof.size()))
	var base := centre + Vector2(0, size * 0.42)
	for i in prof.size():
		var r: float = float(prof[i])
		var hw: float = size * 0.5 * r
		IsoDraw.box(
			ci, Vector2(base.x, base.y - float(i) * layer_h), hw, hw * 0.5, layer_h,
			Palette.tint(color, 0.20), Palette.shade(color, 0.08), Palette.shade(color, 0.26)
		)
