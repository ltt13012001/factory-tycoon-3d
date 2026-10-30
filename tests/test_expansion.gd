extends TestCase


func _rich_sim() -> Simulation:
	var sim := new_sim()
	sim.state.cash = 1000000000
	sim.state.day_start_cash = sim.state.cash
	return sim


func _fill_first_factory(sim: Simulation) -> void:
	for slot in sim.buildings.machine_slots():
		if sim.production.machine_in_slot(slot).is_empty():
			sim.buy_machine(slot)


func _open(sim: Simulation, id: String, lines: int = 0) -> void:
	var l: LocationDef = sim.content.locations[id]
	check(sim.expand(id).ok, "first step " + id)
	sim.advance_ticks(maxi(l.survey_hours, 1) * sim.config.ticks_per_hour)
	check(sim.expand(id).ok, "build " + id)
	sim.advance_ticks(l.build_hours * sim.config.ticks_per_hour)
	check(sim.expansion.is_ready(id), id + " ready")
	check(sim.hire_site_head(id).ok, "head " + id)
	for i in lines:
		if sim.expansion.is_factory(id):
			check(sim.buy_machine(i, "", id).ok, "machine %d in %s" % [i, id])
		else:
			sim.buy_line(id)


func test_line_speed_and_manager_make_machines_faster() -> void:
	var sim := _rich_sim()
	var m: Dictionary = sim.state.machines[0]
	check_eq(sim.production.cycle_ticks(m), 12, "base cycle")
	check(sim.upgrade_line_speed().ok, "line speed 1")
	check_eq(sim.production.cycle_ticks(m), 11, "10% faster: 12 / 1.1")
	check(sim.hire(EmployeeManager.MANAGER).ok, "hire factory manager")
	check(not sim.hire(EmployeeManager.MANAGER).ok, "only one factory manager")
	check_eq(sim.production.cycle_ticks(m), 10, "25% faster: 12 / 1.25")
	for i in 4:
		sim.upgrade_line_speed()
	check(not sim.upgrade_line_speed().ok, "line speed max level")
	check_eq(sim.expansion.speed_bonus_percent(), 65, "5 levels + manager")


func test_manager_wage_and_auto_repair() -> void:
	var sim := _rich_sim()
	var wages := sim.employees.total_wages()
	sim.hire(EmployeeManager.MANAGER)
	check_eq(sim.employees.total_wages() - wages, sim.config.wage_per_day * EmployeeManager.MANAGER_WAGE_FACTOR, "manager wage")
	var m: Dictionary = sim.state.machines[0]
	m.broken = true
	m.condition = 0
	sim.advance_ticks(20)
	check(int(m.repairer_id) == ProductionManager.OWNER or not m.broken, "manager called a repair")


func test_land_needs_full_factory() -> void:
	var sim := _rich_sim()
	check(sim.expansion.block_reason("lot_2") != "", "plot locked while the hall has free places")
	check(not sim.expand("lot_2").ok, "cannot buy land yet")
	_fill_first_factory(sim)
	check_eq(sim.expansion.block_reason("lot_2"), "", "plot open once the hall is full")
	check(sim.expansion.block_reason("lot_3") != "", "next plot waits for factory 2")
	check(sim.expansion.block_reason("binh_duong") != "", "provinces need a company")


func test_branch_earns_only_with_head() -> void:
	var sim := _rich_sim()
	sim.state.company_tier = 1
	var l: LocationDef = sim.content.locations["binh_duong"]
	check(sim.expand("binh_duong").ok, "survey")
	sim.advance_ticks(l.survey_hours * sim.config.ticks_per_hour)
	check(sim.expand("binh_duong").ok, "open branch")
	sim.advance_ticks(l.build_hours * sim.config.ticks_per_hour)
	check(sim.expansion.is_ready("binh_duong"), "branch ready")
	for i in 3:
		check(sim.buy_line("binh_duong").ok, "line")
	var s := sim.expansion.site("binh_duong")
	s.market = 100
	check_eq(sim.expansion.daily_income(s), 0, "no income without a director")
	sim.hire_site_head("binh_duong")
	check_eq(sim.expansion.daily_income(s), 3 * l.line_profit_per_day, "3 lines earn")
	check(sim.automate_site("binh_duong").ok, "automate")
	check_eq(sim.expansion.daily_income(s), 3 * l.line_profit_per_day * 120 / 100, "+20% automation")
	# The day's books include the branch and still balance.
	sim.advance_ticks(sim.config.ticks_per_day - sim.state.tick % sim.config.ticks_per_day)
	var r: Dictionary = sim.state.reports[-1]
	check_eq(int(r.stats.branch_income), 3 * l.line_profit_per_day * 120 / 100, "income in report")
	check(int(r.stats.branch_costs) > 0, "costs in report")
	check(r.ledger_ok, "ledger balanced")


func _build_lot_2(sim: Simulation) -> void:
	_fill_first_factory(sim)
	check(sim.expand("lot_2").ok, "buy land")
	check_eq(sim.expansion.site("lot_2").status, ExpansionManager.LAND, "land owned")
	check(not sim.buy_machine(0, "", "lot_2").ok, "no machines before the hall is built")
	check(not sim.hire(EmployeeManager.OPERATOR, "lot_2").ok, "no staff before the hall is built")
	check(sim.expand("lot_2").ok, "build hall")
	sim.advance_ticks(sim.content.locations["lot_2"].build_hours * sim.config.ticks_per_hour)
	check(sim.expansion.is_ready("lot_2"), "hall ready")


func test_factory_next_door_runs_like_the_first() -> void:
	var sim := _rich_sim()
	_build_lot_2(sim)
	check_eq(sim.production.slot_count("lot_2"), 9, "9 machine places")
	check(not sim.buy_line("lot_2").ok, "no abstract lines in a factory next door")
	var raw_cap := sim.buildings.raw_capacity()
	check_eq(raw_cap, sim.config.raw_capacity + sim.buildings.bonus("raw_capacity_bonus") + ExpansionManager.FACTORY_RAW_CAPACITY, "own store adds room")
	check(sim.buy_machine(0, "", "lot_2").ok, "machine in factory 2")
	check(sim.buy_machine(1, "", "lot_2").ok, "second machine in factory 2")
	check(not sim.buy_machine(1, "", "lot_2").ok, "place taken")
	check(not sim.buy_machine(9, "", "lot_2").ok, "no 10th place")
	var m: Dictionary = sim.production.machine_in_slot(0, "lot_2")
	check_eq(m.site, "lot_2", "machine belongs to factory 2")
	check(sim.production.machine_in_slot(0).site == "", "slot 0 of the first factory is another machine")
	# Operators of the first factory are busy there; factory 2 needs its own.
	check_eq(int(m.operator_id), 0, "no operator borrowed from the first factory")
	check(sim.hire(EmployeeManager.OPERATOR, "lot_2").ok, "hire operator for factory 2")
	check(sim.hire(EmployeeManager.WAREHOUSE, "lot_2").ok, "hire warehouse worker for factory 2")
	var op := sim.state.find_by_id(sim.state.employees, int(m.operator_id))
	check(not op.is_empty() and op.site == "lot_2", "operator of factory 2 runs its machine")
	check_eq(sim.employees.count(EmployeeManager.OPERATOR, "lot_2"), 1, "count per factory")
	sim.state.raw = 400
	var before := sim.state.finished_of("plastic_box")
	sim.advance_ticks(sim.config.ticks_per_day - sim.state.tick % sim.config.ticks_per_day)  # next morning
	sim.state.raw = 400
	sim.advance_ticks(sim.config.ticks_per_hour * 4)
	check(int(m.produced) > 0, "factory 2 machine produces")
	check(sim.state.finished_of("plastic_box") > before, "goods reach the company store")
	# Its warehouse worker never hauls from the first factory's machines.
	for e in sim.employees.staff_at("lot_2"):
		if not e.job.is_empty() and e.job.kind == "haul":
			check_eq(sim.state.find_by_id(sim.state.machines, int(e.job.machine_id)).site, "lot_2", "hauls in its own factory")
	check(sim.expansion.factories_operating() >= 2, "factory 2 counts as operating")


func test_factory_head_speeds_up_and_calls_repairs() -> void:
	var sim := _rich_sim()
	_build_lot_2(sim)
	sim.buy_machine(0, "", "lot_2")
	var m: Dictionary = sim.production.machine_in_slot(0, "lot_2")
	var base := sim.production.cycle_ticks(m)
	check(sim.hire_site_head("lot_2").ok, "factory manager for factory 2")
	check(sim.production.cycle_ticks(m) < base, "manager makes factory 2 faster")
	check_eq(sim.expansion.speed_bonus_percent("lot_2"), ExpansionManager.MANAGER_SPEED_PERCENT, "only the manager bonus")
	check(sim.automate_site("lot_2").ok, "automation level 1")
	check_eq(sim.expansion.speed_bonus_percent("lot_2"), ExpansionManager.MANAGER_SPEED_PERCENT + ExpansionManager.AUTOMATION_SPEED_PERCENT, "automation speeds machines up")
	check_eq(sim.expansion.speed_bonus_percent(""), 0, "first factory unchanged")
	sim.state.tick = sim.state.tick - sim.state.tick % sim.config.ticks_per_day + 4
	m.broken = true
	m.condition = 0
	sim.advance_ticks(20)
	check(int(m.repairer_id) == ProductionManager.OWNER or not m.broken, "factory manager called a repair")


func test_old_lines_become_machines() -> void:
	var sim := _rich_sim()
	_build_lot_2(sim)
	sim.hire_site_head("lot_2")
	var d := sim.to_save_dict()
	d.save_version = 5
	for m in d.machines:
		m.erase("site")
	for e in d.employees:
		e.erase("site")
	d.sites[0].lines = 4
	var cash := int(d.cash)
	var b := blank_sim()
	check(b.load_save_dict(d), "v5 save loads")
	check_eq(b.production.machines_at("lot_2").size(), 4, "4 lines became 4 machines")
	check_eq(b.employees.count(EmployeeManager.OPERATOR, "lot_2"), 4, "with an operator each")
	check_eq(b.employees.count(EmployeeManager.WAREHOUSE, "lot_2"), 2, "and warehouse staff")
	check(b.state.cash > cash, "price difference paid back")
	check(b.economy.ledger_balanced(), "ledger balances")
	for m in b.production.machines_at("lot_2"):
		check(int(m.operator_id) != 0, "every converted machine has an operator")
	check_eq(b.production.machines_at("").size(), sim.production.machines_at("").size(), "first factory unchanged")


func test_company_stages_to_multinational() -> void:
	var sim := _rich_sim()
	check_eq(sim.expansion.tier_name(), "Xưởng sản xuất", "start as a workshop")
	check(not sim.advance_tier().ok, "needs a second factory")
	_fill_first_factory(sim)
	_open(sim, "lot_2", 2)
	check(sim.advance_tier().ok, "company")
	check(sim.hire_executive("production_director").ok, "appoint production director")
	check(not sim.hire_executive("ceo").ok, "CEO needs a multinational group")
	_open(sim, "binh_duong", 1)
	check(sim.expansion.site("binh_duong").market >= 85, "survey sets the market")
	check(not sim.advance_tier().ok, "corporation needs 2 domestic branches")
	_open(sim, "bac_ninh", 1)
	check(sim.advance_tier().ok, "corporation")
	_open(sim, "thailand", 1)
	check(sim.advance_tier().ok, "group")
	check(not sim.advance_tier().ok, "multinational needs 3 countries")
	_open(sim, "indonesia", 1)
	_open(sim, "india", 1)
	check(sim.advance_tier().ok, "multinational group")
	check_eq(sim.expansion.tier_name(), "Tập đoàn đa quốc gia", "final stage")
	check(sim.hire_executive("ceo").ok, "appoint CEO")
	check(not sim.advance_tier().ok, "no stage after multinational")


func test_save_round_trip_with_sites() -> void:
	var sim := _rich_sim()
	_fill_first_factory(sim)
	_open(sim, "lot_2", 4)
	sim.upgrade_line_speed()
	var json := sim.to_json()
	var b := blank_sim()
	check(b.load_json(json), "load")
	check_eq(b.to_json(), json, "identical after load")
	check_eq(b.production.machines_at("lot_2").size(), 4, "machines of factory 2 restored")


func test_old_save_migrates() -> void:
	var sim := new_sim()
	var d := sim.to_save_dict()
	d.save_version = 2
	for k in ["line_speed_level", "company_tier", "sites", "executives"]:
		d.erase(k)
	var b := blank_sim()
	check(b.load_save_dict(d), "v2 save loads")
	check_eq(b.state.sites.size(), 0, "no sites")
	check_eq(b.expansion.tier(), 0, "workshop stage")


func test_rebalance_tops_up_old_saves() -> void:
	var sim := new_sim()
	var d := sim.to_save_dict()
	d.save_version = 3
	var spent := 0
	for e in d.ledger:
		spent += int(e.amount)
	d.cash = -20000
	d.day_start_cash = -20000 - spent
	var b := blank_sim()
	check(b.load_save_dict(d), "v3 save loads")
	check_eq(b.state.cash, 300000, "cash topped up to the new start")
	check(b.economy.ledger_balanced(), "ledger still balances")
