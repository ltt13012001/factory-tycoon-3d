## Machine cycles: a machine runs only with an operator, material and room
## on its output pallet. Defective units go to scrap.
class_name ProductionManager
extends RefCounted

const RUNNING := "running"
const NO_OPERATOR := "no_operator"
const NO_MATERIAL := "no_material"
const OUTPUT_FULL := "output_full"

var sim: Simulation


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func def_of(m: Dictionary) -> MachineDef:
	return sim.content.machines[m.def_id]


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
	}


func machine_in_slot(slot: int) -> Dictionary:
	for m in sim.state.machines:
		if m.slot == slot:
			return m
	return {}


func buy_machine(def_id: String, slot: int) -> Dictionary:
	if not sim.content.machines.has(def_id):
		return Simulation.fail("Không có loại máy này.")
	if slot < 0 or slot >= sim.config.machine_slots:
		return Simulation.fail("Ô đặt máy không hợp lệ.")
	if not machine_in_slot(slot).is_empty():
		return Simulation.fail("Ô này đã có máy.")
	var d: MachineDef = sim.content.machines[def_id]
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
	# Boxes on the pallet go to the finished store; a cycle in progress is lost.
	var moved := mini(int(m.buffer), sim.config.finished_capacity - s.finished)
	s.finished += moved
	s.scrap_total += int(m.buffer) - moved
	for e in s.employees:
		if e.machine_id == machine_id:
			e.machine_id = 0
	s.machines.erase(m)
	sim.economy.book("machine_sale", refund, "Bán " + d.display_name)
	sim.employees.auto_assign()
	sim.emit_event(&"machine_removed", {"id": machine_id})
	return Simulation.ok("Đã bán máy, thu về %s." % Fmt.money(refund))


func tick() -> void:
	var s := sim.state
	for m in s.machines:
		var d := def_of(m)
		var before: String = m.status
		var has_operator: bool = m.operator_id != 0
		if not m.in_cycle:
			if not has_operator:
				m.status = NO_OPERATOR
			elif m.buffer >= d.output_buffer_capacity:
				m.status = OUTPUT_FULL
			elif s.raw < sim.content.product().material_per_unit:
				m.status = NO_MATERIAL
			else:
				var cost := sim.inventory.consume_raw(sim.content.product().material_per_unit)
				sim.economy.add_stat("material_cost", cost)
				m.in_cycle = true
				m.ticks_left = d.cycle_ticks
		if m.in_cycle:
			if not has_operator:
				m.status = NO_OPERATOR
			else:
				m.status = RUNNING
				m.ticks_left -= 1
				if m.ticks_left <= 0:
					_finish_cycle(m, d)
		if m.status != before:
			sim.emit_event(&"machine_state_changed", {"id": m.id, "status": m.status})


func _finish_cycle(m: Dictionary, d: MachineDef) -> void:
	m.in_cycle = false
	sim.state.power_accrued += d.power_cost_per_cycle
	if sim.rng.randi_range(1, 100) <= d.defect_percent:
		m.defects += 1
		sim.state.scrap_total += 1
		sim.economy.add_stat("defects", 1)
		sim.emit_event(&"unit_defective", {"id": m.id})
	else:
		m.buffer += 1
		m.produced += 1
		sim.economy.add_stat("produced", 1)
		sim.emit_event(&"unit_produced", {"id": m.id})


## Good units per game hour across machines that currently have an operator.
func hourly_capacity() -> float:
	var total := 0.0
	for m in sim.state.machines:
		if m.operator_id != 0:
			var d := def_of(m)
			total += float(sim.config.ticks_per_hour) / d.cycle_ticks * (100 - d.defect_percent) / 100.0
	return total
