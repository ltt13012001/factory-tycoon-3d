## Fast-forwards a game with the AutoPlayer, then saves screenshots.
##   godot --path . --rendering-method gl_compatibility -- --screenshot=/tmp/shots
extends Node

var _dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screenshot="):
			_dir = a.trim_prefix("--screenshot=")
	DirAccess.make_dir_recursive_absolute(_dir)
	# Full quality for the shots, whatever the frame rate of a software GPU.
	Graphics.auto = false
	get_parent().get_node("Graphics").set_tier(Graphics.HIGH, false)
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
	hud.find_child("DailyReport", true, false).visible = false
	_showcase()
	await get_tree().create_timer(2.5).timeout
	await _shot("06_showcase")
	var rig: Node3D = get_viewport().get_camera_3d().get_parent().get_parent()
	rig._size_target = 75.0
	await get_tree().create_timer(1.5).timeout
	await _shot("07_wide")
	rig._size_target = 42.0
	var sim := GameManager.sim
	TimeManager.set_speed(0)
	sim.state.tick = (sim.day() - 1) * sim.config.ticks_per_day + (20 - sim.config.day_start_hour) * sim.config.ticks_per_hour
	await get_tree().create_timer(1.5).timeout
	await _shot("08_night")
	sim.state.tick = (sim.day() - 1) * sim.config.ticks_per_day + (13 - sim.config.day_start_hour) * sim.config.ticks_per_hour
	_expansion()
	TimeManager.set_speed(1)
	rig.rotation_degrees.y = 45.0
	rig._yaw_target = 45.0
	EventBus.camera_focus_requested.emit(Vector3(70, 0, 2), 62.0)
	await get_tree().create_timer(3.0).timeout
	await _shot("09_new_factories")
	hud.toggle_panel("expansion")
	await get_tree().create_timer(0.8).timeout
	await _shot("10_expansion_panel")
	hud.toggle_panel("expansion")
	await _staff_shots(hud, rig)
	get_tree().quit()


## Workers up close: resting with no orders, the staff panel, a strike and
## the auto-buy sliders.
func _staff_shots(hud: Node, rig: Node3D) -> void:
	var sim := GameManager.sim
	rig.rotation_degrees.y = 0.0
	rig._yaw_target = 0.0
	# No orders and a full store: everyone ends up in the rest area.
	for o in sim.state.orders.duplicate():
		if o.status == OrderManager.OFFERED or o.status == OrderManager.ACCEPTED:
			sim.state.orders.erase(o)
	sim.state.finished = {"plastic_box": sim.buildings.finished_capacity()}
	sim.state.buildings.erase("break_room")
	sim.state.tick = (sim.day() - 1) * sim.config.ticks_per_day + 3 * sim.config.ticks_per_hour
	for e in sim.state.employees:
		e.mood = 50 + int(e.id) * 7 % 40
	TimeManager.set_speed(4)
	EventBus.camera_focus_requested.emit(Vector3(-16, 0, 6), 16.0)
	await get_tree().create_timer(9.0).timeout
	TimeManager.set_speed(1)
	await get_tree().create_timer(2.0).timeout
	await _shot("11_rest_area")
	EventBus.camera_focus_requested.emit(Vector3(-21, 0, 8), 6.0)
	await get_tree().create_timer(1.5).timeout
	await _shot("16_chibi_closeup")
	EventBus.camera_focus_requested.emit(Vector3(-9, 0, -6), 14.0)
	sim.state.finished = {}
	await get_tree().create_timer(6.0).timeout
	await _shot("12_workers_closeup")
	hud.toggle_panel("staff")
	await get_tree().create_timer(0.8).timeout
	await _shot("13_staff_panel")
	hud.toggle_panel("staff")
	sim.set_pay(70)
	sim.set_shift(14)
	for e in sim.state.employees:
		e.mood = 20
	sim.state.strike = {"since_tick": sim.state.tick}
	EventBus.camera_focus_requested.emit(Vector3(-8, 0, 2), 16.0)
	await get_tree().create_timer(7.0).timeout
	await _shot("14_strike")
	hud.toggle_panel("purchase")
	await get_tree().create_timer(0.8).timeout
	await _shot("15_purchase_panel")
	hud.toggle_panel("purchase")
	await _street_shots(rig)


## After the shift: staff walk out along the walkway, through the gate and
## along the pavement; then the street across the road from the front.
func _street_shots(rig: Node3D) -> void:
	var sim := GameManager.sim
	sim.state.strike = {}
	sim.set_pay(120)
	sim.set_shift(8)
	for e in sim.state.employees:
		e.mood = 80
	sim.state.tick = (sim.day() - 1) * sim.config.ticks_per_day + (14 - sim.config.day_start_hour) * sim.config.ticks_per_hour + 55
	TimeManager.set_speed(1)
	EventBus.camera_focus_requested.emit(Vector3(-4, 0, 12), 20.0)
	await get_tree().create_timer(5.5).timeout
	await _shot("17_going_home")
	TimeManager.set_speed(0)
	rig.rotation_degrees.y = 200.0
	rig._yaw_target = 200.0
	EventBus.camera_focus_requested.emit(Vector3(14, 0, 24), 26.0)
	await get_tree().create_timer(2.0).timeout
	await _shot("18_street")
	rig.rotation_degrees.y = 20.0
	rig._yaw_target = 20.0
	EventBus.camera_focus_requested.emit(Vector3(4, 0, -30), 40.0)
	await get_tree().create_timer(2.0).timeout
	await _shot("19_paddies")


## A growing company: factory 2 running, factory 3 being built, a branch.
func _expansion() -> void:
	var sim := GameManager.sim
	sim.state.cash += 100000000
	sim.hire(EmployeeManager.MANAGER)
	sim.upgrade_line_speed()
	for slot in sim.buildings.machine_slots():
		if sim.production.machine_in_slot(slot).is_empty():
			sim.buy_machine(slot)
	for id in ["lot_2", "lot_3"]:
		print(id, sim.expand(id), sim.expand(id))
		if id == "lot_2":
			sim.advance_ticks(sim.content.locations[id].build_hours * sim.config.ticks_per_hour)
			sim.hire_site_head(id)
			for i in 9:
				sim.buy_line(id)
			sim.automate_site(id)
			sim.automate_site(id)
	var s3 := sim.expansion.site("lot_3")
	s3.ticks_left = s3.total_ticks * 2 / 5
	print("tier ", sim.advance_tier())
	sim.hire_executive("production_director")
	print("survey ", sim.expand("binh_duong"))


## Late-game look: every building, every machine type, a repair under way
## and a construction site.
func _showcase() -> void:
	var sim := GameManager.sim
	sim.state.cash += 10000000
	sim.state.reputation = 80
	sim.state.tick += sim.config.ticks_per_day * 3
	for id in ["hall_expansion", "sales_office", "solar_roof", "break_room"]:
		sim.state.buildings[id] = 1
	var types := ["blow_molder", "industrial_molder", "shelf_press", "auto_molder", "basic_injection_molder", "blow_molder", "shelf_press"]
	var slot := 0
	for def_id in types:
		while not sim.production.machine_in_slot(slot).is_empty():
			slot += 1
		if slot >= sim.buildings.machine_slots():
			break
		print("buy ", def_id, " ", sim.buy_machine(slot, def_id))
	sim.hire(EmployeeManager.TECHNICIAN)
	for i in 3:
		sim.hire(EmployeeManager.OPERATOR)
	sim.buy_material(250)
	var m: Dictionary = sim.state.machines[1]
	m.broken = true
	m.condition = 10
	print("upgrade ", sim.upgrade_machine(sim.state.machines[0].id))
	print("build ", sim.build("warehouse_expansion"))
	sim.state.construction.ticks_left = sim.state.construction.total_ticks / 2
	TimeManager.set_speed(1)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(name + ".png"))
	print("saved ", name)
