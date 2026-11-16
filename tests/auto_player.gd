## A scripted player for the full-loop test. Decides only from the current
## state, so a run that saves and reloads makes the same choices.
class_name AutoPlayer
extends RefCounted

var sim: Simulation


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func act() -> void:
	var s := sim.state
	for o in sim.orders.with_status(OrderManager.ACCEPTED):
		if sim.orders.is_ready(o.id):
			sim.ship_order(o.id)
	for o in sim.orders.with_status(OrderManager.OFFERED):
		var h := sim.orders.hours_needed(o.id)
		if h >= 0 and h <= int(o.deadline_days) * 24 - 4:
			sim.accept_order(o.id)
	var stock := sim.inventory.material_on_hand() + sim.inventory.pending_material()
	if stock < 120 * maxi(1, s.machines.size()):
		var lot := 250 if sim.inventory.raw_free_space() >= 250 else 100
		if sim.economy.can_afford(sim.inventory.lot_cost(lot)) and s.cash > sim.inventory.lot_cost(lot):
			sim.buy_material(lot)
	for m in s.machines:
		if (m.broken or int(m.condition) < 25) and int(m.repairer_id) == 0 \
				and sim.economy.can_afford(sim.production.repair_cost(m)) and s.cash > sim.production.repair_cost(m):
			sim.repair_machine(m.id)
	# Grows once the tutorial reaches its last step, like a new player would.
	if s.machines.size() < 2 and s.tutorial_step >= Tutorial.STEPS.size() - 1 and s.cash >= 120000 + 10000 + 25000:
		var r := sim.buy_machine(1)
		if r.ok:
			sim.hire(EmployeeManager.OPERATOR)
