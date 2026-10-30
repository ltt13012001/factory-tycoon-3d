## Drives the live game for the scene check: opens every panel, selects
## objects, toggles build mode and lets the AutoPlayer run the economy at x4.
##   godot --headless --path . --fixed-fps 60 --quit-after 1800 -- --smoke-test
extends Node

var _bot: AutoPlayer
var _t := 0.0
var _step := 0


func _ready() -> void:
	GameManager.new_game()
	TimeManager.set_speed(4)
	_bot = AutoPlayer.new(GameManager.sim)
	print("smoke test: started")


func _process(delta: float) -> void:
	_t += delta
	_bot.act()
	if _t < 1.0:
		return
	_t = 0.0
	_step += 1
	var hud: Node = get_tree().root.find_child("Hud", true, false)
	match _step % 8:
		0:
			EventBus.selection_changed.emit("machine", GameManager.sim.state.machines[0].id)
		1:
			EventBus.selection_changed.emit("worker", GameManager.sim.state.employees[-1].id)
		2:
			EventBus.build_mode_changed.emit(true)
		3:
			EventBus.build_mode_changed.emit(false)
		4:
			EventBus.inspect_requested.emit(GameManager.sim.state.machines[0].id)
		5:
			EventBus.report_requested.emit(GameManager.sim.state.reports[-1] if not GameManager.sim.state.reports.is_empty() else {"day": 0, "stats": GameManager.sim.state.day_stats, "profit": 0, "start_cash": 0, "end_cash": 0, "income": 0, "expense": 0, "reputation": 50, "critical": false})
	if hud:
		var ids := ["overview", "orders", "purchase", "build", "staff"]
		hud.toggle_panel(ids[_step % ids.size()])
	if _step % 10 == 0:
		var s := GameManager.sim.state
		var chatter := get_tree().root.find_child("Chatter", true, false)
		print("smoke test: day %d %s cash %s machines %d employees %d chats %d" % [GameManager.sim.day(), Fmt.clock(s.tick, GameManager.sim.config), Fmt.money(s.cash), s.machines.size(), s.employees.size(), chatter.started if chatter else -1])
