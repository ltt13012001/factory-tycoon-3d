## Owns the Simulation, starts a new game or loads the save, and forwards
## simulation events to the EventBus. UI and 3D send player commands here.
extends Node

var sim: Simulation
## Machine type chosen in the build panel; placed on the next slot click.
var pending_machine_id := "basic_injection_molder"


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
func buy_machine(slot: int) -> Dictionary: return command(sim.buy_machine(slot, pending_machine_id))
func upgrade_machine(id: int) -> Dictionary: return command(sim.upgrade_machine(id))
func repair_machine(id: int) -> Dictionary: return command(sim.repair_machine(id))
func build(id: String) -> Dictionary: return command(sim.build(id))
func set_auto_buy(on: bool) -> Dictionary: return command(sim.set_auto_buy(on))
func set_auto_ship(on: bool) -> Dictionary: return command(sim.set_auto_ship(on))


func start_placing(def_id: String) -> void:
	pending_machine_id = def_id
	EventBus.build_mode_changed.emit(true)
func sell_machine(id: int) -> Dictionary: return command(sim.sell_machine(id))
func hire(role: String) -> Dictionary: return command(sim.hire(role))
func fire(id: int) -> Dictionary: return command(sim.fire(id))
