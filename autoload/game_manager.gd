## Owns the Simulation, starts a new game or loads the save, and forwards
## simulation events to the EventBus. UI and 3D send player commands here.
extends Node

var sim: Simulation
## Machine type chosen in the build panel; placed on the next slot click.
var pending_machine_id := "basic_injection_molder"
## Factory the build panel places machines in ("" = the first factory).
var build_site := ""


func _ready() -> void:
	sim = Simulation.new()
	sim.event.connect(EventBus.forward)
	if not SaveManager.load_game():
		sim.new_game(randi())


func _exit_tree() -> void:
	if sim:
		sim.dispose()
		sim = null


func new_game() -> void:
	SaveManager.delete_save()
	sim.new_game(randi())
	TimeManager.set_speed(1)


## Runs a command, shows its message as a toast and returns the result.
func command(result: Dictionary) -> Dictionary:
	if result.message != "":
		EventBus.toast.emit(result.message, result.ok)
	return result


func accept_order(id: int) -> Dictionary: return command(sim.accept_order(id))
func reject_order(id: int) -> Dictionary: return command(sim.reject_order(id))
func ship_order(id: int) -> Dictionary: return command(sim.ship_order(id))
func buy_material(qty: int) -> Dictionary: return command(sim.buy_material(qty))
## Build-mode pad ids: the slot in the first factory, or plot order * 100 + slot.
static func slot_pick_id(slot: int, site: String) -> int:
	return slot if site == "" else int(site.trim_prefix("lot_")) * 100 + slot


func buy_machine(pick_id: int) -> Dictionary:
	var site := "" if pick_id < 100 else "lot_%d" % (pick_id / 100)
	return command(sim.buy_machine(pick_id % 100, pending_machine_id, site))
func hire_at(role: String, site: String) -> Dictionary: return command(sim.hire(role, site))
func upgrade_machine(id: int) -> Dictionary: return command(sim.upgrade_machine(id))
func repair_machine(id: int) -> Dictionary: return command(sim.repair_machine(id))
func build(id: String) -> Dictionary: return command(sim.build(id))
func set_auto_buy(on: bool) -> Dictionary: return command(sim.set_auto_buy(on))
func set_auto_ship(on: bool) -> Dictionary: return command(sim.set_auto_ship(on))
func set_auto_accept(on: bool) -> Dictionary: return command(sim.set_auto_accept(on))
func set_auto_buy_amounts(lot: int, threshold: int) -> Dictionary: return command(sim.set_auto_buy_amounts(lot, threshold))
func set_shift(hours: int) -> Dictionary: return command(sim.set_shift(hours))
func set_pay(percent: int) -> Dictionary: return command(sim.set_pay(percent))


func start_placing(def_id: String) -> void:
	pending_machine_id = def_id
	EventBus.build_mode_changed.emit(true)
	# Show the factory the machine goes in.
	if build_site == "":
		EventBus.camera_focus_requested.emit(Vector3(-6, 0, -3), 30.0)
	else:
		EventBus.camera_focus_requested.emit(FactoryLayout.plot(build_site) + Vector3(0, 0, -1.5), 30.0)
func sell_machine(id: int) -> Dictionary: return command(sim.sell_machine(id))
func hire(role: String) -> Dictionary: return command(sim.hire(role))
func fire(id: int) -> Dictionary: return command(sim.fire(id))
func upgrade_line_speed() -> Dictionary: return command(sim.upgrade_line_speed())
func advance_tier() -> Dictionary: return command(sim.advance_tier())
func expand(location_id: String) -> Dictionary: return command(sim.expand(location_id))
func buy_line(location_id: String) -> Dictionary: return command(sim.buy_line(location_id))
func automate_site(location_id: String) -> Dictionary: return command(sim.automate_site(location_id))
func hire_site_head(location_id: String) -> Dictionary: return command(sim.hire_site_head(location_id))
func fire_site_head(location_id: String) -> Dictionary: return command(sim.fire_site_head(location_id))
func hire_executive(id: String) -> Dictionary: return command(sim.hire_executive(id))
func fire_executive(id: String) -> Dictionary: return command(sim.fire_executive(id))
