## Construction projects (one at a time) and the bonuses of finished buildings.
class_name BuildingManager
extends RefCounted

var sim: Simulation


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func level(id: String) -> int:
	return int(sim.state.buildings.get(id, 0))


func bonus(field: String) -> int:
	var total := 0
	for id in sim.state.buildings:
		var d: ConstructionDef = sim.content.constructions.get(id)
		if d:
			total += int(d.get(field)) * int(sim.state.buildings[id])
	return total


func raw_capacity() -> int:
	return sim.config.raw_capacity + bonus("raw_capacity_bonus") + sim.expansion.extra_raw_capacity()


func finished_capacity() -> int:
	return sim.config.finished_capacity + bonus("finished_capacity_bonus") + sim.expansion.extra_finished_capacity()


func machine_slots() -> int:
	return sim.config.machine_slots + bonus("extra_machine_slots")


func haul_leg_ticks() -> int:
	return maxi(4, roundi(sim.config.haul_leg_ticks * 100.0 / (100 + bonus("haul_speed_bonus_percent"))))


func power_cost(base: int) -> int:
	return base * maxi(0, 100 - bonus("power_discount_percent")) / 100


func next_cost(id: String) -> int:
	var d: ConstructionDef = sim.content.constructions[id]
	var lvl := level(id)
	return d.level_costs[lvl] if lvl < d.level_costs.size() else -1


## Why this project cannot start now, or "" when it can.
func block_reason(id: String) -> String:
	var d: ConstructionDef = sim.content.constructions.get(id)
	if d == null:
		return "Không có công trình này."
	if level(id) >= d.level_costs.size():
		return "Đã xây tối đa"
	if not sim.state.construction.is_empty():
		return "Đang xây công trình khác"
	if sim.state.reputation < d.min_reputation:
		return "Cần uy tín %d" % d.min_reputation
	if not sim.economy.can_afford(next_cost(id)):
		return "Không đủ tiền"
	return ""


func start(id: String) -> Dictionary:
	var reason := block_reason(id)
	if reason != "":
		return Simulation.fail(reason + ".")
	var d: ConstructionDef = sim.content.constructions[id]
	var cost := next_cost(id)
	sim.economy.book("construction", -cost, "Xây " + d.display_name)
	var total := d.build_hours * sim.config.ticks_per_hour
	sim.state.construction = {"id": id, "ticks_left": total, "total_ticks": total}
	sim.emit_event(&"construction_started", {"id": id})
	return Simulation.ok("Bắt đầu xây %s, xong sau %d giờ." % [d.display_name, d.build_hours])


func tick() -> void:
	var c: Dictionary = sim.state.construction
	if c.is_empty():
		return
	c.ticks_left -= 1
	if c.ticks_left > 0:
		return
	var id: String = c.id
	sim.state.buildings[id] = level(id) + 1
	sim.state.construction = {}
	sim.emit_event(&"construction_finished", {"id": id, "level": level(id)})
