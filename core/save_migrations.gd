## Upgrades old save dictionaries step by step to CURRENT_VERSION.
## When the save format changes: bump CURRENT_VERSION and add a
## _from_<old>() function that rewrites the dictionary in place.
class_name SaveMigrations
extends RefCounted

const CURRENT_VERSION := 5


static func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("save_version", 0))
	if version > CURRENT_VERSION:
		push_error("Save file is from a newer game version (%d)." % version)
		return {}
	while version < CURRENT_VERSION:
		match version:
			0:
				data = _from_0(data)
			1:
				data = _from_1(data)
			2:
				data = _from_2(data)
			3:
				data = _from_3(data)
			4:
				data = _from_4(data)
		version += 1
		data.save_version = version
	return data


## Version 0 never shipped; it only marks files without a version field.
static func _from_0(data: Dictionary) -> Dictionary:
	return data


## 0.1 -> 0.2: several products, machine levels and wear, buildings.
static func _from_1(data: Dictionary) -> Dictionary:
	var boxes = data.get("finished", 0)
	data.finished = {"plastic_box": int(boxes)} if not boxes is Dictionary else boxes
	for m in data.get("machines", []):
		m.merge({"level": 1, "condition": 100, "wear_count": 0, "broken": false, "repair_ticks_left": 0, "repairer_id": 0})
	for o in data.get("orders", []):
		o.merge({"product_id": "plastic_box"})
	for e in data.get("employees", []):
		if e.job is Dictionary and not e.job.is_empty():
			e.job.merge({"product_id": "plastic_box" if e.job.kind == "haul" else ""})
	data.order_spawn = {"small_customer": int(data.get("order_spawn_acc", 0))}
	data.merge({"buildings": {}, "construction": {}, "settings": {"auto_buy": false, "auto_ship": false}})
	return data


## 0.3 -> 0.4: line speed, more factories and branches, company stages.
static func _from_2(data: Dictionary) -> Dictionary:
	data.merge({"line_speed_level": 0, "company_tier": 0, "sites": [], "executives": {}})
	return data


## 0.4 rebalance: games started on the old, tighter economy get their cash
## topped up to the new starting amount so they are not stuck in debt.
static func _from_3(data: Dictionary) -> Dictionary:
	const NEW_START_CASH := 300000
	var cash := int(data.get("cash", 0))
	if cash < NEW_START_CASH:
		var gift := NEW_START_CASH - cash
		data.cash = NEW_START_CASH
		data.day_start_cash = int(data.get("day_start_cash", cash)) + gift
	return data


## 0.5: shifts and overtime, pay level, staff mood, rest and strikes.
## Machine cycles in progress keep their remaining time (now counted down
## faster), which only shortens them a little.
static func _from_4(data: Dictionary) -> Dictionary:
	for e in data.get("employees", []):
		e.merge({"mood": 70, "rest": false, "away": 0, "idle": 0, "off": false})
	var settings: Dictionary = data.get("settings", {})
	settings.merge({"auto_accept": false, "shift_hours": 8, "pay_percent": 100})
	data.settings = settings
	data.merge({"strike": {}})
	return data
