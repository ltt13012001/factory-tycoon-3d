## The simulation core. Pure logic: no nodes, no scene, fixed ticks.
## The same advance() serves live play, headless tests and (later) offline
## progress. Every state change is announced through the `event` signal.
class_name Simulation
extends RefCounted

signal event(name: StringName, data: Dictionary)

var content: ContentDB
var config: EconomyConfig
var state := GameState.new()
var rng := RandomNumberGenerator.new()

var economy: EconomyManager
var inventory: InventoryManager
var production: ProductionManager
var orders: OrderManager
var employees: EmployeeManager
var tutorial: Tutorial
var buildings: BuildingManager
var expansion: ExpansionManager

var _tick_remainder := 0.0


func _init(p_content: ContentDB = null) -> void:
	content = p_content if p_content else ContentDB.load_default()
	config = content.economy
	economy = EconomyManager.new(self)
	inventory = InventoryManager.new(self)
	production = ProductionManager.new(self)
	orders = OrderManager.new(self)
	employees = EmployeeManager.new(self)
	tutorial = Tutorial.new(self)
	buildings = BuildingManager.new(self)
	expansion = ExpansionManager.new(self)


## Breaks the reference cycles between the simulation, its managers and
## signal handlers so the objects can be freed.
func dispose() -> void:
	for c in event.get_connections():
		event.disconnect(c.callable)
	economy = null
	inventory = null
	production = null
	orders = null
	employees = null
	tutorial = null
	buildings = null
	expansion = null


static func ok(message: String = "") -> Dictionary:
	return {"ok": true, "message": message}


static func fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}


func new_game(world_seed: int = 12345) -> void:
	state = GameState.new()
	state.world_seed = world_seed
	rng.seed = world_seed
	var cfg := config
	state.cash = cfg.start_cash
	state.reputation = cfg.start_reputation
	state.raw = cfg.start_raw_material
	state.raw_value = cfg.start_raw_material * content.material().unit_price
	state.machines.append(production.make_machine(cfg.start_machine_id, 0))
	for i in cfg.start_operators:
		state.employees.append(employees.make_employee(EmployeeManager.OPERATOR))
	for i in cfg.start_warehouse_workers:
		state.employees.append(employees.make_employee(EmployeeManager.WAREHOUSE))
	employees.auto_assign()
	economy.reset_day_stats()
	orders.generate_offer("small_customer")
	_tick_remainder = 0.0
	emit_event(&"game_loaded", {})


func day() -> int:
	return state.tick / config.ticks_per_day + 1


## Clock hour 0..24; day 1 starts at config.day_start_hour.
func hour_of_day() -> float:
	return fmod(float(state.tick % config.ticks_per_day) / config.ticks_per_hour + config.day_start_hour, 24.0)


## How far (0..1) real time has moved into the next tick; the 3D view uses
## it to animate smoothly between ticks.
func tick_fraction() -> float:
	return clampf(_tick_remainder / config.tick_seconds, 0.0, 1.0)


## Runs as many whole ticks as fit in `seconds` (fractions carry over).
func advance(seconds: float) -> int:
	_tick_remainder += seconds
	var n := int(floor(_tick_remainder / config.tick_seconds))
	_tick_remainder -= n * config.tick_seconds
	advance_ticks(n)
	return n


func advance_ticks(n: int) -> void:
	for i in n:
		step()


func step() -> void:
	state.tick += 1
	buildings.tick()
	expansion.tick()
	inventory.tick()
	employees.tick()
	production.tick()
	orders.tick()
	if state.tick % config.ticks_per_day == 0:
		expansion.end_of_day()
		var report := economy.end_of_day(state.tick / config.ticks_per_day)
		emit_event(&"day_ended", report)
		if report.critical:
			emit_event(&"cash_critical", {"cash": state.cash})
		emit_event(&"day_started", {"day": day()})


func emit_event(name: StringName, data: Dictionary) -> void:
	tutorial.on_event(name)
	event.emit(name, data)


# --- Player commands ---------------------------------------------------------

func accept_order(id: int) -> Dictionary:
	return orders.accept(id)


func reject_order(id: int) -> Dictionary:
	return orders.reject(id)


func ship_order(id: int) -> Dictionary:
	return orders.ship(id)


func buy_material(qty: int) -> Dictionary:
	return inventory.buy_material(qty)


func buy_machine(slot: int, def_id: String = "", site := "") -> Dictionary:
	return production.buy_machine(def_id if def_id != "" else config.start_machine_id, slot, site)


func sell_machine(id: int) -> Dictionary:
	return production.sell_machine(id)


func upgrade_machine(id: int) -> Dictionary:
	return production.upgrade(id)


func repair_machine(id: int) -> Dictionary:
	return production.repair(id)


func build(construction_id: String) -> Dictionary:
	return buildings.start(construction_id)


func set_auto_buy(enabled: bool) -> Dictionary:
	return inventory.set_auto_buy(enabled)


func set_auto_ship(enabled: bool) -> Dictionary:
	return orders.set_auto_ship(enabled)


func set_auto_accept(enabled: bool) -> Dictionary:
	return orders.set_auto_accept(enabled)


func set_auto_buy_amounts(lot: int, threshold: int) -> Dictionary:
	return inventory.set_auto_buy_amounts(lot, threshold)


func set_shift(hours: int) -> Dictionary:
	return employees.set_shift(hours)


func set_pay(percent: int) -> Dictionary:
	return employees.set_pay(percent)


func upgrade_line_speed() -> Dictionary:
	return expansion.upgrade_line_speed()


func advance_tier() -> Dictionary:
	return expansion.advance_tier()


func expand(location_id: String) -> Dictionary:
	return expansion.next_step(location_id)


func buy_line(location_id: String) -> Dictionary:
	return expansion.buy_line(location_id)


func automate_site(location_id: String) -> Dictionary:
	return expansion.upgrade_automation(location_id)


func hire_site_head(location_id: String) -> Dictionary:
	return expansion.hire_head(location_id)


func fire_site_head(location_id: String) -> Dictionary:
	return expansion.fire_head(location_id)


func hire_executive(id: String) -> Dictionary:
	return expansion.hire_exec(id)


func fire_executive(id: String) -> Dictionary:
	return expansion.fire_exec(id)


func hire(role: String, site := "") -> Dictionary:
	return employees.hire(role, site)


func fire(id: int) -> Dictionary:
	return employees.fire(id)


# --- Save / load -------------------------------------------------------------

func to_save_dict() -> Dictionary:
	state.rng_state = str(rng.state)
	var d := state.to_dict()
	d["save_version"] = SaveMigrations.CURRENT_VERSION
	return d


func load_save_dict(data: Dictionary) -> bool:
	var migrated := SaveMigrations.migrate(data.duplicate(true))
	if migrated.is_empty():
		return false
	state = GameState.new()
	state.from_dict(migrated)
	rng.seed = state.world_seed
	rng.state = state.rng_state.to_int()
	_tick_remainder = 0.0
	expansion.convert_old_lines()
	employees.auto_assign()
	emit_event(&"game_loaded", {})
	return true


func to_json() -> String:
	return JSON.stringify(to_save_dict(), "", true)


func load_json(text: String) -> bool:
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return false
	return load_save_dict(parsed)
