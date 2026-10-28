## Main scene: lighting, camera, the factory world and the interface.
## Run with `-- --smoke-test` to let a scripted player drive the live game.
extends Node3D


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("6aa7e8")
	sky_mat.sky_horizon_color = Color("cfe3f5")
	sky_mat.ground_horizon_color = Color("cfe3f5")
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.68, 0.78)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.95
	# No SSAO on the Mobile renderer, and too slow for tablets in a browser.
	e.ssao_enabled = RenderingServer.get_current_rendering_method() != "mobile" and not OS.has_feature("web")
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	if OS.has_feature("web"):
		# Browsers on tablets: one shadow split instead of four, and the 3D
		# scene drawn at 75% resolution (the interface stays sharp).
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 90.0
		get_viewport().scaling_3d_scale = 0.75
	add_child(sun)

	add_child(preload("res://scripts/view/camera_rig.gd").new())
	add_child(preload("res://scripts/view/factory_view.gd").new())
	var scenery: Node3D = preload("res://scripts/view/scenery.gd").new()
	add_child(scenery)

	var cycle: Node = preload("res://scripts/view/day_night.gd").new()
	cycle.name = "DayNight"
	cycle.sun = sun
	cycle.environment = e
	cycle.sky_material = sky_mat
	cycle.scenery = scenery
	add_child(cycle)

	var ui := CanvasLayer.new()
	var hud: Control = preload("res://scripts/ui/hud.gd").new()
	hud.name = "Hud"
	ui.add_child(hud)
	add_child(ui)

	var args := OS.get_cmdline_user_args()
	if "--smoke-test" in args:
		add_child(load("res://tests/smoke_test.gd").new())
	for a in args:
		if a.begins_with("--screenshot="):
			add_child(load("res://tests/screenshot_tool.gd").new())
