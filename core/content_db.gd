## Loads every definition resource in data/content/, keyed by id.
class_name ContentDB
extends RefCounted

const CONTENT_DIR := "res://data/content/"

var economy: EconomyConfig
var materials: Dictionary = {}
var products: Dictionary = {}
var machines: Dictionary = {}
var order_templates: Dictionary = {}
var constructions: Dictionary = {}


static func load_default() -> ContentDB:
	var db := ContentDB.new()
	var files := DirAccess.get_files_at(CONTENT_DIR)
	var names := []
	for f in files:
		# Exported builds list converted resources as "name.tres.remap".
		var n := f.trim_suffix(".remap")
		if n.ends_with(".tres") and not names.has(n):
			names.append(n)
	names.sort()
	for n in names:
		db._add(load(CONTENT_DIR + n))
	return db


func _add(res: Resource) -> void:
	if res is EconomyConfig:
		economy = res
	elif res is MaterialDef:
		materials[res.id] = res
	elif res is ProductDef:
		products[res.id] = res
	elif res is MachineDef:
		machines[res.id] = res
	elif res is OrderTemplateDef:
		order_templates[res.id] = res
	elif res is ConstructionDef:
		constructions[res.id] = res
	else:
		push_error("ContentDB: unknown resource %s" % res)


func material() -> MaterialDef:
	return materials[economy.material_id]


## Machine definitions sorted by price, the order the shop shows them.
func machine_list() -> Array:
	var list := machines.values()
	list.sort_custom(func(a, b): return a.price < b.price)
	return list


func construction_list() -> Array:
	var list := constructions.values()
	list.sort_custom(func(a, b): return a.level_costs[0] < b.level_costs[0])
	return list
