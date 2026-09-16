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
## The inside of an enclosed chamber. Seen through the door, and the reason a
## case reads as a machine with something in it rather than as an empty
## cabinet: without it the back and side panels are lit the same as the lid, so
## the bed and the gantry in front of them have nothing to stand against.
const CHAMBER := Color(0.40, 0.42, 0.46)


static func build(id: String) -> Node3D:
	match id:
		"printer_open":
			return _printer_open()
		"printer_case_p":
			return _printer_case("p", false)
		"printer_glass_p":
			return _printer_case("p", true)
		"printer_case_x":
			return _printer_case("x", false)
		"printer_glass_x":
			return _printer_case("x", true)
		"printer_case_h":
			return _printer_case("h", false)
		"printer_glass_h":
			return _printer_case("h", true)
		"printer_ams":
			return _printer_ams()
		"spool":
			return _spool()
		"spool_reel_clear":
			return _spool_reel("clear")
		"spool_reel_solid":
			return _spool_reel("solid")
		"spool_reel_tech":
			return _spool_reel("tech")
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


## A flat annulus standing in the XY plane, built from segments because a
## torus of this width comes out a fat doughnut rather than a reel flange.
## Twenty-eight segments is a circle at the size these are drawn.
static func _annulus(
	parent: Node3D, z: float, inner: float, outer: float, depth: float,
	color: Color, segments: int = 28
) -> void:
	var mid := (inner + outer) * 0.5
	var band := outer - inner
	# A hair over the exact chord, so neighbouring segments overlap instead of
	# leaving hairline gaps the bake would render as holes.
	var chord := TAU * mid / float(segments) * 1.08
	for i in segments:
		var a := TAU * float(i) / float(segments)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(band, chord, depth)
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = _mat(color)
		node.position = Vector3(cos(a) * mid, sin(a) * mid, z)
		node.rotation_degrees = Vector3(0, 0, rad_to_deg(a))
		parent.add_child(node)


## One spoke of a reel: a bar lying in the XY plane, from `inner` out to
## `outer` at `angle`.
static func _spoke(
	parent: Node3D, z: float, angle: float, inner: float, outer: float,
	width: float, color: Color
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(outer - inner, width, 0.03)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _mat(color)
	var mid := (inner + outer) * 0.5
	node.position = Vector3(cos(angle) * mid, sin(angle) * mid, z)
	node.rotation_degrees = Vector3(0, 0, rad_to_deg(angle))
	parent.add_child(node)


## A thin ring standing in the XY plane — the rim of a spool's flange.
static func _ring(
	parent: Node3D, at: Vector3, inner: float, outer: float, color: Color
) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 24
	mesh.ring_segments = 6
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _mat(color)
	node.position = at
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


## The enclosed machines, one builder for the three families that have one.
##
## They are the same machine growing up, and the differences are the ones a
## player is buying: a P is a plain box, an X adds the camera that watches the
## print and a deeper lid, an H is bigger, stands taller, vents through its
## sides and carries two nozzles. Size comes from the catalogue separately —
## Printer.gd scales the sprite by the model's build volume — so this is about
## silhouette, not scale.
##
## Built in two passes, because the printed part has to be seen through the
## front: `glass_only` returns the pane and the door frame, which the station
## draws after the part.
static func _printer_case(family: String, glass_only: bool) -> Node3D:
	var root := Node3D.new()
	var w := 1.24
	var d := 1.16
	var h := 1.42
	if family == "x":
		w = 1.26
		d = 1.18
		h = 1.50
	elif family == "h":
		w = 1.36
		d = 1.26
		h = 1.66

	if glass_only:
		# Front pane and the door frame around it. Drawn over the print.
		_box(root, Vector3(0, h * 0.52, d * 0.50), Vector3(w * 0.88, h * 0.72, 0.02), GLASS)
		for sx in [-1.0, 1.0]:
			_box(root, Vector3(sx * w * 0.46, h * 0.52, d * 0.49),
				Vector3(0.09, h * 0.84, 0.05), FRAME)
		_box(root, Vector3(0, h * 0.91, d * 0.49), Vector3(w * 0.98, 0.08, 0.05), FRAME)
		# Door handle, so the front reads as a door rather than a window.
		_box(root, Vector3(-w * 0.28, h * 0.52, d * 0.54), Vector3(0.05, 0.24, 0.04), BODY_DARK)
		if family == "h":
			# An H opens as two doors, with a post down the middle.
			_box(root, Vector3(0, h * 0.52, d * 0.51), Vector3(0.05, h * 0.72, 0.04), FRAME)
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

	# The chamber the door looks into. Lining the back and the far side dark is
	# what gives the machine depth: the camera sees one side wall from outside
	# and the other from inside, and the pale bed and gantry only read against
	# something darker than they are.
	_box(root, Vector3(0, h * 0.52, -d * 0.44), Vector3(w * 0.90, h * 0.86, 0.03), CHAMBER)
	_box(root, Vector3(-w * 0.43, h * 0.52, 0), Vector3(0.03, h * 0.86, d * 0.88), CHAMBER)
	_box(root, Vector3(0, 0.115, 0), Vector3(w * 0.90, 0.03, d * 0.88), CHAMBER)

	# Bed and plate, at the same height every machine in the game puts them.
	_box(root, Vector3(0, 0.305, 0), Vector3(w * 0.68, 0.05, d * 0.68), FRAME)
	_box(root, Vector3(0, PLATE_TOP - 0.015, 0), Vector3(w * 0.64, 0.03, d * 0.64), PLATE)
	# The Z rails the gantry climbs, up the back corners of the chamber.
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(sx * w * 0.38, h * 0.50, -d * 0.36), Vector3(0.05, h * 0.78, 0.05),
			BODY_DARK)
	# Gantry rail across the top of the chamber, and the toolhead on it. The
	# rail is light against the dark chamber behind it, and the head is the
	# thing a player looks for to see whether a machine is working.
	_box(root, Vector3(0, h * 0.84, -d * 0.16), Vector3(w * 0.86, 0.06, 0.08), BODY)
	_box(root, Vector3(0, h * 0.79, -d * 0.12), Vector3(0.22, 0.17, 0.12), BODY_DARK)
	_box(root, Vector3(0, h * 0.70, -d * 0.12), Vector3(0.09, 0.06, 0.09), FRAME)
	# Screen on the front-right corner post.
	_box(root, Vector3(w * 0.30, h * 0.20, d * 0.52), Vector3(0.26, 0.17, 0.02), SCREEN)

	if family == "x":
		# The camera that watches the print, on a pod under the lid. It is what
		# the X series is sold on, so it is the thing that must read.
		_box(root, Vector3(-w * 0.30, h * 0.86, d * 0.40), Vector3(0.22, 0.14, 0.14), FRAME)
		_disc(root, Vector3(-w * 0.30, h * 0.86, d * 0.48), 0.05, 0.03, SCREEN)
		# A deeper lid, and the exhaust it needs.
		_box(root, Vector3(0, h * 1.09, 0), Vector3(w * 0.90, 0.06, d * 0.90), BODY_DARK)
		for i in 3:
			_box(root, Vector3(w * 0.49, h * 0.62 - float(i) * 0.14, -d * 0.18),
				Vector3(0.03, 0.06, d * 0.44), FRAME)
	elif family == "h":
		# Two nozzles: an H prints in two materials at once, and that is the
		# whole reason to own one.
		for sx in [-1.0, 1.0]:
			_box(root, Vector3(sx * 0.16, h * 0.74, -d * 0.12), Vector3(0.10, 0.18, 0.10), FRAME)
		# Vented flanks and a heavier plinth, so it reads as shop equipment.
		for i in 5:
			_box(root, Vector3(w * 0.49, h * 0.30, -d * 0.36 + float(i) * 0.14),
				Vector3(0.03, h * 0.34, 0.07), FRAME)
		_box(root, Vector3(0, 0.13, 0), Vector3(w * 1.02, 0.16, d * 1.02), BODY_DARK)
		# A material bay along the top, where an H keeps its spools.
		_box(root, Vector3(0, h * 1.12, -d * 0.10), Vector3(w * 0.94, 0.14, d * 0.52), BODY)
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


## A filament spool, in two pieces.
##
## The colour a player cares about is the filament, and the thing that tells
## PLA from carbon fibre is the reel in front of it. Drawing them as two
## sprites — body tinted by the colour, reel tinted by the material — is not a
## trick: the near flange really is in front of the wind, so drawing it second
## is the correct order, and it means eight materials times nine colours are
## four textures rather than seventy-two.
##
## REEL STYLES. Colour alone cannot separate eight materials at the twenty-odd
## pixels a spool occupies on the rack, so the reel is a different object as
## the materials get more serious — which is also what the real ones look like.
## A commodity filament comes on a thin clear reel you can see the wind
## through; a styrenic on a moulded reel with spokes; an engineering filament
## on a heavy ribbed reel that shows almost none of the wind. Which reel a
## material gets is read off its unlock level (Config.material_reel), so a
## material added to the catalogue arrives with one rather than needing a case
## adding here.
const REEL_R := 0.46
const REEL_Z := 0.19
## Hub radius, as a fraction of the spool. Shared with the body, so a reel's
## spokes land on the hub that is actually there behind them.
const HUB_R := 0.34


static func _spool() -> Node3D:
	var root := Node3D.new()
	_spool_into(root)
	return root


## One reel, in the style a material class ships on. Built almost white: the
## whole thing is multiplied by the material's swatch at draw time.
static func _spool_reel(kind: String) -> Node3D:
	var root := Node3D.new()
	var r := REEL_R
	var z := REEL_Z
	# Inner edge of the flange plate, the number of spokes across the window,
	# and how much of the wind still shows through the middle.
	var inner := 0.84
	var spokes := 0
	var pane := 0.14
	match kind:
		"solid":
			inner = 0.70
			spokes = 4
			pane = 0.22
		"tech":
			inner = 0.58
			spokes = 6
			pane = 0.30

	# The flange plate itself — the material's colour, and the largest thing
	# on the sprite that carries it.
	_annulus(root, z, r * inner, r, 0.05, Color(0.96, 0.96, 0.97))
	# The bead around the outer edge. A reel is moulded, not cut, and the lip
	# is what stops the flange reading as a flat washer.
	_ring(root, Vector3(0, 0, z), r * 0.955, r * 1.02, Color(1.0, 1.0, 1.0))
	# Spokes across the window, out from the hub. Slightly darker than the
	# plate so they read as separate parts of the same moulding.
	for i in spokes:
		_spoke(root, z - 0.005, TAU * float(i) / float(spokes) + PI * 0.25,
			r * HUB_R * 0.92, r * inner, 0.075, Color(0.80, 0.80, 0.82))
	if kind == "tech":
		# A heavy reel is ribbed between its spokes as well.
		_annulus(root, z - 0.008, r * 0.40, r * 0.46, 0.03, Color(0.80, 0.80, 0.82), 20)
	# The window over the wind. Opaque enough to tint the filament behind it —
	# which is the point, a material should shade the colour it comes in — but
	# kept light: the veil is multiplied by the material's swatch too, so a
	# heavy one turns black carbon fibre into a spool with no colour at all.
	_disc(root, Vector3(0, 0, z - 0.012), r * inner, 0.012,
		Color(1.0, 1.0, 1.0, pane))
	return root


## The body: the wind, the far flange, and the hub through the middle.
static func _spool_into(parent: Node3D) -> void:
	var r := REEL_R
	# Built almost white, because the whole spool takes the filament's colour:
	# real spools show the wind through the flange, and at the size this is
	# drawn a coloured disc with a grey hub is what reads as "a spool of red".
	# The wind is a shade under the flanges so the rim still separates.
	_disc(parent, Vector3(0, 0, 0), r * 0.90, 0.34, Color(0.88, 0.88, 0.89))
	# The outer turns of the wind, a touch brighter, so a full spool has a
	# visible edge where the filament is instead of one flat disc of colour.
	_ring(parent, Vector3(0, 0, 0.16), r * 0.80, r * 0.895, Color(1.0, 1.0, 1.0))
	_disc(parent, Vector3(0, 0, -REEL_Z), r, 0.045, Color(1.0, 1.0, 1.0))
	# Hub and the hole through it — what says spool rather than wheel. The core
	# is a shade under the wind rather than dark: it is multiplied by the
	# filament colour as well, and a dark core reads as a hole straight through
	# the middle of every spool in the room.
	_disc(parent, Vector3(0, 0, 0), r * HUB_R, 0.44, Color(0.66, 0.67, 0.69))
	_disc(parent, Vector3(0, 0, 0), r * 0.15, 0.48, Color(0.26, 0.27, 0.30))
