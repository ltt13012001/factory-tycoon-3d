## Staff list, hiring and firing, operator assignment, warehouse trips and
## technician maintenance.
class_name EmployeeManager
extends RefCounted

const OPERATOR := "operator"
const WAREHOUSE := "warehouse"
const TECHNICIAN := "technician"
const ROLE_NAMES := {OPERATOR: "Vận hành máy", WAREHOUSE: "Nhân viên kho", TECHNICIAN: "Kỹ thuật viên"}
## Technicians service machines at or below this condition.
const SERVICE_BELOW := 60

var sim: Simulation


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func make_employee(role: String) -> Dictionary:
	var names := sim.config.worker_names
	var n := "Công nhân %d" % (sim.state.name_index + 1)
	if names.size() > 0:
		n = names[sim.state.name_index % names.size()]
		if sim.state.name_index >= names.size():
			n += " %d" % (sim.state.name_index / names.size() + 1)
	sim.state.name_index += 1
	return {"id": sim.state.take_id(), "name": n, "role": role, "machine_id": 0, "job": {}}


func count(role: String) -> int:
	var c := 0
	for e in sim.state.employees:
		if e.role == role:
			c += 1
	return c


func hire(role: String) -> Dictionary:
	if not ROLE_NAMES.has(role):
		return Simulation.fail("Vai trò không hợp lệ.")
	var fee := sim.config.hire_fee
	if not sim.economy.can_afford(fee):
		return Simulation.fail("Không đủ tiền tuyển dụng (%s)." % Fmt.money(fee))
	var e := make_employee(role)
	sim.economy.book("hire", -fee, "Tuyển " + e.name)
	sim.state.employees.append(e)
	auto_assign()
	sim.emit_event(&"employee_hired", e.duplicate(true))
	return Simulation.ok("Đã tuyển %s (%s)." % [e.name, ROLE_NAMES[role]])


func fire(employee_id: int) -> Dictionary:
	var s := sim.state
	var e := s.find_by_id(s.employees, employee_id)
	if e.is_empty():
		return Simulation.fail("Không tìm thấy nhân viên.")
	_drop_carried(e)
	if e.machine_id != 0:
		var m := s.find_by_id(s.machines, e.machine_id)
		if not m.is_empty():
			m.operator_id = 0
	for m in s.machines:
		if int(m.repairer_id) == employee_id:
			m.repairer_id = 0
			m.repair_ticks_left = 0
	s.employees.erase(e)
	auto_assign()
	sim.emit_event(&"employee_fired", {"id": employee_id})
	return Simulation.ok("%s đã nghỉ việc." % e.name)


## Goods in a fired worker's hands go back where they came from.
func _drop_carried(e: Dictionary) -> void:
	if e.job.is_empty() or int(e.job.get("qty", 0)) == 0:
		e.job = {}
		return
	var s := sim.state
	if e.job.kind == "unload":
		s.dock += int(e.job.qty)
	elif e.job.kind == "haul":
		var m := s.find_by_id(s.machines, int(e.job.machine_id))
		if m.is_empty():
			var moved := mini(int(e.job.qty), sim.inventory.finished_free_space())
			s.add_finished(e.job.product_id, moved)
			s.scrap_total += int(e.job.qty) - moved
		else:
			m.buffer += int(e.job.qty)
	e.job = {}


## Gives every machine that needs an operator the first free operator.
func auto_assign() -> void:
	var s := sim.state
	for e in s.employees:
		if e.role == OPERATOR and e.machine_id != 0:
			var m := s.find_by_id(s.machines, e.machine_id)
			if m.is_empty() or not sim.production.needs_operator(m):
				e.machine_id = 0
	var machines := s.machines.duplicate()
	machines.sort_custom(func(a, b): return a.slot < b.slot)
	for m in machines:
		if not sim.production.needs_operator(m):
			m.operator_id = 0
			continue
		if m.operator_id != 0 and not s.find_by_id(s.employees, m.operator_id).is_empty():
			continue
		m.operator_id = 0
		for e in s.employees:
			if e.role == OPERATOR and e.machine_id == 0:
				e.machine_id = m.id
				m.operator_id = e.id
				break


func tick() -> void:
	for e in sim.state.employees:
		if e.role == TECHNICIAN:
			if e.job.is_empty():
				_pick_service(e)
			continue
		if e.role != WAREHOUSE:
			continue
		if e.job.is_empty():
			e.job = _pick_job(e)
			if e.job.is_empty():
				continue
		var job: Dictionary = e.job
		job.ticks_left -= 1
		if job.ticks_left > 0:
			continue
		if job.phase == "to_source":
			_pick_up(e, job)
		else:
			_deposit(e, job)


func _pick_service(e: Dictionary) -> void:
	var best := {}
	for m in sim.state.machines:
		if int(m.repairer_id) != 0:
			continue
		if not m.broken and int(m.condition) > SERVICE_BELOW:
			continue
		if best.is_empty() or (m.broken and not best.broken) or (m.broken == best.broken and int(m.condition) < int(best.condition)):
			best = m
	if best.is_empty():
		return
	e.job = {"kind": "repair", "phase": "to_source", "ticks_left": 0, "machine_id": best.id, "qty": 0, "product_id": ""}
	sim.production.start_repair(best, e.id)


func _targeted_machines() -> Array:
	var ids := []
	for e in sim.state.employees:
		if not e.job.is_empty() and e.job.kind == "haul":
			ids.append(e.job.machine_id)
	return ids


func _pick_job(_e: Dictionary) -> Dictionary:
	var s := sim.state
	var cfg := sim.config
	var leg := sim.buildings.haul_leg_ticks()
	if s.dock - _dock_claims() > 0 and s.raw + sim.inventory.carried("unload") < sim.buildings.raw_capacity():
		return {"kind": "unload", "phase": "to_source", "ticks_left": leg, "machine_id": 0, "qty": 0, "product_id": ""}
	if sim.inventory.finished_free_space() - sim.inventory.carried("haul") <= 0:
		return {}
	var targeted := _targeted_machines()
	var best := {}
	for m in s.machines:
		if targeted.has(m.id):
			continue
		var full: bool = m.buffer >= sim.production.def_of(m).output_buffer_capacity
		if m.buffer >= cfg.haul_min_boxes or (full and m.buffer > 0):
			if best.is_empty() or m.buffer > best.buffer:
				best = m
	if best.is_empty():
		return {}
	return {"kind": "haul", "phase": "to_source", "ticks_left": leg, "machine_id": best.id, "qty": 0,
		"product_id": sim.production.def_of(best).output_product_id}


## Workers already walking to the dock will each take up to one batch.
func _dock_claims() -> int:
	var claims := 0
	for e in sim.state.employees:
		if not e.job.is_empty() and e.job.kind == "unload" and e.job.phase == "to_source":
			claims += sim.config.haul_raw_batch
	return claims


func _pick_up(e: Dictionary, job: Dictionary) -> void:
	var s := sim.state
	var cfg := sim.config
	var qty := 0
	if job.kind == "unload":
		var space := sim.buildings.raw_capacity() - s.raw - sim.inventory.carried("unload")
		qty = mini(mini(cfg.haul_raw_batch, s.dock), space)
		s.dock -= qty
	else:
		var m := s.find_by_id(s.machines, int(job.machine_id))
		if not m.is_empty():
			qty = mini(cfg.haul_finished_batch, int(m.buffer))
			m.buffer -= qty
	if qty <= 0:
		e.job = {}
		return
	job.qty = qty
	job.phase = "to_dest"
	job.ticks_left = sim.buildings.haul_leg_ticks()
	sim.emit_event(&"worker_picked_up", {"id": e.id, "kind": job.kind, "qty": qty})


func _deposit(e: Dictionary, job: Dictionary) -> void:
	var s := sim.state
	var put := 0
	if job.kind == "unload":
		put = mini(int(job.qty), sim.buildings.raw_capacity() - s.raw)
		s.raw += put
	else:
		put = mini(int(job.qty), sim.inventory.finished_free_space())
		s.add_finished(job.product_id, put)
	job.qty -= put
	if job.qty > 0:
		job.ticks_left = 1  # store full: wait at the door until there is room
		return
	e.job = {}
	sim.emit_event(&"worker_delivered", {"id": e.id, "kind": job.kind, "qty": put})
