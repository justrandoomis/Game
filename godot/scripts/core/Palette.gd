extends Node
## DESIGN TOKENS.
##
## A bright, warm workshop palette — deliberately not the dark olive/gold of
## the Levonis store. Every colour in the game comes from here, so the farm,
## the HUD and the screens read as one product.

# Sky and structure
const SKY := Color("8FD3EC")
const SKY_SOFT := Color("C3E9F7")
const SKY_DEEP := Color("4FA3C7")

# Brand accents
const TEAL := Color("3FC0AE")
const TEAL_DEEP := Color("2A9C8C")
const GREEN := Color("5FC98A")
const GREEN_DEEP := Color("3FA46B")
const YELLOW := Color("F8CE4E")
const YELLOW_DEEP := Color("DDAC24")
const ORANGE := Color("F79B3E")
const ORANGE_DEEP := Color("D77A1E")
const CORAL := Color("EF6F61")
const CORAL_DEEP := Color("C94F42")

# Surfaces
const CREAM := Color("FBF8F2")
const PAPER := Color("FFFFFF")
const SAND := Color("F1EBE0")
const LINE := Color("E3DCD0")

# Ink
const INK := Color("23324B")
const INK_SOFT := Color("6C7A92")
const INK_FAINT := Color("A3AEC0")

# Materials in the scene
const WOOD := Color("DCA96A")
const WOOD_MID := Color("C68F51")
const WOOD_DARK := Color("A5713C")
## The wood of the baked KayKit props, sampled from assets/props/. It is the
## same saturation and brightness as WOOD above and a warmer hue — a terracotta
## rather than a honey oak. Anything drawn by hand that touches a baked prop
## uses this, so a painted surface and a modelled one are the same timber.
const PROP_WOOD := Color("D88865")
const PROP_WOOD_DARK := Color("B5674E")
const STEEL := Color("C7D0DA")
const STEEL_MID := Color("A6B2C0")
const STEEL_DARK := Color("7E8B9C")
const FLOOR := Color("F0EDE6")
const FLOOR_ALT := Color("E7E3DA")
const FLOOR_LINE := Color("D8D2C6")

## Status colours, keyed by the server's printer status strings.
const STATUS := {
	"idle": Color("5FC98A"),
	"printing": Color("4FA3C7"),
	"paused": Color("F8CE4E"),
	"maintenance": Color("F79B3E"),
	"failed": Color("EF6F61"),
	"offline": Color("A3AEC0"),
}

## Deadline urgency bands. Colour strengthens as time runs out; never flashes.
const DEADLINE := {
	"normal": Color("4FA3C7"),
	"soon": Color("F8CE4E"),
	"urgent": Color("F79B3E"),
	"critical": Color("EF6F61"),
}

## Machine shells. Every printer is drawn by the same routine — only the
## palette changes, so the fleet stays visually consistent as it grows.
const SKIN := {
	"cream": {"body": Color("E4D8C0"), "trim": Color("8C8069")},
	"charcoal": {"body": Color("4A5262"), "trim": Color("2C323C")},
	"orange": {"body": Color("F0A15A"), "trim": Color("B96C28")},
	"red": {"body": Color("E4695F"), "trim": Color("A8413A")},
	"green": {"body": Color("62B990"), "trim": Color("36795A")},
	"steel": {"body": Color("A7B3C2"), "trim": Color("6C7889")},
}

## Filament colours, matching shared/config/materials.ts.
const FILAMENT := {
	"white": Color("F5F7FA"), "black": Color("3A3F49"), "gray": Color("9AA4B2"),
	"red": Color("EF5B52"), "orange": Color("F79B3E"), "yellow": Color("F6CE4B"),
	"green": Color("54C98A"), "blue": Color("4EA8DE"), "purple": Color("A97BD6"),
}


func filament(color_id: String) -> Color:
	return FILAMENT.get(color_id, INK_FAINT)


func status(id: String) -> Color:
	return STATUS.get(id, INK_FAINT)


func skin(id: String) -> Dictionary:
	return SKIN.get(id, SKIN["cream"])


## Darken for the shaded faces of an isometric solid.
func shade(c: Color, amount: float) -> Color:
	return Color(c.r * (1.0 - amount), c.g * (1.0 - amount), c.b * (1.0 - amount), c.a)


## Lighten for lit faces and highlights.
func tint(c: Color, amount: float) -> Color:
	return Color(
		c.r + (1.0 - c.r) * amount,
		c.g + (1.0 - c.g) * amount,
		c.b + (1.0 - c.b) * amount,
		c.a
	)
