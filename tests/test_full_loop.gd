extends TestCase

const DAYS := 10


func _run(sim: Simulation, from_tick: int, to_tick: int) -> void:
	var bot := AutoPlayer.new(sim)
	for t in range(from_tick, to_tick):
		if t % 15 == 0:
			bot.act()
		sim.step()


func test_ten_days_with_auto_player() -> void:
	var sim := new_sim(2026)
	var errors := []
	sim.event.connect(func(name, data):
		if name == &"day_ended" and not data.ledger_ok:
			errors.append("ledger mismatch on day %d" % data.day))
	var total := days(sim, DAYS)
	_run(sim, 0, total)
	check_eq(errors.size(), 0, "ledger matches cash every day: %s" % str(errors))
	check_eq(sim.state.reports.size(), DAYS, "10 daily reports")
	var cash := sim.config.start_cash
	for r in sim.state.reports:
		check_eq(r.start_cash, cash, "day %d starts with previous end cash" % r.day)
		check_eq(r.end_cash, r.start_cash + r.income - r.expense, "day %d cash = start + income - expense" % r.day)
		cash = r.end_cash
	check_eq(sim.state.cash, cash, "final cash matches reports")
	check_eq(sim.state.machines.size(), 2, "auto player bought the second machine")
	check(sim.state.cash >= sim.config.overdraft_limit, "never below overdraft limit at the end")
	var delivered := 0
	for r in sim.state.reports:
		delivered += int(r.stats.orders_delivered)
	check(delivered >= 8, "delivered orders over 10 days (%d)" % delivered)
	check_eq(sim.state.tutorial_step, Tutorial.STEPS.size(), "tutorial completed by the loop")
	print("       10 days: cash %s, reputation %d, delivered %d, bought 2nd machine: %s" % [
		Fmt.money(sim.state.cash), sim.state.reputation, delivered, sim.state.machines.size() == 2])
	for r in sim.state.reports:
		print("         day %2d profit %10s cash %10s produced %3d" % [r.day, Fmt.money(r.profit), Fmt.money(r.end_cash), r.stats.produced])


func test_save_midway_gives_identical_result() -> void:
	var straight := new_sim(2026)
	var total := days(straight, DAYS)
	_run(straight, 0, total)

	var first := new_sim(2026)
	var half := days(first, DAYS / 2.0) + 333
	_run(first, 0, half)
	var json := first.to_json()
	var resumed := blank_sim()
	check(resumed.load_json(json), "load midway save")
	_run(resumed, half, total)
	check_eq(resumed.to_json(), straight.to_json(), "save + load + continue == uninterrupted run")
