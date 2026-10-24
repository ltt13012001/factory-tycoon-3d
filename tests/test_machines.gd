extends TestCase


func test_unlocks() -> void:
	var sim := new_sim()
	var blow: MachineDef = sim.content.machines["blow_molder"]
	check(sim.production.unlock_reason(blow) != "", "blow molder locked on day 1")
	sim.state.cash = 1000000
	check(not sim.buy_machine(1, "blow_molder").ok, "cannot buy a locked machine")
	sim.state.tick = days(sim, 1)
	check_eq(sim.production.unlock_reason(blow), "", "unlocked on day 2 at reputation 50")
	check(sim.buy_machine(1, "blow_molder").ok, "buy blow molder")


func test_bottles_and_their_orders() -> void:
	var sim := new_sim()
	sim.state.cash = 1000000
	sim.state.tick = days(sim, 1)
	sim.buy_machine(1, "blow_molder")
	sim.hire(EmployeeManager.OPERATOR)
	sim.state.raw = 400
	sim.state.raw_value = 400 * 200
	var offered := {}
	sim.event.connect(func(name, data):
		if name == &"order_offered":
			offered[data.product_id] = true)
	sim.advance_ticks(days(sim, 2))
	var m := sim.production.machine_in_slot(1)
	check(m.produced > 30, "blow molder made bottles (%d)" % m.produced)
	check(sim.state.finished_of("water_bottle") + int(m.buffer) > 0, "bottles in stock")
	check(offered.has("water_bottle"), "bottle orders appear once a blow molder exists")
	check(not offered.has("storage_shelf"), "no shelf orders without a shelf press")


func test_auto_machine_needs_no_operator() -> void:
	var sim := new_sim()
	sim.state.cash = 2000000
	sim.state.reputation = 70
	sim.state.tick = days(sim, 4)
	check(sim.buy_machine(2, "auto_molder").ok, "buy auto molder")
	sim.advance_ticks(40)
	var m := sim.production.machine_in_slot(2)
	check_eq(m.operator_id, 0, "no operator assigned")
	check_eq(m.status, ProductionManager.RUNNING, "runs by itself")


func test_upgrade_makes_faster() -> void:
	var sim := new_sim()
	var m: Dictionary = sim.state.machines[0]
	check_eq(sim.production.cycle_ticks(m), 24, "level 1 cycle")
	check_eq(sim.production.upgrade_cost(m), 60000, "upgrade to 2 costs 50% of price")
	check(sim.upgrade_machine(m.id).ok, "upgrade")
	check_eq(sim.production.cycle_ticks(m), 20, "15% faster")
	sim.state.cash = 1000000
	check(sim.upgrade_machine(m.id).ok, "upgrade to 3")
	check_eq(sim.production.cycle_ticks(m), 17, "30% faster")
	check(not sim.upgrade_machine(m.id).ok, "max level 3")


func test_wear_breakdown_and_repair() -> void:
	var sim := new_sim()
	var m: Dictionary = sim.state.machines[0]
	sim.state.raw = 600
	m.condition = 1
	m.wear_count = 2
	sim.advance_ticks(24)
	check(m.broken, "breaks at condition 0")
	check_eq(m.status, ProductionManager.BROKEN, "status broken")
	var produced: int = m.produced + m.defects
	sim.advance_ticks(100)
	check_eq(m.produced + m.defects, produced, "broken machine makes nothing")
	var cash := sim.state.cash
	check(sim.repair_machine(m.id).ok, "owner repairs")
	check_eq(sim.state.cash, cash - 100 * 150, "repair cost per missing point")
	sim.advance_ticks(sim.config.repair_walk_ticks + 60)
	check(not m.broken and m.condition == 100, "repaired to 100")
	check(sim.economy.ledger_balanced(), "ledger balanced")


func test_technician_services_machines() -> void:
	var sim := new_sim()
	sim.hire(EmployeeManager.TECHNICIAN)
	var m: Dictionary = sim.state.machines[0]
	m.condition = 50
	var cash := sim.state.cash
	sim.advance_ticks(1)
	check(int(m.repairer_id) != 0, "technician picks the worn machine")
	sim.advance_ticks(sim.config.repair_walk_ticks + 60)
	check_eq(m.condition, 100, "serviced")
	check_eq(sim.state.cash, cash, "technician repairs are free")


func test_constructions() -> void:
	var sim := new_sim()
	sim.state.cash = 1000000
	check_eq(sim.buildings.raw_capacity(), 600, "base raw capacity")
	check(sim.build("warehouse_expansion").ok, "start warehouse expansion")
	check(not sim.build("solar_roof").ok, "one project at a time")
	sim.advance_ticks(6 * 60)
	check_eq(sim.buildings.raw_capacity(), 1200, "+600 raw")
	check_eq(sim.buildings.finished_capacity(), 600, "+300 finished")
	check(sim.build("hall_expansion").ok, "start hall expansion")
	sim.advance_ticks(8 * 60)
	check_eq(sim.buildings.machine_slots(), 9, "+3 slots")
	check(sim.buy_machine(8).ok, "buy into a new slot")
	check(sim.build("solar_roof").ok, "solar")
	sim.advance_ticks(6 * 60)
	check_eq(sim.buildings.power_cost(15), 9, "40% cheaper power")


func test_automation() -> void:
	var sim := new_sim()
	sim.set_auto_buy(true)
	sim.state.raw = 50
	sim.advance_ticks(60)
	check_eq(sim.inventory.pending_material(), 250, "auto-buy ordered a lot")
	sim.set_auto_ship(true)
	var o: Dictionary = sim.orders.with_status(OrderManager.OFFERED)[0]
	sim.accept_order(o.id)
	sim.state.finished = {"plastic_box": o.qty}
	sim.advance_ticks(1)
	check_eq(o.status, OrderManager.SHIPPING, "auto-ship sends ready orders")


func test_migrate_v1_save() -> void:
	var sim := new_sim()
	var d := sim.to_save_dict()
	# Shape of a 0.1 save
	d.save_version = 1
	d.finished = 42
	d.erase("buildings")
	d.erase("construction")
	d.erase("settings")
	d.erase("order_spawn")
	for m in d.machines:
		for k in ["level", "condition", "wear_count", "broken", "repair_ticks_left", "repairer_id"]:
			m.erase(k)
	for o in d.orders:
		o.erase("product_id")
	var b := blank_sim()
	check(b.load_save_dict(d), "v1 save loads")
	check_eq(b.state.finished_of("plastic_box"), 42, "boxes kept")
	check_eq(b.state.machines[0].level, 1, "machine level added")
	check_eq(b.state.orders[0].product_id, "plastic_box", "order product added")
	b.advance_ticks(days(b, 1))
	check(b.state.reports[-1].ledger_ok, "runs a day after migration")
