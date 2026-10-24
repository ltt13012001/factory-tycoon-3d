extends TestCase


func test_full_day_output() -> void:
	var sim := new_sim()
	sim.state.raw = 600
	sim.state.raw_value = 600 * 200
	var m: Dictionary = sim.state.machines[0]
	sim.advance_ticks(days(sim, 1) - 1)
	check_eq(m.produced + m.defects, 59, "59 cycles finished before the last tick")
	sim.advance_ticks(1)
	var st: Dictionary = sim.state.reports[-1].stats
	check_eq(st.produced + st.defects, 60, "6 s cycle -> 60 cycles per day")
	check(st.defects >= 0 and st.defects <= 10, "about 5%% defects (got %d)" % st.defects)
	check_eq(st.power, 60 * 15, "power $0,15 per cycle")
	check_eq(sim.state.raw, 600 - 60, "one unit per cycle")
	check_eq(sim.state.finished_total() + m.buffer + sim.inventory.carried("haul"), st.produced, "every good box is in a store")


func test_stops_without_operator() -> void:
	var sim := new_sim()
	sim.fire(sim.state.employees[0].id)
	sim.advance_ticks(100)
	var m: Dictionary = sim.state.machines[0]
	check_eq(m.status, ProductionManager.NO_OPERATOR, "status no operator")
	check_eq(m.produced + m.defects, 0, "nothing produced")
	check_eq(sim.state.raw, 100, "no material used")


func test_stops_without_material() -> void:
	var sim := new_sim()
	sim.state.raw = 3
	sim.advance_ticks(24 * 5)
	var m: Dictionary = sim.state.machines[0]
	check_eq(m.produced + m.defects, 3, "used exactly the 3 units")
	check_eq(m.status, ProductionManager.NO_MATERIAL, "status no material")
	check_eq(sim.state.raw_value, 0, "material book value fully expensed")


func test_stops_when_output_full() -> void:
	var sim := new_sim()
	sim.fire(sim.state.employees[1].id)  # nobody empties the pallet
	sim.advance_ticks(24 * 40)
	var m: Dictionary = sim.state.machines[0]
	check_eq(m.buffer, 20, "pallet holds 20")
	check_eq(m.status, ProductionManager.OUTPUT_FULL, "status output full")


func test_stops_when_finished_store_full() -> void:
	var sim := new_sim()
	sim.state.finished = {"plastic_box": sim.config.finished_capacity}
	sim.advance_ticks(24 * 40)
	var m: Dictionary = sim.state.machines[0]
	check_eq(sim.state.finished_total(), 300, "store stays at capacity")
	check_eq(m.status, ProductionManager.OUTPUT_FULL, "machine stops when store is full")


func test_second_machine_needs_operator() -> void:
	var sim := new_sim()
	check(sim.buy_machine(1).ok, "buy second machine")
	check_eq(sim.state.cash, 100000 - 120000, "price $1.200 into overdraft")
	sim.advance_ticks(10)
	var m2: Dictionary = sim.production.machine_in_slot(1)
	check_eq(m2.status, ProductionManager.NO_OPERATOR, "idle without operator")
	check(sim.hire(EmployeeManager.OPERATOR).ok, "hire operator")
	check(m2.operator_id != 0, "new operator auto-assigned")
	check(not sim.buy_machine(1).ok, "slot taken")
	var r := sim.sell_machine(m2.id)
	check(r.ok, "sell machine")
	check_eq(sim.state.cash, 100000 - 120000 - 10000 + 60000, "50% resale")
	check(sim.state.ledger.size() > 0 and sim.economy.ledger_balanced(), "ledger balanced")
