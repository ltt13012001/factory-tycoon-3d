## Measures frame cost in a mid-game factory: for each graphics level and a
## few camera views, the average frame time, script time, draw calls,
## primitives and objects drawn, plus the script time of each part of the
## world (by pausing it for a moment). Prints one line per sample and
## writes them as JSON.
##   godot --path . --rendering-method mobile -- --perf=/tmp/perf.json
##       [--quality=medium] [--mobile] [--perf-frames=90] [--perf-quick]
##       [--perf-ablate] [--perf-shots=/tmp/shots]
## --mobile builds the world and picks the settings of a phone or tablet
## (Palette.low_end), --perf-ablate measures each costly feature switched
## off, --perf-quick skips the per-node script times, --perf-shots saves a
## picture of every sample.
extends Node

var _out := ""
var _results := []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--perf="):
			_out = a.trim_prefix("--perf=")
	Graphics.auto = false
	GameManager.new_game()
	var sim := GameManager.sim
	var bot := AutoPlayer.new(sim)
	var target := sim.config.ticks_per_day * 6 + sim.config.ticks_per_hour * 10
	for t in target:
		if t % 15 == 0:
			bot.act()
		sim.step()
	for o in sim.orders.with_status(OrderManager.OFFERED):
		sim.accept_order(o.id)
	sim.buy_material(100)
	TimeManager.set_speed(1)
	_run.call_deferred()


func _run() -> void:
	var hud: Node = get_tree().root.find_child("Hud", true, false)
	await get_tree().create_timer(2.0).timeout
	var report := hud.find_child("DailyReport", true, false)
	if report:
		report.visible = false
	var title := hud.find_child("TitleScreen", true, false)
	if title:
		title.visible = false
	var graphics: Node = get_parent().get_node("Graphics")
	var rig: Node3D = get_viewport().get_camera_3d().get_parent().get_parent()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var tiers := [Graphics.LOW, Graphics.MEDIUM, Graphics.HIGH]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="):
			tiers = [["low", "medium", "high"].find(a.trim_prefix("--quality="))]
	for q in tiers:
		graphics.set_tier(q, false)
		Engine.max_fps = 0
		for view in [["default", 42.0], ["wide", 75.0], ["close", 22.0]]:
			rig._size_target = view[1]
			await get_tree().create_timer(1.5).timeout
			await _sample("%s/%s" % [Graphics.NAMES[q], view[0]], graphics)
	if "--perf-ablate" in OS.get_cmdline_user_args():
		await _ablate(graphics, rig)
	if "--perf-quick" in OS.get_cmdline_user_args():
		_finish()
		return
	# Script time per part of the world, at the default view.
	rig._size_target = 42.0
	await get_tree().create_timer(1.0).timeout
	var base := await _process_ms(60)
	_log({"name": "process_total", "ms": base})
	var main := get_parent()
	var parts := {}
	for n in main.get_children():
		if n == self:
			continue
		parts[n.name] = n
	for key in parts:
		var n: Node = parts[key]
		var before := n.process_mode
		n.process_mode = Node.PROCESS_MODE_DISABLED
		var ms := await _process_ms(60)
		n.process_mode = before
		_log({"name": "process_without/%s" % key, "ms": ms, "saves": base - ms})
	_finish()


func _finish() -> void:
	if _out != "":
		var f := FileAccess.open(_out, FileAccess.WRITE)
		f.store_string(JSON.stringify(_results, "  "))
	get_tree().quit()


## GPU cost of each expensive feature at the current level: switch one
## off, measure, switch it back.
func _ablate(graphics: Node, rig: Node3D) -> void:
	rig._size_target = 42.0
	var vp := get_viewport()
	var env: Environment = graphics.environment
	var sun: DirectionalLight3D = graphics.sun
	var ground: ShaderMaterial = Palette.surface("ground")
	var foliage: ShaderMaterial = Palette.surface("foliage")
	var cases := {
		"none": [func(): pass, func(): pass],
		"no_shadows": [func(): sun.shadow_enabled = false, func(): sun.shadow_enabled = true],
		"shadow_ortho": [func(): sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL, func(): sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS],
		"no_msaa": [func(): vp.msaa_3d = Viewport.MSAA_DISABLED, func(): vp.msaa_3d = Viewport.MSAA_4X],
		"msaa_2x": [func(): vp.msaa_3d = Viewport.MSAA_2X, func(): vp.msaa_3d = Viewport.MSAA_4X],
		"no_glow": [func(): env.glow_enabled = false, func(): env.glow_enabled = true],
		"no_fog": [func(): env.fog_enabled = false, func(): env.fog_enabled = true],
		"ground_q0": [func(): ground.set_shader_parameter("quality", 0.0), func(): ground.set_shader_parameter("quality", float(Graphics.tier))],
		"foliage_q0": [func(): foliage.set_shader_parameter("quality", 0.0), func(): foliage.set_shader_parameter("quality", float(Graphics.tier))],
		"scale_075": [func(): vp.scaling_3d_scale = 0.75, func(): vp.scaling_3d_scale = 1.0],
	}
	for key in cases:
		cases[key][0].call()
		await get_tree().create_timer(1.0).timeout
		await _sample("ablate/%s/%s" % [Graphics.NAMES[Graphics.tier], key], graphics)
		cases[key][1].call()


func _process_ms(frames: int) -> float:
	var total := 0.0
	for i in frames:
		await get_tree().process_frame
		total += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	return total / frames


func _sample(label: String, graphics: Node) -> void:
	var frames := 90
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--perf-frames="):
			frames = int(a.trim_prefix("--perf-frames="))
	var t0 := Time.get_ticks_usec()
	var proc := 0.0
	var gpu := 0.0
	var cpu_render := 0.0
	var draws := 0.0
	var prims := 0.0
	var objs := 0.0
	for i in frames:
		Engine.max_fps = 0
		await get_tree().process_frame
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var vp := get_viewport().get_viewport_rid()
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu_render += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var frame_ms := (Time.get_ticks_usec() - t0) / 1000.0 / frames
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--perf-shots="):
			var dir := a.trim_prefix("--perf-shots=")
			DirAccess.make_dir_recursive_absolute(dir)
			get_viewport().get_texture().get_image().save_jpg("%s/%s.jpg" % [dir, label.replace("/", "_")], 0.9)
	_log({
		"name": label,
		"frame_ms": frame_ms,
		"process_ms": proc / frames,
		"render_cpu_ms": cpu_render / frames,
		"gpu_ms": gpu / frames,
		"draw_calls": draws / frames,
		"primitives": prims / frames,
		"objects": objs / frames,
	})


func _log(d: Dictionary) -> void:
	_results.append(d)
	var parts := []
	for k in d:
		var v = d[k]
		parts.append("%s=%s" % [k, ("%.2f" % v) if v is float else str(v)])
	print("PERF ", " ".join(parts))
