## Minimal base for the headless test runner: methods named test_* run in
## order, and each failed check is recorded with a message.
class_name TestCase
extends RefCounted

var failures: Array[String] = []
var checks := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func check_eq(actual, expected, message: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])


var _sims: Array[Simulation] = []


func new_sim(seed: int = 42) -> Simulation:
	var sim := blank_sim()
	sim.new_game(seed)
	return sim


func blank_sim() -> Simulation:
	var sim := Simulation.new()
	_sims.append(sim)
	return sim


func cleanup() -> void:
	for sim in _sims:
		sim.dispose()
	_sims.clear()


func hours(sim: Simulation, h: float) -> int:
	return int(h * sim.config.ticks_per_hour)


func days(sim: Simulation, d: float) -> int:
	return int(d * sim.config.ticks_per_day)
