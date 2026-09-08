extends Node2D
## THE PROP BAKER.
##
## Turns KayKit glTF models into flat sprites that already stand on the game's
## grid. Run it when tools/prop_recipes.json changes; the game itself never
## loads a mesh.
##
##     godot --path godot res://tools/BakeProps.tscn
##
## Why bake at all. The farm is a 2D scene drawn from one fixed 2:1 dimetric
## projection (scripts/core/Iso.gd). A model rendered through an orthographic
## camera set to that same projection produces a sprite that is, pixel for
## pixel, in the same perspective as everything drawn by hand around it — so a
## KayKit table and a hand-drawn printer share one vanishing point and one
## grid. It also means the shipped game carries a few hundred kilobytes of PNG
## instead of meshes, materials and a 3D renderer, which is what makes this
## affordable on a phone and in a browser.
##
## Output: assets/props/<id>.png plus assets/props/props.json, which records
## each sprite's size and its anchor — the pixel inside the sprite that must
## land on a grid position. Both are committed.

const RECIPES := "res://tools/prop_recipes.json"
const OUT_DIR := "res://assets/props"

## The projection. Identical to the one Iso.gd draws by hand: yaw 45 degrees,
## pitch 30 degrees, orthographic. A floor square then projects to a diamond
## exactly twice as wide as it is tall, which is the game's 148x74 tile.
const CAM_PITCH := -30.0
const CAM_YAW := 45.0

## Transparent margin kept around each sprite so no edge pixel is clipped by
## rounding, and so linear filtering at small zoom fades into nothing.
const PAD_PX := 6


func _ready() -> void:
	var recipes := _load_recipes()
	if recipes.is_empty():
		push_error("BakeProps: no recipes")
		get_tree().quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var supersample: float = float(recipes.get("supersample", 2.0))
	var scales: Dictionary = recipes.get("scales", {})
	var catalog := {}

	for recipe in recipes.get("props", []):
		var entry := await _bake(recipe, scales, supersample)
		if entry.is_empty():
			get_tree().quit(1)
			return
		catalog[String(recipe["id"])] = entry
		print("baked %-14s %dx%d  anchor %d,%d" % [
			recipe["id"], entry["w"], entry["h"], entry["ax"], entry["ay"]
		])

	var manifest := {
		"generated_by": "tools/BakeProps.gd from tools/prop_recipes.json — do not hand-edit",
		"supersample": supersample,
		"props": catalog,
	}
	var file := FileAccess.open("%s/props.json" % OUT_DIR, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t", true) + "\n")
	file.close()

	print("BAKED %d props" % catalog.size())
	get_tree().quit()


func _load_recipes() -> Dictionary:
	var file := FileAccess.open(RECIPES, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


## Render one model and write its sprite. Returns its catalog entry.
func _bake(recipe: Dictionary, scales: Dictionary, supersample: float) -> Dictionary:
	var id := String(recipe["id"])
	var path := "res://assets/kaykit/%s.gltf" % String(recipe["src"])
	if not ResourceLoader.exists(path):
		push_error("BakeProps: missing model %s" % path)
		return {}

	var scene: PackedScene = load(path)
	var inst: Node3D = scene.instantiate()
	inst.rotation_degrees = Vector3(0, float(recipe.get("yaw", 0.0)), 0)

	# Pixels per model unit, at bake resolution. The sprite is drawn back down
	# by `supersample` at runtime, so it stays crisp when the camera zooms in.
	var px_per_unit: float = float(scales.get(String(recipe.get("scale", "prop")), 44.0))
	var k: float = px_per_unit * supersample

	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	viewport.add_child(inst)
	_flatten(inst)
	_light(viewport)

	var bounds := _scene_aabb(inst)
	var basis := Basis.from_euler(
		Vector3(deg_to_rad(CAM_PITCH), deg_to_rad(CAM_YAW), 0.0), EULER_ORDER_YXZ
	)

	# Fit the model in camera space: u runs screen-right, v screen-up, w toward
	# the camera. Everything below is plain orthographic projection.
	var u_min := INF
	var u_max := -INF
	var v_min := INF
	var v_max := -INF
	var w_max := -INF
	for i in 8:
		var corner := bounds.get_endpoint(i)
		u_min = minf(u_min, corner.dot(basis.x))
		u_max = maxf(u_max, corner.dot(basis.x))
		v_min = minf(v_min, corner.dot(basis.y))
		v_max = maxf(v_max, corner.dot(basis.y))
		w_max = maxf(w_max, corner.dot(basis.z))

	var width := int(ceil((u_max - u_min) * k)) + PAD_PX * 2
	var height := int(ceil((v_max - v_min) * k)) + PAD_PX * 2
	viewport.size = Vector2i(width, height)

	# The camera looks at the centre of that fitted box, from outside it.
	var centre_u := (u_min + u_max) * 0.5
	var centre_v := (v_min + v_max) * 0.5
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = float(height) / k
	camera.rotation_degrees = Vector3(CAM_PITCH, CAM_YAW, 0)
	camera.position = basis.x * centre_u + basis.y * centre_v + basis.z * (w_max + 20.0)
	camera.near = 0.01
	camera.far = (w_max - _min_w(bounds, basis)) + 60.0
	viewport.add_child(camera)

	# Two frames: one to build the render target, one to draw into it.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.save_png("%s/%s.png" % [OUT_DIR, id])

	# The anchor is the middle of the model's base: centre in the ground plane,
	# bottom in height. Putting that pixel on a grid position is what makes a
	# sprite stand on a cell the same way a hand-drawn solid does.
	var base := Vector3(
		bounds.position.x + bounds.size.x * 0.5,
		bounds.position.y,
		bounds.position.z + bounds.size.z * 0.5
	)
	var anchor_x: float = (base.dot(basis.x) - centre_u) * k + float(width) * 0.5
	var anchor_y: float = float(height) * 0.5 - (base.dot(basis.y) - centre_v) * k

	# How far the model's top rises above its base, on screen. A station reads
	# this to know where a printer's feet meet the table, so the mount height
	# comes from the model itself and not from a number somebody typed.
	var top := Vector3(base.x, bounds.position.y + bounds.size.y, base.z)
	var top_px: float = (base.dot(basis.y) - top.dot(basis.y)) * px_per_unit

	viewport.queue_free()
	return {
		"w": width,
		"h": height,
		"ax": snappedf(anchor_x, 0.01),
		"ay": snappedf(anchor_y, 0.01),
		"top": snappedf(absf(top_px), 0.01),
		# The model's own size, in model units, after any yaw. Scripts use it
		# with Props.along() to lay things out along a prop — spools across a
		# shelf, tools across a bench — from the model's real dimensions rather
		# than from numbers measured off a screenshot.
		"sx": snappedf(bounds.size.x, 0.001),
		"sy": snappedf(bounds.size.y, 0.001),
		"sz": snappedf(bounds.size.z, 0.001),
		"src": String(recipe["src"]),
		"px_per_unit": px_per_unit,
	}


func _min_w(bounds: AABB, basis: Basis) -> float:
	var out := INF
	for i in 8:
		out = minf(out, bounds.get_endpoint(i).dot(basis.z))
	return out


## Combined AABB of every mesh in the instance, in the instance's own space.
func _scene_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var box: AABB = mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out


## Strip the shine off every surface.
##
## KayKit ships its models with a little specular, which renders a highlight
## that slides across a face. The farm around these props is drawn as flat
## polygons with no highlight at all, so a glossy prop would read as a
## photograph pasted into a drawing. Fully rough and non-metallic gives each
## face one even tone, which is exactly what IsoDraw produces by hand.
func _flatten(root: Node3D) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface)
			if source is not BaseMaterial3D:
				continue
			var material: BaseMaterial3D = source.duplicate()
			material.roughness = 1.0
			material.metallic = 0.0
			material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			mesh_instance.set_surface_override_material(surface, material)


## Light the model the way the hand-drawn solids are shaded, so a baked prop
## and a drawn one read as the same material under the same sun.
##
## IsoDraw tints the top face, shades the right face a little and the left face
## more (see IsoDraw.solid). That is a light above and to the model's +X side.
## Ambient does most of the work: this is a bright, low-contrast palette, and a
## hard key would give the props a depth the drawn art does not have.
func _light(viewport: SubViewport) -> void:
	var key := DirectionalLight3D.new()
	key.light_energy = 0.85
	key.light_color = Color(1.0, 0.97, 0.91)
	key.shadow_enabled = false
	viewport.add_child(key)
	key.look_at_from_position(Vector3.ZERO, Vector3(-0.53, -0.74, -0.29), Vector3.UP)

	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.22
	fill.light_color = Color(0.82, 0.90, 1.0)
	fill.shadow_enabled = false
	viewport.add_child(fill)
	fill.look_at_from_position(Vector3.ZERO, Vector3(0.6, -0.2, 0.75), Vector3.UP)

	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.93, 0.96, 1.0)
	environment.ambient_light_energy = 1.05
	world.environment = environment
	viewport.add_child(world)
