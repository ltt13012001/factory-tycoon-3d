## Fast-forwards a game with the AutoPlayer, then saves screenshots.
##   godot --path . --rendering-method gl_compatibility -- --screenshot=/tmp/shots
extends Node

var _dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screenshot="):
			_dir = a.trim_prefix("--screenshot=")
	DirAccess.make_dir_recursive_absolute(_dir)
	GameManager.new_game()
	var sim := GameManager.sim
	var bot := AutoPlayer.new(sim)
	var target := sim.config.ticks_per_day * 6 + sim.config.ticks_per_hour * 10
	for t in target:
		if t % 15 == 0:
			bot.act()
		sim.step()
	# Make sure something is visibly happening in the shots.
	for o in sim.orders.with_status(OrderManager.OFFERED):
		sim.accept_order(o.id)
	sim.buy_material(100)
	TimeManager.set_speed(1)
	_run.call_deferred()


func _run() -> void:
	var hud: Node = get_tree().root.find_child("Hud", true, false)
	await get_tree().create_timer(3.0).timeout
	hud.find_child("DailyReport", true, false).visible = false
	await _shot("01_factory")
	hud.toggle_panel("orders")
	await get_tree().create_timer(0.6).timeout
	await _shot("02_orders")
	hud.toggle_panel("build")
	EventBus.build_mode_changed.emit(true)
	await get_tree().create_timer(0.6).timeout
	await _shot("03_build")
	EventBus.build_mode_changed.emit(false)
	hud.toggle_panel("overview")
	EventBus.selection_changed.emit("machine", GameManager.sim.state.machines[0].id)
	await get_tree().create_timer(0.6).timeout
	await _shot("04_overview_selection")
	hud.toggle_panel("overview")
	EventBus.selection_changed.emit("", 0)
	EventBus.report_requested.emit(GameManager.sim.state.reports[-1])
	await get_tree().create_timer(0.6).timeout
	await _shot("05_report")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(name + ".png"))
	print("saved ", name)
