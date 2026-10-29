## Prints how a typical player's money develops over a few weeks, to check
## the economy after balancing changes:
##   godot --headless --path . --script res://tests/balance_report.gd
## The player accepts every order it can make in time, ships when ready,
## buys material when low, repairs, and buys one more machine (with an
## operator) whenever it has the cash and the orders to keep it busy.
extends SceneTree

const DAYS := 15


func _initialize() -> void:
	for seed in [1, 2, 3]:
		_run(seed)
	quit()


func _run(seed: int) -> void:
	var sim := Simulation.new()
	sim.new_game(seed)
	print("--- seed %d ---" % seed)
	for t in DAYS * sim.config.ticks_per_day:
		if t % 15 == 0:
			_act(sim)
		sim.step()
	for r in sim.state.reports:
		print("day %2d profit %10s cash %10s produced %4d delivered %2d machines %d staff %d" % [
			r.day, Fmt.money(r.profit), Fmt.money(r.end_cash), r.stats.produced, r.stats.orders_delivered,
			sim.state.machines.size(), sim.state.employees.size()])
	sim.dispose()


func _act(sim: Simulation) -> void:
	var s := sim.state
	for o in sim.orders.with_status(OrderManager.ACCEPTED):
		if sim.orders.is_ready(o.id):
			sim.ship_order(o.id)
	for o in sim.orders.with_status(OrderManager.OFFERED):
		var h := sim.orders.hours_needed(o.id)
		if h >= 0 and h <= int(o.deadline_days) * 24 - 4:
			sim.accept_order(o.id)
	var stock := sim.inventory.material_on_hand() + sim.inventory.pending_material()
	if stock < 150 * maxi(1, s.machines.size()):
		var lot := 500 if sim.inventory.raw_free_space() >= 500 else (250 if sim.inventory.raw_free_space() >= 250 else 100)
		if s.cash > sim.inventory.lot_cost(lot):
			sim.buy_material(lot)
	for m in s.machines:
		if (m.broken or int(m.condition) < 25) and int(m.repairer_id) == 0 and s.cash > sim.production.repair_cost(m):
			sim.repair_machine(m.id)
	# Grow: a machine for whichever product has open demand, then staff it.
	var slot := s.machines.size()
	if slot >= sim.buildings.machine_slots():
		return
	for def_id in ["basic_injection_molder", "blow_molder", "industrial_molder", "shelf_press"]:
		var d: MachineDef = sim.content.machines[def_id]
		if sim.production.unlock_reason(d) != "" or s.cash < d.price + sim.config.hire_fee + 30000:
			continue
		if sim.production.produces(d.output_product_id) and def_id != "industrial_molder":
			continue
		if sim.buy_machine(slot, def_id).ok:
			sim.hire(EmployeeManager.OPERATOR)
			if s.machines.size() % 3 == 0:
				sim.hire(EmployeeManager.WAREHOUSE)
		return
