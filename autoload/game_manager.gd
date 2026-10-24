## Owns the Simulation, starts a new game or loads the save, and forwards
## simulation events to the EventBus. UI and 3D send player commands here.
extends Node

var sim: Simulation


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
func buy_machine(slot: int) -> Dictionary: return command(sim.buy_machine(slot))
func sell_machine(id: int) -> Dictionary: return command(sim.sell_machine(id))
func hire(role: String) -> Dictionary: return command(sim.hire(role))
func fire(id: int) -> Dictionary: return command(sim.fire(id))
