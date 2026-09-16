extends Node
## Balancing data, served by the backend.
##
## Nothing here is hard-coded in the client: printer stats, filament prices,
## products, workshop tiers, upgrades and level gates all arrive from
## /api/game/config, which the admin can override in the database. The client
## caches the payload for the session and looks things up by id.

signal loaded()

var data: Dictionary = {}
var is_loaded: bool = false

var _printers: Dictionary = {}
var _materials: Dictionary = {}
var _colors: Dictionary = {}
var _products: Dictionary = {}
var _upgrades: Dictionary = {}


func load_config() -> bool:
	var response := await Net.get_json("/api/game/config")
	if not response.get("success", false):
		return false
	data = response.get("config", {})
	_index()
	is_loaded = true
	loaded.emit()
	return true


func _index() -> void:
	var catalogs: Dictionary = data.get("catalogs", {})
	_printers.clear()
	for p in catalogs.get("printers", []):
		_printers[p["id"]] = p
	_materials.clear()
	for m in catalogs.get("materials", []):
		_materials[m["id"]] = m
	_colors.clear()
	for c in catalogs.get("colors", []):
		_colors[c["id"]] = c
	_products.clear()
	for pr in catalogs.get("products", []):
		_products[pr["id"]] = pr
	_upgrades.clear()
	for u in data.get("upgrades", []):
		_upgrades[u["id"]] = u


func printer_model(id: String) -> Dictionary:
	return _printers.get(id, {})


func material(id: String) -> Dictionary:
	return _materials.get(id, {})


## The material's swatch colour. The catalogue ships it as a hex string and
## every caller wants a Color.
func material_tint(id: String) -> Color:
	var hex := String(material(id).get("tint", ""))
	return Color(hex) if hex.begins_with("#") else Palette.INK_FAINT


## Which reel a material's spools come on: "clear", "solid" or "tech".
##
## Filament ships on heavier reels the more demanding the plastic is, and that
## is exactly the axis the catalogue already orders materials along — so the
## reel is read off the unlock level rather than listed here. A material added
## to the catalogue therefore arrives with a reel that matches its tier without
## anything in the client changing.
func material_reel(id: String) -> String:
	var level := int(material(id).get("unlockLevel", 1))
	if level <= 6:
		return "clear"
	if level <= 18:
		return "solid"
	return "tech"


func color(id: String) -> Dictionary:
	return _colors.get(id, {})


func product(id: String) -> Dictionary:
	return _products.get(id, {})


func upgrade(id: String) -> Dictionary:
	return _upgrades.get(id, {})


func all_printers() -> Array:
	return data.get("catalogs", {}).get("printers", [])


func all_materials() -> Array:
	return data.get("catalogs", {}).get("materials", [])


func all_colors() -> Array:
	return data.get("catalogs", {}).get("colors", [])


func all_products() -> Array:
	return data.get("catalogs", {}).get("products", [])


func all_upgrades() -> Array:
	return data.get("upgrades", [])


## Whether any maintenance action actually consumes this part. Three of the
## six in the catalogue — the belt set, the extruder gears, the maintenance
## kit — are consumed by nothing, so offering to sell them is offering to take
## the player's coins for an item with no use.
func part_is_used(part_id: String) -> bool:
	for action in maintenance_actions():
		if String(action.get("partId", "")) == part_id:
			return true
	return false


func all_parts() -> Array:
	return data.get("maintenance", {}).get("parts", [])


func maintenance_actions() -> Array:
	return data.get("maintenance", {}).get("actions", [])


func workshop_tier(index: int) -> Dictionary:
	var tiers: Array = data.get("workshop", {}).get("tiers", [])
	if index < 0 or index >= tiers.size():
		return {}
	return tiers[index]


func workshop_tiers() -> Array:
	return data.get("workshop", {}).get("tiers", [])


func health_thresholds() -> Dictionary:
	return data.get("maintenance", {}).get("thresholds", {"good": 100, "service": 70, "warning": 40, "critical": 20})


## A machine's speed with everything fitted to it. Mirrors effectiveStats()
## on the server, which is what the print time is actually worked out from.
func effective_speed(printer: Dictionary) -> float:
	var speed := float(printer_model(String(printer.get("modelId", ""))).get("speed", 1.0))
	for id in printer.get("upgrades", []):
		var effects: Dictionary = upgrade(String(id)).get("effects", {})
		if effects.has("speed"):
			speed *= 1.0 + float(effects["speed"])
	return maxf(0.15, speed)


## Purge waste as a fraction, with the machine's upgrades applied. Same source.
func material_waste(printer: Dictionary) -> float:
	var waste := float(data.get("materials", {}).get("wasteFactor", 0.04))
	for id in printer.get("upgrades", []):
		var effects: Dictionary = upgrade(String(id)).get("effects", {})
		if effects.has("materialWaste"):
			waste *= 1.0 + float(effects["materialWaste"])
	return maxf(0.0, waste)


## What an order pays when it is delivered after its deadline, as a fraction
## of the reward. A quote for the card, not the payment: the server works out
## what actually lands, from this same number.
func late_penalty() -> float:
	return float(data.get("economy", {}).get("latePenalty", 0.45))


## Cost of the next station, mirroring shared/engines/economy.ts.
func slot_cost(unlocked_count: int) -> int:
	var w: Dictionary = data.get("workshop", {})
	var base: float = float(w.get("slotCostBase", 450))
	var growth: float = float(w.get("slotCostGrowth", 1.55))
	return int(round(base * pow(growth, float(maxi(0, unlocked_count - 1)))))


func slot_level(unlocked_count: int) -> int:
	var step: int = int(data.get("workshop", {}).get("slotLevelStep", 2))
	return 1 + maxi(0, unlocked_count - 1) * step


## XP needed to leave `level`. Mirrors xpForLevel() on the server.
func xp_for_level(level: int) -> int:
	var p: Dictionary = data.get("progression", {})
	var base: float = float(p.get("xpBase", 120))
	var exponent: float = float(p.get("xpExponent", 1.45))
	return int(round(base * pow(float(level), exponent)))


## Feature gates, so the UI can hide systems the player has not reached.
func has_feature(level: int, key: String) -> bool:
	var unlocks: Dictionary = data.get("progression", {}).get("unlocks", {})
	for lvl_key in unlocks.keys():
		if level >= int(lvl_key):
			for k in unlocks[lvl_key]:
				if String(k) == key:
					return true
	return false


## The level at which a feature appears, for "unlocks at level N" copy.
func feature_level(key: String) -> int:
	var unlocks: Dictionary = data.get("progression", {}).get("unlocks", {})
	for lvl_key in unlocks.keys():
		for k in unlocks[lvl_key]:
			if String(k) == key:
				return int(lvl_key)
	return 1
