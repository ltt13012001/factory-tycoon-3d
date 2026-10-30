## Staff list, hiring and firing, operator assignment, warehouse trips and
## technician maintenance; shifts and overtime, pay level, mood, rest and
## strikes.
class_name EmployeeManager
extends RefCounted

const OPERATOR := "operator"
const WAREHOUSE := "warehouse"
const TECHNICIAN := "technician"
## Factory manager of the first factory: one at most.
const MANAGER := "manager"
const ROLE_NAMES := {OPERATOR: "Vận hành máy", WAREHOUSE: "Nhân viên kho", TECHNICIAN: "Kỹ thuật viên", MANAGER: "Xưởng trưởng"}
## A factory manager earns this many times the normal wage.
const MANAGER_WAGE_FACTOR := 3
## Technicians service machines at or below this condition.
const SERVICE_BELOW := 60

## The normal working day in hours; longer shifts are overtime.
const STANDARD_SHIFT := 8
const SHIFT_CHOICES := [8, 10, 12, 14]
## Overtime hours are paid at this percent of the normal hourly wage.
const OVERTIME_PAY_PERCENT := 150
## Pay level choices, percent of the standard wage.
const PAY_MIN := 70
const PAY_MAX := 150
## Mood lost to each shift length.
const OVERTIME_MOOD := {8: 0, 10: 8, 12: 16, 14: 26}
const BASE_MOOD := 60
const BREAK_ROOM_MOOD := 8
## Staff may strike while the average mood is below this, and go back to
## work once the conditions would bring it up to STRIKE_ENDS_AT.
const STRIKE_BELOW := 30
const STRIKE_ENDS_AT := 45
## Chance per working hour that unhappy staff go on strike.
const STRIKE_CHANCE_PERCENT := 25
const UNHAPPY_BELOW := 40
## A worker with nothing to do for this many ticks goes to the rest area,
## and needs RETURN_TICKS to walk back to work (also when the shift starts).
const REST_AFTER_TICKS := 30
const RETURN_TICKS := 20
## A warehouse worker waits this long at a full store, then puts the goods back.
const FULL_STORE_WAIT_TICKS := 30

var sim: Simulation


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func make_employee(role: String, site := "") -> Dictionary:
	return {"id": sim.state.take_id(), "name": next_name(), "role": role, "site": site, "machine_id": 0, "job": {},
		"mood": 70, "rest": false, "away": 0, "idle": 0, "off": false}


## The next name from the name list (also used for managers and executives).
func next_name() -> String:
	var names := sim.config.worker_names
	var n := "Công nhân %d" % (sim.state.name_index + 1)
	if names.size() > 0:
		n = names[sim.state.name_index % names.size()]
		if sim.state.name_index >= names.size():
			n += " %d" % (sim.state.name_index / names.size() + 1)
	sim.state.name_index += 1
	return n


## Daily wage: the pay level applied to the standard wage, plus overtime
## hours at OVERTIME_PAY_PERCENT.
func wage_of(e: Dictionary) -> int:
	var base := sim.config.wage_per_day * (MANAGER_WAGE_FACTOR if e.role == MANAGER else 1) * pay_percent() / 100
	var h := shift_hours()
	return base * (STANDARD_SHIFT * 100 + (h - STANDARD_SHIFT) * OVERTIME_PAY_PERCENT) / (STANDARD_SHIFT * 100)


func shift_hours() -> int:
	return int(sim.state.settings.get("shift_hours", STANDARD_SHIFT))


func pay_percent() -> int:
	return int(sim.state.settings.get("pay_percent", 100))


func set_shift(hours: int) -> Dictionary:
	if not SHIFT_CHOICES.has(hours):
		return Simulation.fail("Ca làm không hợp lệ.")
	sim.state.settings.shift_hours = hours
	if hours == STANDARD_SHIFT:
		return Simulation.ok("Ca làm %d tiếng, không tăng ca." % hours)
	return Simulation.ok("Ca làm %d tiếng: tăng ca %d tiếng, trả %d%% lương giờ." % [hours, hours - STANDARD_SHIFT, OVERTIME_PAY_PERCENT])


func set_pay(percent: int) -> Dictionary:
	sim.state.settings.pay_percent = clampi(percent, PAY_MIN, PAY_MAX)
	return Simulation.ok("Mức lương: %d%% lương chuẩn." % pay_percent())


## True while the day shift is on (from the start of the day for shift_hours).
func on_shift() -> bool:
	# Tick t covers the moment just before it, so a day is ticks 1..ticks_per_day.
	return posmod(sim.state.tick - 1, sim.config.ticks_per_day) < shift_hours() * sim.config.ticks_per_hour


func on_strike() -> bool:
	return not sim.state.strike.is_empty()


## True when the employee is at their post and able to work right now.
func is_present(e: Dictionary) -> bool:
	if not on_shift() or e.get("off", false):
		return false
	if e.role == MANAGER:
		return true
	return not on_strike() and not e.get("rest", false) and int(e.get("away", 0)) == 0


## The machine status when its operator is not at the machine.
func absence_status(e: Dictionary) -> String:
	if e.is_empty():
		return ProductionManager.NO_OPERATOR
	if not on_shift() or e.get("off", false):
		return ProductionManager.OFF_SHIFT
	if on_strike():
		return ProductionManager.STRIKE
	return ProductionManager.OPERATOR_AWAY


## Calls a resting worker back to work.
func call_back(e: Dictionary) -> void:
	if e.get("rest", false):
		e.rest = false
		e.away = RETURN_TICKS
	e.idle = 0


## The mood this employee drifts toward under the current pay and hours.
func mood_target(e: Dictionary) -> int:
	var t := BASE_MOOD + (pay_percent() - 100) * 6 / 5 - int(OVERTIME_MOOD.get(shift_hours(), 0))
	if sim.buildings.level("break_room") > 0:
		t += BREAK_ROOM_MOOD
	t += int(e.id) * 7 % 11 - 5  # everyone is a little different
	return clampi(t, 0, 100)


func average_mood() -> int:
	var total := 0
	var n := 0
	for e in sim.state.employees:
		if e.role != MANAGER:
			total += int(e.get("mood", 70))
			n += 1
	return total / n if n > 0 else 70


func average_mood_target() -> int:
	var total := 0
	var n := 0
	for e in sim.state.employees:
		if e.role != MANAGER:
			total += mood_target(e)
			n += 1
	return total / n if n > 0 else 70


func total_wages() -> int:
	var total := 0
	for e in sim.state.employees:
		total += wage_of(e)
	return total


## Staff with this role in every factory, or in one factory when site is given.
func count(role: String, site = null) -> int:
	var c := 0
	for e in sim.state.employees:
		if e.role == role and (site == null or ProductionManager.site_of(e) == site):
			c += 1
	return c


func staff_at(site: String) -> Array:
	return sim.state.employees.filter(func(e): return ProductionManager.site_of(e) == site)


## Hires into the first factory (site "") or a finished factory next door.
## The factories next door get their manager from ExpansionManager.hire_head.
func hire(role: String, site := "") -> Dictionary:
	if not ROLE_NAMES.has(role):
		return Simulation.fail("Vai trò không hợp lệ.")
	if site != "":
		if not sim.expansion.is_factory(site) or not sim.expansion.is_ready(site):
			return Simulation.fail("Nhà xưởng chưa xây xong.")
		if role == MANAGER:
			return sim.expansion.hire_head(site)
	if role == MANAGER and count(MANAGER, "") > 0:
		return Simulation.fail("Xưởng đã có xưởng trưởng.")
	var fee := sim.config.hire_fee
	if not sim.economy.can_afford(fee):
		return Simulation.fail("Không đủ tiền tuyển dụng (%s)." % Fmt.money(fee))
	var e := make_employee(role, site)
	sim.economy.book("hire", -fee, "Tuyển " + e.name)
	sim.state.employees.append(e)
	auto_assign()
	sim.emit_event(&"employee_hired", e.duplicate(true))
	if site != "":
		return Simulation.ok("Đã tuyển %s (%s) cho %s." % [e.name, ROLE_NAMES[role], sim.expansion.loc(site).display_name])
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


## Gives every machine that needs an operator the first free operator of
## the same factory.
func auto_assign() -> void:
	var s := sim.state
	for e in s.employees:
		if e.role == OPERATOR and e.machine_id != 0:
			var m := s.find_by_id(s.machines, e.machine_id)
			if m.is_empty() or not sim.production.needs_operator(m) or ProductionManager.site_of(m) != ProductionManager.site_of(e):
				e.machine_id = 0
	var machines := s.machines.duplicate()
	machines.sort_custom(func(a, b): return a.slot < b.slot)
	for m in machines:
		if not sim.production.needs_operator(m):
			m.operator_id = 0
			continue
		if m.operator_id != 0 and int(s.find_by_id(s.employees, m.operator_id).get("machine_id", 0)) == m.id:
			continue
		m.operator_id = 0
		for e in s.employees:
			if e.role == OPERATOR and e.machine_id == 0 and ProductionManager.site_of(e) == ProductionManager.site_of(m):
				e.machine_id = m.id
				m.operator_id = e.id
				break


func tick() -> void:
	var shift := on_shift()
	if sim.state.tick % sim.config.ticks_per_hour == 0:
		_hourly(shift)
	if shift:
		for site in sim.expansion.factory_ids():
			if sim.expansion.site(site).head != "":
				_manage(site)
	for e in sim.state.employees:
		_attendance(e, shift)
		if e.role == MANAGER:
			if shift:
				_manage("")
			continue
		if e.role == OPERATOR:
			_operator_idle(e)
			continue
		var can_start := shift and not on_strike() and int(e.away) == 0
		if e.role == TECHNICIAN:
			if e.job.is_empty():
				if can_start:
					_pick_service(e)
				_count_idle(e, e.job.is_empty())
			continue
		if e.role != WAREHOUSE:
			continue
		if e.job.is_empty():
			if can_start:
				e.job = _pick_job(e)
			if e.job.is_empty():
				_count_idle(e, true)
				continue
			if e.rest:
				# Coming from the rest area takes a little longer.
				e.rest = false
				e.job.ticks_left += RETURN_TICKS
				e.job.leg = e.job.ticks_left
			e.idle = 0
		if on_strike():
			continue
		var job: Dictionary = e.job
		job.ticks_left -= 1
		if job.ticks_left > 0:
			continue
		if job.phase == "to_source":
			_pick_up(e, job)
		else:
			_deposit(e, job)


## Going home after the shift, coming back in the morning, walking back
## from the rest area.
func _attendance(e: Dictionary, shift: bool) -> void:
	if not shift:
		# Workers finish the trip they are on, then go home.
		if not e.off and (e.role != WAREHOUSE or e.job.is_empty()):
			e.off = true
			e.rest = false
			e.away = 0
			e.idle = 0
		return
	if e.off:
		e.off = false
		e.away = RETURN_TICKS
	if int(e.away) > 0 and not on_strike():
		e.away = int(e.away) - 1


## Operators rest while their machine has nothing to do (output full, no
## material, broken); ProductionManager calls them back.
func _operator_idle(e: Dictionary) -> void:
	var m := {}
	if e.machine_id != 0:
		m = sim.state.find_by_id(sim.state.machines, int(e.machine_id))
	var idle: bool = m.is_empty() or (not m.in_cycle and m.status in [ProductionManager.OUTPUT_FULL, ProductionManager.NO_MATERIAL]) \
		or m.broken or int(m.repairer_id) != 0
	_count_idle(e, idle)


func _count_idle(e: Dictionary, idle: bool) -> void:
	if not idle or e.off or not on_shift() or on_strike():
		e.idle = 0
		return
	e.idle = int(e.idle) + 1
	if int(e.idle) >= REST_AFTER_TICKS and not e.rest and int(e.away) == 0:
		e.rest = true


## Once per game hour: moods drift toward their target, and unhappy staff
## may go on strike (or end it once pay and hours improve).
func _hourly(shift: bool) -> void:
	var s := sim.state
	if s.employees.is_empty():
		return
	for e in s.employees:
		var target := mood_target(e)
		var mood := int(e.get("mood", 70))
		e.mood = mood + clampi(target - mood, -2, 2)
	var avg := average_mood()
	if on_strike():
		if average_mood_target() >= STRIKE_ENDS_AT:
			for e in s.employees:
				e.mood = maxi(int(e.mood), STRIKE_ENDS_AT)
			s.strike = {}
			sim.emit_event(&"strike_ended", {})
		return
	var unhappy := avg < UNHAPPY_BELOW
	if unhappy and not s.settings.get("unhappy_warned", false):
		sim.emit_event(&"staff_unhappy", {"mood": avg})
	s.settings.unhappy_warned = unhappy
	if shift and avg < STRIKE_BELOW and count(OPERATOR) + count(WAREHOUSE) + count(TECHNICIAN) > 0 \
			and sim.rng.randi_range(1, 100) <= STRIKE_CHANCE_PERCENT:
		s.strike = {"since_tick": s.tick}
		for e in s.employees:
			if e.role == WAREHOUSE:
				_drop_carried(e)
			e.rest = false
			e.idle = 0
		sim.emit_event(&"strike_started", {"mood": avg})


## A factory manager (the first factory's, or the head of a factory next
## door) calls a paid repair for a broken machine of their factory when no
## technician there is free to take it.
func _manage(site: String) -> void:
	if sim.state.tick % 10 != 0:
		return
	for e in sim.state.employees:
		if e.role == TECHNICIAN and e.job.is_empty() and ProductionManager.site_of(e) == site and not e.off and int(e.away) == 0:
			return
	for m in sim.state.machines:
		if ProductionManager.site_of(m) == site and m.broken and int(m.repairer_id) == 0 and sim.economy.can_afford(sim.production.repair_cost(m)):
			sim.production.repair(m.id)
			return


func _pick_service(e: Dictionary) -> void:
	var best := {}
	var site := ProductionManager.site_of(e)
	for m in sim.state.machines:
		if int(m.repairer_id) != 0 or ProductionManager.site_of(m) != site:
			continue
		if not m.broken and int(m.condition) > SERVICE_BELOW:
			continue
		if best.is_empty() or (m.broken and not best.broken) or (m.broken == best.broken and int(m.condition) < int(best.condition)):
			best = m
	if best.is_empty():
		return
	e.job = {"kind": "repair", "phase": "to_source", "ticks_left": 0, "machine_id": best.id, "qty": 0, "product_id": ""}
	e.rest = false
	e.idle = 0
	sim.production.start_repair(best, e.id)


func _targeted_machines() -> Array:
	var ids := []
	for e in sim.state.employees:
		if not e.job.is_empty() and e.job.kind == "haul":
			ids.append(e.job.machine_id)
	return ids


## The first factory's warehouse staff unload the trucks at the dock and
## take goods from its machines to the store; the staff of a factory next
## door take goods from their own machines to the company store.
func _pick_job(e: Dictionary) -> Dictionary:
	var s := sim.state
	var cfg := sim.config
	var leg := sim.buildings.haul_leg_ticks()
	var site := ProductionManager.site_of(e)
	if site == "" and s.dock - _dock_claims() > 0 and s.raw + sim.inventory.carried("unload") < sim.buildings.raw_capacity():
		return {"kind": "unload", "phase": "to_source", "ticks_left": leg, "leg": leg, "machine_id": 0, "qty": 0, "product_id": ""}
	if sim.inventory.finished_free_space() - sim.inventory.carried("haul") - _haul_claims() < cfg.haul_min_boxes:
		return {}
	var targeted := _targeted_machines()
	var best := {}
	for m in s.machines:
		if targeted.has(m.id) or ProductionManager.site_of(m) != site:
			continue
		var full: bool = m.buffer >= sim.production.def_of(m).output_buffer_capacity
		if m.buffer >= cfg.haul_min_boxes or (full and m.buffer > 0):
			if best.is_empty() or m.buffer > best.buffer:
				best = m
	if best.is_empty():
		return {}
	return {"kind": "haul", "phase": "to_source", "ticks_left": leg, "leg": leg, "machine_id": best.id, "qty": 0,
		"product_id": sim.production.def_of(best).output_product_id}


## Workers walking to a machine will each fill up to one batch of store space.
func _haul_claims() -> int:
	var claims := 0
	for e in sim.state.employees:
		if not e.job.is_empty() and e.job.kind == "haul" and e.job.phase == "to_source":
			claims += sim.config.haul_finished_batch
	return claims


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
			var room := sim.inventory.finished_free_space() - sim.inventory.carried("haul")
			qty = mini(mini(cfg.haul_finished_batch, int(m.buffer)), room)
			m.buffer -= maxi(0, qty)
	if qty <= 0:
		e.job = {}
		return
	job.qty = qty
	job.phase = "to_dest"
	job.ticks_left = sim.buildings.haul_leg_ticks()
	job.leg = job.ticks_left
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
		# Store full: wait at the door for a while, then put the goods back.
		job.wait = int(job.get("wait", 0)) + 1
		job.ticks_left = 1
		if int(job.wait) >= FULL_STORE_WAIT_TICKS:
			_drop_carried(e)
		return
	e.job = {}
	sim.emit_event(&"worker_delivered", {"id": e.id, "kind": job.kind, "qty": put})
