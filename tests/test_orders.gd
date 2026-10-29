extends TestCase


func _first_offer(sim: Simulation) -> Dictionary:
	return sim.orders.with_status(OrderManager.OFFERED)[0]


func test_accept_ship_and_pay() -> void:
	var sim := new_sim()
	var o := _first_offer(sim)
	check(o.qty >= 60 and o.qty <= 180, "quantity 60-180")
	check(o.deadline_days >= 1 and o.deadline_days <= 3, "deadline 1-3 days")
	check(sim.accept_order(o.id).ok, "accept")
	check_eq(o.deadline_tick, sim.state.tick + o.deadline_days * 1440, "deadline from acceptance")
	check(not sim.ship_order(o.id).ok, "cannot ship without stock")
	sim.state.finished = {"plastic_box": o.qty}
	check(sim.orders.is_ready(o.id), "ready when stock covers it")
	var cash := sim.state.cash
	check(sim.ship_order(o.id).ok, "ship")
	check_eq(sim.state.finished_total(), 0, "boxes loaded on truck")
	check_eq(sim.state.cash, cash, "no money before truck leaves")
	sim.advance_ticks(sim.config.customer_truck_ticks)
	check_eq(sim.state.cash, cash + o.qty * o.unit_price, "paid on delivery")
	check_eq(sim.state.reputation, 52, "on time +2")
	check_eq(o.status, OrderManager.DELIVERED, "delivered")


func test_late_penalty() -> void:
	var sim := new_sim()
	var o := _first_offer(sim)
	sim.accept_order(o.id)
	sim.fire(sim.state.employees[0].id)
	# 1.5 days late -> 2 started days -> 20%
	sim.advance_ticks(o.deadline_days * 1440 + days(sim, 1.5) - sim.config.customer_truck_ticks)
	sim.state.finished = {"plastic_box": o.qty}
	var cash := sim.state.cash
	sim.ship_order(o.id)
	sim.advance_ticks(sim.config.customer_truck_ticks)
	var value: int = o.qty * o.unit_price
	check_eq(o.penalty, value * 20 / 100, "10% per started late day")
	check_eq(sim.state.cash, cash + value - value * 20 / 100, "penalty deducted")
	check_eq(sim.state.reputation, 45, "late -5")
	check(sim.economy.ledger_balanced(), "ledger balanced")


func test_penalty_cap() -> void:
	var sim := new_sim()
	var o := _first_offer(sim)
	sim.accept_order(o.id)
	sim.fire(sim.state.employees[0].id)
	sim.advance_ticks(days(sim, 12))
	sim.state.finished = {"plastic_box": o.qty}
	sim.ship_order(o.id)
	sim.advance_ticks(sim.config.customer_truck_ticks)
	check_eq(o.penalty, o.qty * o.unit_price * 50 / 100, "penalty capped at 50%")


func test_offer_expires() -> void:
	var sim := new_sim()
	var o := _first_offer(sim)
	sim.advance_ticks(1439)
	check(not sim.state.find_by_id(sim.state.orders, o.id).is_empty(), "still open before 1 day")
	sim.advance_ticks(1)
	check(sim.state.find_by_id(sim.state.orders, o.id).is_empty(), "expired after 1 day")


func test_reservation_earliest_deadline_first() -> void:
	var sim := new_sim()
	var a := _first_offer(sim)
	var b := sim.orders.generate_offer()
	b.deadline_days = a.deadline_days + 1
	sim.accept_order(b.id)
	sim.accept_order(a.id)
	sim.state.finished = {"plastic_box": a.qty}
	check(sim.orders.is_ready(a.id), "earliest deadline gets the stock")
	check(not sim.orders.is_ready(b.id), "later order waits")
	check_eq(sim.orders.free_stock("plastic_box"), 0, "no free stock")


func test_demand_rate_and_prices() -> void:
	var sim := new_sim(7)
	sim.fire(sim.state.employees[0].id)
	var offers := [1]
	var prices := []
	sim.event.connect(func(name, data):
		if name == &"order_offered":
			offers[0] += 1
			prices.append(data.unit_price)
			sim.reject_order(data.id))
	sim.advance_ticks(days(sim, 10))
	# reputation 50 -> 4.5 orders per game day
	check_eq(offers[0], 46, "1 initial + 4.5 per day for 10 days")
	for p in prices:
		check(p >= roundi(700 * 0.9 * 0.99) and p <= roundi(700 * 1.1 * 1.01), "price in range (%d)" % p)


func test_capacity_estimate() -> void:
	var sim := new_sim()
	var o := _first_offer(sim)
	var h := sim.orders.hours_needed(o.id)
	# 4.75 good boxes per game hour with one machine
	check_eq(h, ceili(o.qty / 4.75), "hours with current capacity")
	sim.fire(sim.state.employees[0].id)
	check_eq(sim.orders.hours_needed(o.id), -1, "no running machine")
