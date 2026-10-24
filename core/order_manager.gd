## Customer orders: offers, acceptance, stock reservation, shipping,
## late penalties and reputation.
class_name OrderManager
extends RefCounted

const OFFERED := "offered"
const ACCEPTED := "accepted"
const SHIPPING := "shipping"
const DELIVERED := "delivered"
const KEEP_HISTORY := 20

var sim: Simulation


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func with_status(status: String) -> Array:
	var out := []
	for o in sim.state.orders:
		if o.status == status:
			out.append(o)
	return out


func generate_offer() -> Dictionary:
	var s := sim.state
	var cfg := sim.config
	var t := sim.content.order_template()
	var qty := sim.rng.randi_range(t.min_quantity, t.max_quantity)
	var days := clampi(roundi(float(qty) / t.quantity_per_day) + 1, t.min_deadline_days, t.max_deadline_days)
	var u := sim.rng.randf()
	var rs := cfg.price_random_spread_percent / 100.0
	var rp := cfg.price_reputation_spread_percent / 100.0
	var price := roundi(sim.content.product().base_price
		* (1.0 - rs / 2.0 + rs * u)
		* (1.0 - rp / 2.0 + rp * s.reputation / 100.0))
	var customer := "Khách hàng"
	if t.customer_names.size() > 0:
		customer = t.customer_names[sim.rng.randi_range(0, t.customer_names.size() - 1)]
	var o := {
		"id": s.take_id(),
		"customer": customer,
		"qty": qty,
		"unit_price": price,
		"deadline_days": days,
		"offered_tick": s.tick,
		"expire_tick": s.tick + t.offer_lifetime_days * cfg.ticks_per_day,
		"accepted_tick": -1,
		"deadline_tick": -1,
		"status": OFFERED,
		"ship_ticks_left": 0,
		"paid_tick": -1,
		"penalty": 0,
	}
	s.orders.append(o)
	sim.emit_event(&"order_offered", o.duplicate())
	return o


func accept(order_id: int) -> Dictionary:
	var o := sim.state.find_by_id(sim.state.orders, order_id)
	if o.is_empty() or o.status != OFFERED:
		return Simulation.fail("Đơn hàng không còn.")
	o.status = ACCEPTED
	o.accepted_tick = sim.state.tick
	o.deadline_tick = sim.state.tick + int(o.deadline_days) * sim.config.ticks_per_day
	sim.emit_event(&"order_accepted", o.duplicate())
	return Simulation.ok("Đã nhận đơn của %s." % o.customer)


func reject(order_id: int) -> Dictionary:
	var o := sim.state.find_by_id(sim.state.orders, order_id)
	if o.is_empty() or o.status != OFFERED:
		return Simulation.fail("Đơn hàng không còn.")
	sim.state.orders.erase(o)
	sim.emit_event(&"order_removed", {"id": order_id})
	return Simulation.ok("Đã từ chối đơn.")


## Finished stock is reserved for accepted orders, earliest deadline first.
## Returns {order_id: units reserved}.
func allocation() -> Dictionary:
	var accepted := with_status(ACCEPTED)
	accepted.sort_custom(func(a, b): return a.deadline_tick < b.deadline_tick or (a.deadline_tick == b.deadline_tick and a.id < b.id))
	var remaining := sim.state.finished
	var out := {}
	for o in accepted:
		var take := mini(remaining, int(o.qty))
		out[o.id] = take
		remaining -= take
	return out


func free_stock() -> int:
	var reserved := 0
	var alloc := allocation()
	for k in alloc:
		reserved += int(alloc[k])
	return sim.state.finished - reserved


func is_ready(order_id: int) -> bool:
	var o := sim.state.find_by_id(sim.state.orders, order_id)
	return not o.is_empty() and o.status == ACCEPTED and int(allocation().get(order_id, 0)) >= int(o.qty)


## Game hours needed to make what this order still lacks, or -1 with no
## working machine.
func hours_needed(order_id: int) -> int:
	var o := sim.state.find_by_id(sim.state.orders, order_id)
	if o.is_empty():
		return 0
	var have := int(allocation().get(order_id, 0)) if o.status == ACCEPTED else maxi(0, free_stock())
	var missing := maxi(0, int(o.qty) - have)
	if o.status == OFFERED:
		# Accepted orders in the queue have to be made first.
		for a in with_status(ACCEPTED):
			missing += int(a.qty) - int(allocation().get(a.id, 0))
	if missing == 0:
		return 0
	var rate := sim.production.hourly_capacity()
	if rate <= 0.0:
		return -1
	return ceili(missing / rate)


func ship(order_id: int) -> Dictionary:
	var o := sim.state.find_by_id(sim.state.orders, order_id)
	if o.is_empty() or o.status != ACCEPTED:
		return Simulation.fail("Đơn hàng không thể giao.")
	if not is_ready(order_id):
		return Simulation.fail("Chưa đủ hàng trong kho.")
	sim.state.finished -= int(o.qty)
	o.status = SHIPPING
	o.ship_ticks_left = sim.config.customer_truck_ticks
	sim.emit_event(&"order_shipping", o.duplicate())
	return Simulation.ok("Xe tải của %s đang đến lấy hàng." % o.customer)


func tick() -> void:
	var s := sim.state
	var cfg := sim.config
	s.order_spawn_acc += cfg.orders_per_day_x100_base + cfg.orders_per_day_x100_per_reputation * s.reputation
	var threshold := cfg.ticks_per_day * 100
	while s.order_spawn_acc >= threshold:
		s.order_spawn_acc -= threshold
		if with_status(OFFERED).size() < cfg.max_open_offers:
			generate_offer()
	for o in s.orders.duplicate():
		if o.status == OFFERED and s.tick >= o.expire_tick:
			s.orders.erase(o)
			sim.emit_event(&"order_expired", {"id": o.id, "customer": o.customer})
		elif o.status == SHIPPING:
			o.ship_ticks_left -= 1
			if o.ship_ticks_left <= 0:
				_complete(o)


func late_days(o: Dictionary, at_tick: int) -> int:
	if at_tick <= int(o.deadline_tick):
		return 0
	return ceili(float(at_tick - int(o.deadline_tick)) / sim.config.ticks_per_day)


func _complete(o: Dictionary) -> void:
	var s := sim.state
	var cfg := sim.config
	var value := int(o.qty) * int(o.unit_price)
	var late := late_days(o, s.tick)
	var pct := mini(cfg.late_penalty_max_percent, late * cfg.late_penalty_percent_per_day)
	var penalty := value * pct / 100
	sim.economy.book("sales", value, "%s: %d hộp" % [o.customer, o.qty])
	sim.economy.add_stat("revenue", value)
	sim.economy.add_stat("orders_delivered", 1)
	s.total_revenue += value
	if penalty > 0:
		sim.economy.book("penalty", -penalty, "Phạt giao trễ %d ngày" % late)
		sim.economy.add_stat("penalties", penalty)
	if late > 0:
		sim.economy.add_stat("orders_late", 1)
		s.reputation = clampi(s.reputation + cfg.reputation_late, 0, cfg.reputation_max)
	else:
		s.reputation = clampi(s.reputation + cfg.reputation_on_time, 0, cfg.reputation_max)
	o.status = DELIVERED
	o.paid_tick = s.tick
	o.penalty = penalty
	var done := with_status(DELIVERED)
	while done.size() > KEEP_HISTORY:
		s.orders.erase(done.pop_front())
	sim.emit_event(&"order_completed", {"id": o.id, "customer": o.customer, "value": value, "penalty": penalty, "late_days": late})
