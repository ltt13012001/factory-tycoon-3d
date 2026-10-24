## Loads every definition resource the simulation needs, keyed by id.
class_name ContentDB
extends RefCounted

const CONTENT_DIR := "res://data/content/"

var economy: EconomyConfig
var materials: Dictionary = {}
var products: Dictionary = {}
var machines: Dictionary = {}
var order_templates: Dictionary = {}


static func load_default() -> ContentDB:
	var db := ContentDB.new()
	db.economy = load(CONTENT_DIR + "economy.tres")
	db._add(load(CONTENT_DIR + "plastic_pellets.tres"))
	db._add(load(CONTENT_DIR + "plastic_box.tres"))
	db._add(load(CONTENT_DIR + "basic_injection_molder.tres"))
	db._add(load(CONTENT_DIR + "small_customer.tres"))
	return db


func _add(res: Resource) -> void:
	if res is MaterialDef:
		materials[res.id] = res
	elif res is ProductDef:
		products[res.id] = res
	elif res is MachineDef:
		machines[res.id] = res
	elif res is OrderTemplateDef:
		order_templates[res.id] = res
	else:
		push_error("ContentDB: unknown resource %s" % res)


func material() -> MaterialDef:
	return materials[economy.material_id]


func product() -> ProductDef:
	return products[economy.product_id]


func order_template() -> OrderTemplateDef:
	return order_templates[economy.order_template_id]
