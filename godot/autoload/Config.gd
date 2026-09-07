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
