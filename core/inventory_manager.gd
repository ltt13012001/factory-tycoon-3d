## Raw material and finished goods stores, purchasing and deliveries.
class_name InventoryManager
extends RefCounted

var sim: Simulation


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func carried(kind: String) -> int:
	var total := 0
	for e in sim.state.employees:
		if not e.job.is_empty() and e.job.kind == kind:
			total += int(e.job.qty)
	return total


func pending_material() -> int:
	var total := 0
	for p in sim.state.purchases:
		total += int(p.qty)
	return total


## Every material unit the company owns (store, dock, being carried).
func material_on_hand() -> int:
	return sim.state.raw + sim.state.dock + carried("unload")


func raw_free_space() -> int:
	return sim.buildings.raw_capacity() - material_on_hand() - pending_material()


func finished_free_space() -> int:
	return sim.buildings.finished_capacity() - sim.state.finished_total()


func lot_cost(qty: int) -> int:
	return qty * sim.content.material().unit_price + sim.config.shipping_per_lot


## Auto-buy amounts, chosen with sliders in the purchase panel.
const AUTO_LOT_MIN := 50
const AUTO_LOT_MAX := 1000
const AUTO_STEP := 50


func auto_buy_lot() -> int:
	return int(sim.state.settings.get("auto_buy_lot", sim.config.auto_buy_lot))


func auto_buy_threshold() -> int:
	return int(sim.state.settings.get("auto_buy_threshold", sim.config.auto_buy_threshold))


func set_auto_buy_amounts(lot: int, threshold: int) -> Dictionary:
	sim.state.settings.auto_buy_lot = clampi(snappedi(lot, AUTO_STEP), AUTO_LOT_MIN, AUTO_LOT_MAX)
	sim.state.settings.auto_buy_threshold = clampi(snappedi(threshold, AUTO_STEP), 0, sim.buildings.raw_capacity())
	return Simulation.ok("")


func buy_material(qty: int) -> Dictionary:
	if not sim.config.lot_sizes.has(qty):
		return Simulation.fail("Lô hàng không hợp lệ.")
	return _order_material(qty)


func _order_material(qty: int) -> Dictionary:
	var cfg := sim.config
	if qty > raw_free_space():
		return Simulation.fail("Kho nguyên liệu không đủ chỗ (còn %d)." % maxi(0, raw_free_space()))
	var cost := lot_cost(qty)
	if not sim.economy.can_afford(cost):
		return Simulation.fail("Không đủ tiền. Cần %s." % Fmt.money(cost))
	sim.economy.book("material", -cost, "Mua %d %s" % [qty, sim.content.material().display_name])
	var p := {
		"id": sim.state.take_id(),
		"qty": qty,
		"cost": cost,
		"arrive_tick": sim.state.tick + cfg.delivery_hours * cfg.ticks_per_hour,
	}
	sim.state.purchases.append(p)
	sim.emit_event(&"material_ordered", p.duplicate())
	return Simulation.ok("Đã đặt %d %s, giao sau %d giờ." % [qty, sim.content.material().display_name, cfg.delivery_hours])


func set_auto_buy(enabled: bool) -> Dictionary:
	sim.state.settings.auto_buy = enabled
	return Simulation.ok("Đã bật tự động mua hạt nhựa." if enabled else "Đã tắt tự động mua hạt nhựa.")


func tick() -> void:
	var s := sim.state
	var arrived := []
	for p in s.purchases:
		if s.tick >= p.arrive_tick:
			arrived.append(p)
	for p in arrived:
		s.purchases.erase(p)
		s.dock += int(p.qty)
		s.raw_value += int(p.cost)
		sim.emit_event(&"material_arrived", p.duplicate())
	# Auto-buy checks once per game hour so it never floods orders.
	if s.settings.get("auto_buy", false) and s.tick % sim.config.ticks_per_hour == 0:
		# Buys the chosen amount, or what still fits in the store.
		var lot := mini(auto_buy_lot(), raw_free_space())
		var cost := lot_cost(lot)
		if material_on_hand() + pending_material() < auto_buy_threshold() \
				and lot >= AUTO_LOT_MIN and s.cash - cost >= 0:
			_order_material(lot)


## Removes units from the raw store and returns their book value, so the
## total value reaches exactly zero when the last unit is used.
func consume_raw(units: int) -> int:
	var s := sim.state
	var total_units := material_on_hand()
	var cost := 0
	if total_units > 0:
		cost = s.raw_value - (s.raw_value * (total_units - units)) / total_units
	s.raw -= units
	s.raw_value -= cost
	return cost
