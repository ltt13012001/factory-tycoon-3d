extends TestCase


func test_start_state() -> void:
	var sim := new_sim()
	check_eq(sim.state.cash, 100000, "start cash $1.000")
	check_eq(sim.state.reputation, 50, "start reputation")
	check_eq(sim.state.raw, 100, "start material")
	check_eq(sim.state.machines.size(), 1, "one machine")
	check_eq(sim.employees.count(EmployeeManager.OPERATOR), 1, "one operator")
	check_eq(sim.employees.count(EmployeeManager.WAREHOUSE), 1, "one warehouse worker")
	check_eq(sim.state.machines[0].operator_id, sim.state.employees[0].id, "operator assigned")
	check_eq(sim.orders.with_status(OrderManager.OFFERED).size(), 1, "first offer waiting")


func test_buy_material_and_delivery() -> void:
	var sim := new_sim()
	var r := sim.buy_material(100)
	check(r.ok, "buy 100 ok")
	check_eq(sim.state.cash, 100000 - 22000, "100 x $2 + $20 shipping")
	check_eq(sim.state.dock, 0, "nothing at dock yet")
	sim.advance_ticks(hours(sim, 2) - 1)
	check_eq(sim.state.dock, 0, "not arrived 1 tick early")
	sim.advance_ticks(1)
	check_eq(sim.state.dock, 100, "arrives after 2 game hours")
	# 4 trips of 25 bags, 10 s each
	sim.advance_ticks(4 * 2 * sim.config.haul_leg_ticks + 4)
	check_eq(sim.state.dock, 0, "warehouse worker unloaded the dock")
	check_eq(sim.state.purchases.size(), 0, "purchase closed")
	check(not sim.buy_material(123).ok, "invalid lot size rejected")


func test_raw_capacity() -> void:
	var sim := new_sim()
	check(sim.buy_material(500).ok, "fill store to 600")
	var r := sim.buy_material(100)
	check(not r.ok, "store full rejects more")


func test_end_of_day_costs() -> void:
	var sim := new_sim()
	sim.fire(sim.state.employees[0].id)  # no production, no power
	var cash_before := sim.state.cash
	sim.advance_ticks(days(sim, 1))
	var report: Dictionary = sim.state.reports[-1]
	check_eq(sim.state.cash, cash_before - 4000 - 4000, "1 wage + rent")
	check(report.ledger_ok, "ledger balanced")
	check_eq(report.stats.wages, 4000, "wages in report")
	check_eq(report.profit, -8000, "profit = -wages - rent")
	check_eq(report.end_cash, sim.state.cash, "report end cash")


func test_overdraft() -> void:
	var sim := new_sim()
	sim.state.cash = 60000
	check(not sim.buy_machine(1).ok, "cannot go below -$500")
	sim.state.cash = -10000
	sim.economy.reset_day_stats()
	sim.fire(sim.state.employees[0].id)
	sim.advance_ticks(days(sim, 1))
	# -100 - 40 wage - 40 rent = -180 -> 2% interest = 3,60
	check_eq(sim.state.reports[-1].stats.interest, 360, "2% interest on negative cash")
	check_eq(sim.state.cash, -18000 - 360, "cash after interest")
	check(sim.state.reports[-1].ledger_ok, "ledger balanced with overdraft")


func test_money_format() -> void:
	check_eq(Fmt.money(100000), "$1.000", "thousands")
	check_eq(Fmt.money(1234567), "$12.345,67", "cents")
	check_eq(Fmt.money(-50000), "-$500", "negative")
	check_eq(Fmt.money(15), "$0,15", "small")
