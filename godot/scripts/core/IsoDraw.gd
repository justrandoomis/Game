class_name IsoDraw
extends RefCounted
## Isometric drawing primitives.
##
## Every solid in the workshop is built from these two helpers, which is why
## nothing in the farm can end up at a slightly different angle from its
## neighbour. Flat polygons only — no textures, no lighting, no shadow maps —
## so the whole scene stays cheap on a mid-range phone.
##
## Local coordinates: (0, 0) is the centre of the floor tile a thing stands on.
## Height is drawn upward as negative y.

## A box standing on the floor: top face, right face, left face.
## `hw`/`hh` are the half-diagonals of its footprint diamond, `h` its height.
static func box(
	ci: CanvasItem,
	centre: Vector2,
	hw: float,
	hh: float,
	h: float,
	top: Color,
	right: Color,
	left: Color
) -> void:
	var cx := centre.x
	var cy := centre.y
	# Left face (facing lower-left), then right, then the lit top.
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - hw, cy), Vector2(cx, cy + hh),
		Vector2(cx, cy + hh - h), Vector2(cx - hw, cy - h),
	]), left)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(cx, cy + hh), Vector2(cx + hw, cy),
		Vector2(cx + hw, cy - h), Vector2(cx, cy + hh - h),
	]), right)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(cx, cy - hh - h), Vector2(cx + hw, cy - h),
		Vector2(cx, cy + hh - h), Vector2(cx - hw, cy - h),
	]), top)


## A box whose faces are derived from one colour, so callers only pick a hue.
static func solid(ci: CanvasItem, centre: Vector2, hw: float, hh: float, h: float, base: Color) -> void:
	box(ci, centre, hw, hh, h,
		Palette.tint(base, 0.16), Palette.shade(base, 0.10), Palette.shade(base, 0.26))


## A flat diamond on the floor — tiles, rugs, slot outlines, contact shadows.
static func diamond(ci: CanvasItem, centre: Vector2, hw: float, hh: float, fill: Color) -> void:
	ci.draw_colored_polygon(diamond_points(centre, hw, hh), fill)


static func diamond_points(centre: Vector2, hw: float, hh: float) -> PackedVector2Array:
	return PackedVector2Array([
		centre + Vector2(0, -hh), centre + Vector2(hw, 0),
		centre + Vector2(0, hh), centre + Vector2(-hw, 0),
	])


## Outline of a floor diamond. Used for empty expansion slots.
static func diamond_outline(
	ci: CanvasItem, centre: Vector2, hw: float, hh: float, color: Color, width: float = 2.0
) -> void:
	var p := diamond_points(centre, hw, hh)
	var closed := PackedVector2Array([p[0], p[1], p[2], p[3], p[0]])
	ci.draw_polyline(closed, color, width, true)


## Dashed diamond outline, drawn by hand because draw_dashed_line only does
## straight segments and we want the dashes to follow the tile edges exactly.
static func diamond_dashed(
	ci: CanvasItem, centre: Vector2, hw: float, hh: float, color: Color,
	width: float = 2.0, dash: float = 9.0
) -> void:
	var p := diamond_points(centre, hw, hh)
	for i in 4:
		ci.draw_dashed_line(p[i], p[(i + 1) % 4], color, width, dash, true)


## Soft contact shadow. One flattened diamond, cheaper than a blurred sprite.
static func shadow(ci: CanvasItem, centre: Vector2, hw: float, alpha: float = 0.13) -> void:
	var c := Palette.INK
	c.a = alpha
	diamond(ci, centre, hw, hw * 0.5, c)


## A vertical post: a thin box, for table legs and printer uprights.
static func post(ci: CanvasItem, centre: Vector2, thickness: float, h: float, base: Color) -> void:
	solid(ci, centre, thickness, thickness * 0.5, h, base)


## An upright rectangular panel facing the camera's lower-right — printer
## front panels, screens, posters. `w` runs along the right-hand axis.
static func panel_right(
	ci: CanvasItem, origin: Vector2, w: float, h: float, fill: Color
) -> void:
	var step := Vector2(w, -w * 0.5)
	ci.draw_colored_polygon(PackedVector2Array([
		origin, origin + step, origin + step + Vector2(0, -h), origin + Vector2(0, -h),
	]), fill)


## An upright panel facing the camera's lower-left. `w` runs along the left axis.
static func panel_left(
	ci: CanvasItem, origin: Vector2, w: float, h: float, fill: Color
) -> void:
	var step := Vector2(-w, -w * 0.5)
	ci.draw_colored_polygon(PackedVector2Array([
		origin, origin + step, origin + step + Vector2(0, -h), origin + Vector2(0, -h),
	]), fill)


## A filament spool seen edge-on: a disc with a darker hub.
static func spool(ci: CanvasItem, centre: Vector2, radius: float, color: Color) -> void:
	ci.draw_circle(centre, radius, Palette.shade(color, 0.22))
	ci.draw_circle(centre, radius * 0.86, color)
	ci.draw_circle(centre, radius * 0.32, Palette.CREAM)
	ci.draw_circle(centre, radius * 0.16, Palette.shade(color, 0.35))


## A rounded chip behind scene labels, so text stays readable over any floor.
static func chip(ci: CanvasItem, rect: Rect2, fill: Color, radius: float = 6.0) -> void:
	ci.draw_rect(Rect2(rect.position + Vector2(radius, 0), Vector2(rect.size.x - radius * 2.0, rect.size.y)), fill)
	ci.draw_rect(Rect2(rect.position + Vector2(0, radius), Vector2(rect.size.x, rect.size.y - radius * 2.0)), fill)
	ci.draw_circle(rect.position + Vector2(radius, radius), radius, fill)
	ci.draw_circle(rect.position + Vector2(rect.size.x - radius, radius), radius, fill)
	ci.draw_circle(rect.position + Vector2(radius, rect.size.y - radius), radius, fill)
	ci.draw_circle(rect.position + Vector2(rect.size.x - radius, rect.size.y - radius), radius, fill)
