## Machine cycles: a machine runs only with an operator (unless automated),
## material and room on its output pallet. Machines wear out, can break,
## and can be upgraded or repaired. Defective units go to scrap.
class_name ProductionManager
extends RefCounted

const RUNNING := "running"
const NO_OPERATOR := "no_operator"
const NO_MATERIAL := "no_material"
const OUTPUT_FULL := "output_full"
const BROKEN := "broken"
const REPAIRING := "repairing"
const OWNER := -1

var sim: Simulation


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func def_of(m: Dictionary) -> MachineDef:
	return sim.content.machines[m.def_id]


func product_of(m: Dictionary) -> ProductDef:
	return sim.content.products[def_of(m).output_product_id]


func make_machine(def_id: String, slot: int) -> Dictionary:
	return {
		"id": sim.state.take_id(),
		"def_id": def_id,
		"slot": slot,
		"in_cycle": false,
		"ticks_left": 0,
		"buffer": 0,
		"status": NO_OPERATOR,
		"operator_id": 0,
		"produced": 0,
		"defects": 0,
		"level": 1,
		"condition": 100,
		"wear_count": 0,
		"broken": false,
		"repair_ticks_left": 0,
		"repairer_id": 0,
	}


func machine_in_slot(slot: int) -> Dictionary:
	for m in sim.state.machines:
		if m.slot == slot:
			return m
	return {}


func needs_operator(m: Dictionary) -> bool:
	return def_of(m).operators_required > 0


func cycle_ticks(m: Dictionary) -> int:
	var d := def_of(m)
	return maxi(4, roundi(d.cycle_ticks * (100 - d.upgrade_speed_percent * (int(m.level) - 1)) / 100.0))


func upgrade_cost(m: Dictionary) -> int:
	var d := def_of(m)
	if int(m.level) >= d.max_level:
		return -1
	return d.price * d.upgrade_cost_percent / 100 * int(m.level)


func repair_cost(m: Dictionary) -> int:
	return (100 - int(m.condition)) * def_of(m).repair_cost_per_point


## Why this machine type cannot be bought yet, or "" when it can.
func unlock_reason(d: MachineDef) -> String:
	if sim.day() < d.min_day:
		return "Mở từ ngày %d" % d.min_day
	if sim.state.reputation < d.min_reputation:
		return "Cần uy tín %d" % d.min_reputation
	return ""


func buy_machine(def_id: String, slot: int) -> Dictionary:
	if not sim.content.machines.has(def_id):
		return Simulation.fail("Không có loại máy này.")
	if slot < 0 or slot >= sim.buildings.machine_slots():
		return Simulation.fail("Ô đặt máy không hợp lệ.")
	if not machine_in_slot(slot).is_empty():
		return Simulation.fail("Ô này đã có máy.")
	var d: MachineDef = sim.content.machines[def_id]
	var locked := unlock_reason(d)
	if locked != "":
		return Simulation.fail(locked + ".")
	if not sim.economy.can_afford(d.price):
		return Simulation.fail("Không đủ tiền. Cần %s." % Fmt.money(d.price))
	sim.economy.book("machine", -d.price, "Mua " + d.display_name)
	var m := make_machine(def_id, slot)
	sim.state.machines.append(m)
	sim.state.machines_bought += 1
	sim.employees.auto_assign()
	sim.emit_event(&"machine_added", m.duplicate())
	return Simulation.ok("Đã mua %s." % d.display_name)


func sell_machine(machine_id: int) -> Dictionary:
	var s := sim.state
	var m := s.find_by_id(s.machines, machine_id)
	if m.is_empty():
		return Simulation.fail("Không tìm thấy máy.")
	var d := def_of(m)
	var refund := d.price * d.resale_percent / 100
	# Units on the pallet go to the finished store; a cycle in progress is lost.
	var moved := mini(int(m.buffer), sim.inventory.finished_free_space())
	s.add_finished(d.output_product_id, moved)
	s.scrap_total += int(m.buffer) - moved
	for e in s.employees:
		if e.machine_id == machine_id:
			e.machine_id = 0
		if not e.job.is_empty() and e.job.kind == "repair" and int(e.job.machine_id) == machine_id:
			e.job = {}
	s.machines.erase(m)
	sim.economy.book("machine_sale", refund, "Bán " + d.display_name)
	sim.employees.auto_assign()
	sim.emit_event(&"machine_removed", {"id": machine_id})
	return Simulation.ok("Đã bán máy, thu về %s." % Fmt.money(refund))


func upgrade(machine_id: int) -> Dictionary:
	var m := sim.state.find_by_id(sim.state.machines, machine_id)
	if m.is_empty():
		return Simulation.fail("Không tìm thấy máy.")
	var cost := upgrade_cost(m)
	if cost < 0:
		return Simulation.fail("Máy đã ở cấp cao nhất.")
	if not sim.economy.can_afford(cost):
		return Simulation.fail("Không đủ tiền nâng cấp (%s)." % Fmt.money(cost))
	sim.economy.book("upgrade", -cost, "Nâng cấp " + def_of(m).display_name)
	m.level = int(m.level) + 1
	sim.emit_event(&"machine_upgraded", {"id": m.id, "level": m.level})
	return Simulation.ok("Máy lên cấp %d: nhanh hơn %d%%." % [m.level, def_of(m).upgrade_speed_percent * (int(m.level) - 1)])


## The owner repairs (or services) the machine for a fee.
func repair(machine_id: int) -> Dictionary:
	var m := sim.state.find_by_id(sim.state.machines, machine_id)
	if m.is_empty():
		return Simulation.fail("Không tìm thấy máy.")
	if int(m.repairer_id) != 0:
		return Simulation.fail("Máy đang được sửa.")
	if int(m.condition) >= 100 and not m.broken:
		return Simulation.fail("Máy đang ở tình trạng tốt.")
	var cost := repair_cost(m)
	if not sim.economy.can_afford(cost):
		return Simulation.fail("Không đủ tiền sửa máy (%s)." % Fmt.money(cost))
	if cost > 0:
		sim.economy.book("repair", -cost, "Sửa " + def_of(m).display_name)
		sim.economy.add_stat("repairs", cost)
	start_repair(m, OWNER)
	return Simulation.ok("Chủ xưởng đang đến sửa máy.")


func start_repair(m: Dictionary, repairer_id: int) -> void:
	m.repairer_id = repairer_id
	m.repair_ticks_left = sim.config.repair_walk_ticks + def_of(m).repair_ticks
	m.status = REPAIRING
	sim.emit_event(&"machine_state_changed", {"id": m.id, "status": m.status})


func tick() -> void:
	var s := sim.state
	for m in s.machines:
		var d := def_of(m)
		var before: String = m.status
		if int(m.repairer_id) != 0:
			m.status = REPAIRING
			m.repair_ticks_left -= 1
			if m.repair_ticks_left <= 0:
				_finish_repair(m)
		elif m.broken:
			m.status = BROKEN
		else:
			_run(m, d)
		if m.status != before:
			sim.emit_event(&"machine_state_changed", {"id": m.id, "status": m.status})


func _run(m: Dictionary, d: MachineDef) -> void:
	var s := sim.state
	var has_operator: bool = m.operator_id != 0 or not needs_operator(m)
	var per_unit: int = sim.content.products[d.output_product_id].material_per_unit
	if not m.in_cycle:
		if not has_operator:
			m.status = NO_OPERATOR
			return
		if m.buffer >= d.output_buffer_capacity:
			m.status = OUTPUT_FULL
			return
		if s.raw < per_unit:
			m.status = NO_MATERIAL
			return
		var cost := sim.inventory.consume_raw(per_unit)
		sim.economy.add_stat("material_cost", cost)
		m.in_cycle = true
		m.ticks_left = cycle_ticks(m)
	if not has_operator:
		m.status = NO_OPERATOR
		return
	m.status = RUNNING
	m.ticks_left -= 1
	if m.ticks_left <= 0:
		_finish_cycle(m, d)


func _finish_cycle(m: Dictionary, d: MachineDef) -> void:
	m.in_cycle = false
	sim.state.power_accrued += sim.buildings.power_cost(d.power_cost_per_cycle)
	if sim.rng.randi_range(1, 100) <= d.defect_percent:
		m.defects += 1
		sim.state.scrap_total += 1
		sim.economy.add_stat("defects", 1)
		sim.emit_event(&"unit_defective", {"id": m.id})
	else:
		m.buffer += 1
		m.produced += 1
		sim.economy.add_stat("produced", 1)
		sim.emit_event(&"unit_produced", {"id": m.id, "product_id": d.output_product_id})
	m.wear_count = int(m.wear_count) + 1
	if m.wear_count >= d.wear_cycles:
		m.wear_count = 0
		m.condition = maxi(0, int(m.condition) - 1)
	if int(m.condition) <= 0 or (int(m.condition) < d.fragile_below and sim.rng.randi_range(1, 100) <= d.breakdown_percent):
		m.broken = true
		m.status = BROKEN
		sim.emit_event(&"machine_broken", {"id": m.id})


func _finish_repair(m: Dictionary) -> void:
	var repairer := int(m.repairer_id)
	m.condition = 100
	m.wear_count = 0
	m.broken = false
	m.repairer_id = 0
	m.repair_ticks_left = 0
	m.status = NO_OPERATOR
	for e in sim.state.employees:
		if e.id == repairer:
			e.job = {}
	sim.emit_event(&"machine_repaired", {"id": m.id})


## Good units per game hour across working machines, optionally for one product.
func hourly_capacity(product_id: String = "") -> float:
	var total := 0.0
	for m in sim.state.machines:
		var d := def_of(m)
		if product_id != "" and d.output_product_id != product_id:
			continue
		if (m.operator_id != 0 or not needs_operator(m)) and not m.broken:
			total += float(sim.config.ticks_per_hour) / cycle_ticks(m) * (100 - d.defect_percent) / 100.0
	return total


func produces(product_id: String) -> bool:
	for m in sim.state.machines:
		if def_of(m).output_product_id == product_id:
			return true
	return false
