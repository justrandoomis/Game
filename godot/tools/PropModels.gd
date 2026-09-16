class_name PropModels
extends RefCounted
## MODELS THE PACKS DO NOT HAVE.
##
## The KayKit packs furnish a workshop but they contain no 3D printer and no
## filament spool, and those two are the things this game is actually about.
## They are built here instead, in code, and go through exactly the same bake
## as every other prop — tools/BakeProps.gd renders them from the game's own
## 2:1 dimetric camera and writes a sprite.
##
## Geometry as code rather than a binary: a printer is boxes and rods, it is
## reviewed in a diff, and a proportion is changed by editing a number rather
## than by opening a modelling package.
##
## SCALE. One unit is one KayKit unit, so these sit alongside the furniture
## without a special case: props bake at 44 px to the unit, and a station table
## is 2 units across. A machine is therefore about 1.2 units wide on a 2-unit
## table, which is the proportion a real printer has on a real workbench.
##
## COLOUR. Shells are built in neutral greys and tinted at draw time by the
## machine's skin (Printer.gd), so the whole fleet — six shell colours across
## two families — costs two textures rather than twelve. Everything that is
## meant to read as a material rather than as paint (the build plate, the
## screen, the rods) is built at a value that still reads as itself once the
## tint is applied.

## Where the build plate's top surface sits above the machine's feet. Printer.gd
## turns this into the pixel height the printed part and the nozzle ride at, so
## the part always lands on the plate rather than near it.
const PLATE_TOP := 0.36

## A NOTE ON WHICH FACES YOU ACTUALLY SEE.
##
## The camera looks down at 30 degrees, so the top of a box is the largest face
## of it on screen — usually larger than both visible sides together. Anything
## given a dark value on top therefore paints the machine dark no matter what
## colour its skin is. Shell tops are light here and only small parts — the
## bed, the rails, the feet, the posts — are dark.

## Neutral values, spread wide on purpose. These are multiplied by a machine's
## skin colour at draw time, so the spread here is what survives as the
## difference between a shell panel and the rail bolted to it. Baked flat and
## close together — the way the KayKit props are — a tinted machine comes out
## as one featureless lump.
const BODY := Color(1.00, 1.00, 1.00)
const BODY_DARK := Color(0.72, 0.73, 0.75)
const FRAME := Color(0.30, 0.31, 0.34)
const RUBBER := Color(0.14, 0.15, 0.17)
const PLATE := Color(0.52, 0.55, 0.60)
const SCREEN := Color(0.26, 0.58, 0.76)
const GLASS := Color(0.84, 0.93, 0.99, 0.28)


static func build(id: String) -> Node3D:
	match id:
		"printer_open":
			return _printer_open()
		"printer_case":
			return _printer_case(false)
		"printer_glass":
			return _printer_case(true)
		"printer_ams":
			return _printer_ams()
		"spool":
			return _spool()
	push_error("PropModels: no builder for %s" % id)
	return null


# ------------------------------------------------------------------ helpers

static func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


## A box with its centre at `at`, sized `size`.
static func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _mat(color)
	node.position = at
	parent.add_child(node)


## An upright cylinder, `height` tall, centred on `at`.
static func _tube(
	parent: Node3D, at: Vector3, radius: float, height: float, color: Color, sides: int = 16
) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _mat(color)
	node.position = at
	parent.add_child(node)


## A disc lying in the XY plane — a spool flange, seen face on.
static func _disc(
	parent: Node3D, at: Vector3, radius: float, thickness: float, color: Color
) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = thickness
	mesh.radial_segments = 24
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _mat(color)
	node.position = at
	# Lay the cylinder on its side so its axis runs along Z, which in this
	# projection points at the room — a spool on a shelf faces the player.
	node.rotation_degrees = Vector3(90, 0, 0)
	parent.add_child(node)


# ------------------------------------------------------------------- models

## The open-frame machine: a bed slinger, which is what every A-series printer
## in the catalogue is. Base with a screen, a plate that slides on it, two rear
## uprights carrying a gantry, and the spool on an arm at the top.
static func _printer_open() -> Node3D:
	var root := Node3D.new()
	var w := 1.22
	var d := 1.12

	# Base: the electronics box the bed rides on. Its top is the biggest face
	# of the machine, so it carries the shell colour.
	_box(root, Vector3(0, 0.16, 0), Vector3(w, 0.32, d), BODY)
	# A recessed channel along it, which is what a bed slinger's Y axis is.
	_box(root, Vector3(0, 0.325, 0), Vector3(w * 0.72, 0.02, d * 0.90), BODY_DARK)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(root, Vector3(sx * w * 0.42, 0.015, sz * d * 0.42),
				Vector3(0.10, 0.03, 0.10), RUBBER)
	# Control screen on the front face, angled up the way a real one is.
	var screen := MeshInstance3D.new()
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(0.34, 0.02, 0.15)
	screen.mesh = screen_mesh
	screen.material_override = _mat(SCREEN)
	screen.position = Vector3(w * 0.24, 0.20, d * 0.51)
	screen.rotation_degrees = Vector3(-74, 0, 0)
	root.add_child(screen)

	# Heated bed and the spring-steel plate on it. Small and dark against the
	# base, which is what makes the base read as the body of a machine.
	_box(root, Vector3(0, 0.345, 0), Vector3(w * 0.66, 0.05, d * 0.66), FRAME)
	_box(root, Vector3(0, PLATE_TOP - 0.015, 0), Vector3(w * 0.62, 0.03, d * 0.62), PLATE)

	# Two rear uprights and the gantry across them. Kept stout and not too
	# tall: thin poles at this size read as a gantry crane rather than as a
	# machine. The beam is lighter than the posts, because its top faces the
	# camera and would otherwise be a black bar across the printer.
	var back_z := -d * 0.38
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(sx * w * 0.41, 0.80, back_z), Vector3(0.19, 0.96, 0.17), FRAME)
	_box(root, Vector3(0, 1.36, back_z), Vector3(w * 1.02, 0.18, 0.26), BODY_DARK)
	_box(root, Vector3(0, 1.25, back_z + 0.14), Vector3(w * 0.94, 0.07, 0.05), FRAME)
	# The X carriage the nozzle hangs off, parked in the middle.
	_box(root, Vector3(0, 1.22, back_z + 0.17), Vector3(0.22, 0.20, 0.10), BODY_DARK)

	# The spool arm, standing on the beam. The spool itself is NOT part of this
	# model: what is loaded on the machine is live data, so the station draws
	# the spool sprite on the arm in the colour the server says is threaded.
	# The recipe's "spool" mount is where it goes.
	_box(root, Vector3(0, 1.50, back_z), Vector3(0.10, 0.12, 0.10), FRAME)
	_box(root, Vector3(0, 1.57, back_z + 0.08), Vector3(0.07, 0.07, 0.24), FRAME)
	return root


## The enclosed machine: P, X and H series. Built in two passes because the
## printed part has to be seen through the front of it — `glass_only` returns
## the panes and the front posts, which the station draws after the part.
static func _printer_case(glass_only: bool) -> Node3D:
	var root := Node3D.new()
	var w := 1.24
	var d := 1.16
	var h := 1.42

	if glass_only:
		# Front pane and the door frame around it. Drawn over the print.
		_box(root, Vector3(0, h * 0.52, d * 0.50), Vector3(w * 0.88, h * 0.72, 0.02), GLASS)
		for sx in [-1.0, 1.0]:
			_box(root, Vector3(sx * w * 0.46, h * 0.52, d * 0.49),
				Vector3(0.09, h * 0.84, 0.05), FRAME)
		_box(root, Vector3(0, h * 0.91, d * 0.49), Vector3(w * 0.98, 0.08, 0.05), FRAME)
		# Door handle, so the front reads as a door rather than a window.
		_box(root, Vector3(-w * 0.28, h * 0.52, d * 0.54), Vector3(0.05, 0.24, 0.04), BODY_DARK)
		return root

	# Case: back and sides, closed, on a dark plinth and under a light lid that
	# overhangs it. The lid is the face the camera sees most of, so it carries
	# the shell colour; the rim under it is what gives the box an edge.
	_box(root, Vector3(0, h * 0.52, -d * 0.48), Vector3(w, h * 0.92, 0.06), BODY)
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(sx * w * 0.47, h * 0.52, 0), Vector3(0.06, h * 0.92, d), BODY_DARK)
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(sx * w * 0.48, h * 0.52, -d * 0.48), Vector3(0.08, h * 0.92, 0.08), FRAME)
	_box(root, Vector3(0, h * 0.975, 0), Vector3(w * 1.08, 0.05, d * 1.08), FRAME)
	_box(root, Vector3(0, h * 1.03, 0), Vector3(w * 1.04, 0.08, d * 1.04), BODY)
	_box(root, Vector3(0, 0.05, 0), Vector3(w * 1.06, 0.10, d * 1.06), FRAME)

	# Bed and plate, at the same height the open machine puts them.
	_box(root, Vector3(0, 0.305, 0), Vector3(w * 0.68, 0.05, d * 0.68), FRAME)
	_box(root, Vector3(0, PLATE_TOP - 0.015, 0), Vector3(w * 0.64, 0.03, d * 0.64), PLATE)
	# Gantry rail across the top of the chamber.
	_box(root, Vector3(0, h * 0.84, -d * 0.16), Vector3(w * 0.86, 0.06, 0.08), BODY_DARK)
	# Screen on the front-right corner post.
	_box(root, Vector3(w * 0.30, h * 0.20, d * 0.52), Vector3(0.26, 0.17, 0.02), SCREEN)
	return root


## The multi-material unit: a box of four spools that sits on the lid.
static func _printer_ams() -> Node3D:
	var root := Node3D.new()
	_box(root, Vector3(0, 0.22, 0), Vector3(1.10, 0.44, 0.86), BODY)
	_box(root, Vector3(0, 0.455, 0), Vector3(1.04, 0.03, 0.80), BODY_DARK)
	# Four spool ends showing through the front, the thing that makes an AMS
	# recognisable at this size.
	for i in 4:
		var x := lerpf(-0.36, 0.36, float(i) / 3.0)
		_disc(root, Vector3(x, 0.24, 0.44), 0.15, 0.03, FRAME)
	return root


## A filament spool: two flanges, the wound filament between them, and the
## hole through the middle. Built white so one texture serves every colour in
## the catalogue — the rack tints it with the filament's own colour.
static func _spool() -> Node3D:
	var root := Node3D.new()
	_spool_into(root)
	return root


static func _spool_into(parent: Node3D) -> void:
	var r := 0.46
	# Built almost white, because the whole spool takes the filament's colour:
	# real spools show the wind through the flange, and at the size this is
	# drawn a coloured disc with a grey hub is what reads as "a spool of red".
	# The wind is a shade under the flanges so the rim still separates.
	_disc(parent, Vector3(0, 0, 0), r * 0.90, 0.34, Color(0.88, 0.88, 0.89))
	for sz in [-1.0, 1.0]:
		_disc(parent, Vector3(0, 0, sz * 0.19), r, 0.045, Color(1.0, 1.0, 1.0))
	# Hub and the hole through it — what says spool rather than wheel. Dark
	# enough to survive being multiplied by a pale filament colour.
	_disc(parent, Vector3(0, 0, 0), r * 0.34, 0.44, Color(0.46, 0.47, 0.50))
	_disc(parent, Vector3(0, 0, 0), r * 0.15, 0.48, Color(0.22, 0.23, 0.26))
