## Converts real time into fixed simulation ticks, with pause and x1/x2/x4.
extends Node

const SPEEDS := [0, 1, 2, 4]

var speed: int = 1
var _last_day := 0


func set_speed(value: int) -> void:
	speed = clampi(value, 0, 4)
	EventBus.speed_changed.emit(speed)


func toggle_pause() -> void:
	set_speed(0 if speed > 0 else 1)


func _process(delta: float) -> void:
	var sim: Simulation = GameManager.sim
	if sim == null or speed == 0:
		return
	# Clamp so a long hitch never runs thousands of ticks in one frame.
	sim.advance(minf(delta, 0.25) * speed * night_factor())


## The hours after the shift pass faster while nobody is at work.
const NIGHT_SPEEDUP := 3


func night_factor() -> int:
	var sim: Simulation = GameManager.sim
	if sim == null or sim.employees.on_shift() or sim.employees.on_strike():
		return 1
	for e in sim.state.employees:
		if not e.get("off", false):
			return 1
	return NIGHT_SPEEDUP


func clock_text() -> String:
	var sim: Simulation = GameManager.sim
	if sim == null:
		return ""
	var text := "Ngày %d · %s" % [sim.day(), Fmt.clock(sim.state.tick, sim.config)]
	if sim.employees.on_strike():
		text += " · Đình công"
	elif not sim.employees.on_shift():
		text += " · Hết ca" + (" (tua ×%d)" % NIGHT_SPEEDUP if speed > 0 and night_factor() > 1 else "")
	return text
