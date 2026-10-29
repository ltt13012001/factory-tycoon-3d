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
		sim.buy_line(id)


func test_line_speed_and_manager_make_machines_faster() -> void:
	var sim := _rich_sim()
	var m: Dictionary = sim.state.machines[0]
	check_eq(sim.production.cycle_ticks(m), 24, "base cycle")
	check(sim.upgrade_line_speed().ok, "line speed 1")
	check_eq(sim.production.cycle_ticks(m), 22, "10% faster: 24 / 1.1")
	check(sim.hire(EmployeeManager.MANAGER).ok, "hire factory manager")
	check(not sim.hire(EmployeeManager.MANAGER).ok, "only one factory manager")
	check_eq(sim.production.cycle_ticks(m), 19, "25% faster: 24 / 1.25")
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


func test_site_earns_only_with_head() -> void:
	var sim := _rich_sim()
	_fill_first_factory(sim)
	check(sim.expand("lot_2").ok, "buy land")
	check_eq(sim.expansion.site("lot_2").status, ExpansionManager.LAND, "land owned")
	check(sim.expand("lot_2").ok, "build hall")
	sim.advance_ticks(sim.content.locations["lot_2"].build_hours * sim.config.ticks_per_hour)
	check(sim.expansion.is_ready("lot_2"), "hall ready")
	for i in 3:
		check(sim.buy_line("lot_2").ok, "line")
	var s := sim.expansion.site("lot_2")
	check_eq(sim.expansion.daily_income(s), 0, "no income without a factory manager")
	sim.hire_site_head("lot_2")
	check_eq(sim.expansion.daily_income(s), 3 * 18000, "3 lines earn")
	check(sim.automate_site("lot_2").ok, "automate")
	check_eq(sim.expansion.daily_income(s), 3 * 18000 * 120 / 100, "+20% automation")
	# The day's books include the site and still balance.
	sim.advance_ticks(sim.config.ticks_per_day - sim.state.tick % sim.config.ticks_per_day)
	var r: Dictionary = sim.state.reports[-1]
	check_eq(int(r.stats.branch_income), 3 * 18000 * 120 / 100, "income in report")
	check(int(r.stats.branch_costs) > 0, "costs in report")
	check(r.ledger_ok, "ledger balanced")


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
	check_eq(b.expansion.site("lot_2").lines, 4, "lines restored")


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
