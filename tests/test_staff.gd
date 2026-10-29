## Shifts and overtime, pay level and mood, strikes, resting when there is
## nothing to do, auto-buy amounts and orders accepted by a director.
extends TestCase


func test_overtime_pay() -> void:
	var sim := new_sim()
	var e: Dictionary = sim.state.employees[0]
	var base := sim.config.wage_per_day
	check_eq(sim.employees.wage_of(e), base, "8-hour shift: standard wage")
	check(sim.set_shift(12).ok, "set 12-hour shift")
	check_eq(sim.employees.wage_of(e), base + base * 4 * 150 / 800, "4 overtime hours at 150%")
	check(sim.set_shift(14).ok, "set 14-hour shift")
	check_eq(sim.employees.wage_of(e), base + base * 6 * 150 / 800, "6 overtime hours at 150%")
	check(not sim.set_shift(16).ok, "16 hours refused")
	sim.set_shift(8)
	sim.set_pay(80)
	check_eq(sim.employees.wage_of(e), base * 80 / 100, "pay level 80%")


func test_overtime_makes_more() -> void:
	var outputs := []
	for hours in [8, 14]:
		var sim := new_sim()
		sim.state.raw = 600
		sim.state.raw_value = 600 * 200
		sim.set_shift(hours)
		sim.advance_ticks(days(sim, 1))
		var st: Dictionary = sim.state.reports[-1].stats
		outputs.append(st.produced + st.defects)
	check_eq(outputs[0], 120, "120 cycles in 8 hours")
	check(outputs[1] > outputs[0] * 3 / 2, "14 hours make much more (got %d)" % outputs[1])


func test_staff_go_home_and_come_back() -> void:
	var sim := new_sim()
	sim.advance_ticks(EmployeeManager.STANDARD_SHIFT * sim.config.ticks_per_hour + 5)
	var e: Dictionary = sim.state.employees[0]
	check(e.off, "operator went home after the shift")
	check(not sim.employees.is_present(e), "not present at night")
	sim.advance_ticks(days(sim, 1) - EmployeeManager.STANDARD_SHIFT * sim.config.ticks_per_hour - 5 + 1)
	check(sim.employees.on_shift(), "next shift started")
	check_eq(e.away, EmployeeManager.RETURN_TICKS - 1, "walking in from the gate")
	sim.advance_ticks(EmployeeManager.RETURN_TICKS)
	check(sim.employees.is_present(e), "back at work")


func test_idle_staff_rest_and_return() -> void:
	var sim := new_sim()
	sim.state.raw = 0
	sim.state.raw_value = 0
	sim.advance_ticks(EmployeeManager.REST_AFTER_TICKS + 10)
	var op: Dictionary = sim.state.employees[0]
	var wh: Dictionary = sim.state.employees[1]
	check(op.rest, "operator rests without material")
	check(wh.rest, "warehouse worker rests with nothing to carry")
	var m: Dictionary = sim.state.machines[0]
	check_eq(m.status, ProductionManager.NO_MATERIAL, "machine waits for material")
	sim.state.raw = 50
	sim.state.raw_value = 50 * 200
	sim.advance_ticks(1)
	check(not op.rest, "operator called back")
	check_eq(m.status, ProductionManager.OPERATOR_AWAY, "machine waits for the operator")
	sim.advance_ticks(EmployeeManager.RETURN_TICKS + 1)
	check_eq(m.status, ProductionManager.RUNNING, "running again")


## The bug behind workers twitching when there were no orders: a worker
## waiting at a full store. Now the goods go back and the worker rests.
func test_full_store_wait_ends() -> void:
	var sim := new_sim()
	var m: Dictionary = sim.state.machines[0]
	sim.state.finished = {"plastic_box": sim.config.finished_capacity - 15}
	m.buffer = 40
	var wh: Dictionary = sim.state.employees[1]
	sim.advance_ticks(1)
	check_eq(wh.job.get("kind", ""), "haul", "fetches boxes while there is room")
	sim.advance_ticks(2 * sim.buildings.haul_leg_ticks())
	check_eq(sim.state.finished_total(), sim.config.finished_capacity, "store filled")
	check(wh.job.is_empty(), "no worker waiting at the full store")
	sim.advance_ticks(EmployeeManager.REST_AFTER_TICKS + EmployeeManager.FULL_STORE_WAIT_TICKS)
	check(wh.job.is_empty(), "no new trips to a full store")
	check(wh.rest, "rests instead")
	check_eq(sim.state.finished_total() + int(m.buffer) + sim.state.scrap_total - int(m.defects), sim.config.finished_capacity - 15 + 40 + int(m.produced), "no box lost")


func test_mood_and_strike() -> void:
	var sim := new_sim()
	var tph := sim.config.ticks_per_hour
	sim.set_pay(70)
	sim.set_shift(14)
	check(sim.employees.average_mood_target() < EmployeeManager.STRIKE_BELOW, "low pay and long hours: unhappy")
	var events := []
	sim.event.connect(func(n, _d): events.append(n))
	sim.advance_ticks(days(sim, 3))
	check(sim.employees.average_mood() < EmployeeManager.STRIKE_BELOW + 5, "mood dropped (%d)" % sim.employees.average_mood())
	check(events.has(&"staff_unhappy"), "warned before the strike")
	check(events.has(&"strike_started"), "staff went on strike")
	check(sim.employees.on_strike(), "still on strike")
	var m: Dictionary = sim.state.machines[0]
	# Morning of the next day: still nothing is made during a strike.
	sim.advance_ticks(days(sim, 1) - posmod(sim.state.tick, sim.config.ticks_per_day) + 2 * tph)
	check_eq(m.status, ProductionManager.STRIKE, "machine stopped by the strike")
	var made := int(m.produced)
	sim.advance_ticks(2 * tph)
	check_eq(int(m.produced), made, "nothing produced during the strike")
	sim.set_pay(120)
	sim.set_shift(8)
	sim.advance_ticks(tph)
	check(not sim.employees.on_strike(), "strike over after a pay rise")
	check(events.has(&"strike_ended"), "strike end announced")


func test_good_pay_no_strike() -> void:
	var sim := new_sim()
	sim.set_shift(14)
	sim.set_pay(110)
	var events := []
	sim.event.connect(func(n, _d): events.append(n))
	sim.advance_ticks(days(sim, 5))
	check(not events.has(&"strike_started"), "no strike with fair pay and overtime")


func test_auto_buy_amounts() -> void:
	var sim := new_sim()
	sim.state.cash = 1000000
	sim.state.day_start_cash = 1000000
	sim.set_auto_buy_amounts(330, 260)
	check_eq(sim.inventory.auto_buy_lot(), 350, "lot snapped to 50")
	check_eq(sim.inventory.auto_buy_threshold(), 250, "threshold snapped to 50")
	sim.state.raw = 100
	sim.state.raw_value = 100 * 200
	sim.set_auto_buy(true)
	sim.advance_ticks(sim.config.ticks_per_hour)
	check_eq(sim.inventory.pending_material(), 350, "auto-buy ordered the chosen amount")
	check(sim.economy.ledger_balanced(), "ledger balanced")


func test_director_accepts_orders() -> void:
	var sim := new_sim()
	check(not sim.set_auto_accept(true).ok, "needs a director")
	sim.state.cash = 100000000
	sim.state.day_start_cash = sim.state.cash
	sim.state.company_tier = 1
	check(sim.hire_executive("production_director").ok, "hire production director")
	check(sim.state.settings.auto_accept, "director accepts orders by default")
	var before := sim.orders.with_status(OrderManager.ACCEPTED).size()
	sim.advance_ticks(15)
	check(sim.orders.with_status(OrderManager.ACCEPTED).size() > before, "the open offer was accepted")
	check(sim.set_auto_accept(false).ok, "can be turned off")


func test_old_save_gets_staff_fields() -> void:
	var sim := new_sim()
	var d := sim.to_save_dict()
	d.save_version = 4
	for e in d.employees:
		for k in ["mood", "rest", "away", "idle", "off"]:
			e.erase(k)
	d.settings.erase("shift_hours")
	d.erase("strike")
	var b := blank_sim()
	check(b.load_save_dict(d), "old save loads")
	check_eq(int(b.state.employees[0].mood), 70, "mood added")
	check_eq(b.employees.shift_hours(), 8, "standard shift")
	b.advance_ticks(100)
	check(b.state.machines[0].produced > 0, "runs after loading")
