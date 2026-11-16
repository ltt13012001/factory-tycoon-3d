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
	sky_mat.ground_bottom_color = Color("5a6b4a")
	sky_mat.sky_curve = 0.12
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	# The sky only feeds reflections on metal and glass; a small radiance
	# map is plenty and cheap to refresh as the day/night tints change.
	sky.radiance_size = Sky.RADIANCE_SIZE_64 if Palette.low_end() else Sky.RADIANCE_SIZE_128
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	# Shade lit by the sky itself: blue from above, a green bounce from the
	# ground below, so shadows read as daylight rather than flat grey.
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 0.75
	e.ambient_light_color = Color(0.62, 0.68, 0.78)
	e.ambient_light_energy = 0.55
	# AgX keeps strong sunlight from clipping and rolls bright colours off
	# naturally, like a camera: the photographic look of city builders.
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.08
	e.tonemap_white = 6.0
	e.tonemap_agx_contrast = 1.45
	# Haze that softens the distant hills and town (aerial perspective).
	# The camera is orthographic and 80 m back, so depth fog starts beyond
	# the factory lot and only reaches the far scenery.
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = Color("cfe0f0")
	e.fog_density = 0.55
	e.fog_depth_begin = 105.0
	e.fog_depth_end = 240.0
	e.fog_depth_curve = 1.6
	e.fog_sky_affect = 0.0
	# The haze takes the colour of the sky behind it, and glows warmer
	# towards the sun.
	e.fog_aerial_perspective = 0.25
	e.fog_sun_scatter = 0.12
	# Gentle bloom on lamps, windows and status lights.
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_strength = 0.9
	e.glow_bloom = 0.02
	e.glow_hdr_threshold = 1.1
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 1.08
	# No SSAO on the Mobile renderer, and too slow for tablets in a browser.
	e.ssao_enabled = RenderingServer.get_current_rendering_method() != "mobile" and not OS.has_feature("web")
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.shadow_opacity = 0.9
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)

	# Shadows, 3D resolution and bloom per quality level (see Graphics).
	var graphics := Graphics.new()
	graphics.name = "Graphics"
	graphics.sun = sun
	graphics.environment = e
	add_child(graphics)

	add_child(preload("res://scripts/view/camera_rig.gd").new())
	var factory: Node3D = preload("res://scripts/view/factory_view.gd").new()
	add_child(factory)
	var scenery: Node3D = preload("res://scripts/view/scenery.gd").new()
	add_child(scenery)
	var sites: Node3D = preload("res://scripts/view/sites_view.gd").new()
	add_child(sites)
	var branches: Node3D = preload("res://scripts/view/branch_view.gd").new()
	branches.name = "Branches"
	branches.scenery = scenery
	branches.main_world.assign([factory, scenery, sites])
	add_child(branches)

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
