## Day/night cycle driven by the game clock: moves the sun, tints the sky
## and ambient light, and switches on lamps and windows after dusk.
extends Node

var sun: DirectionalLight3D
var environment: Environment
var sky_material: ProceduralSkyMaterial
var scenery: Node3D

const DAY_TOP := Color("6aa7e8")
const DAY_HORIZON := Color("cfe3f5")
const DUSK_HORIZON := Color("f2a65e")
const NIGHT_TOP := Color("0d1b33")
const NIGHT_HORIZON := Color("2a3b5c")

## Changing the sky redraws it, so phones and browsers update the light a few
## times a second instead of every frame; the change per step is invisible.
var _interval := 0.25 if OS.has_feature("mobile") or OS.has_feature("web") else 0.0
var _wait := 0.0


func _process(delta: float) -> void:
	var sim: Simulation = GameManager.sim
	if sim == null:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = _interval
	var frac := sim.tick_fraction() if TimeManager.speed > 0 else 0.0
	var h := fmod(sim.hour_of_day() + frac / sim.config.ticks_per_hour, 24.0)
	apply_hour(h)


## Sunrise at 6:00, sunset at 18:00.
func apply_hour(h: float) -> void:
	var s := sin((h - 6.0) / 12.0 * PI)  # 1 at noon, < 0 at night
	var day := smoothstep(-0.15, 0.3, s)
	var dusk := clampf(1.0 - absf(s) / 0.35, 0.0, 1.0) * smoothstep(-0.3, 0.0, s)
	var night := 1.0 - day

	# Sun sweeps east to west, kept high enough for readable shadows; at
	# night the same light becomes dim blue moonlight from a fixed angle.
	var t := clampf((h - 6.0) / 12.0, 0.0, 1.0)
	var elevation := lerpf(22.0, 62.0, clampf(s, 0.0, 1.0))
	var yaw := lerpf(-100.0, 40.0, t)
	if day < 0.05:
		elevation = 50.0
		yaw = -30.0
	sun.rotation_degrees = Vector3(-elevation, yaw, 0)
	sun.light_energy = lerpf(0.22, 1.0, day)
	sun.light_color = Color("aabbee").lerp(Color("fff4e0"), day).lerp(Color("ffb36b"), dusk * 0.6)

	environment.ambient_light_energy = lerpf(0.42, 0.55, day)
	environment.ambient_light_color = Color(0.42, 0.48, 0.68).lerp(Color(0.62, 0.68, 0.78), day)
	sky_material.sky_top_color = NIGHT_TOP.lerp(DAY_TOP, day)
	var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON, day).lerp(DUSK_HORIZON, dusk * 0.8)
	sky_material.sky_horizon_color = horizon
	sky_material.ground_horizon_color = horizon

	var glow := smoothstep(0.35, 0.8, night)
	if scenery:
		scenery.lamp_material.emission_energy_multiplier = glow * 3.0
		scenery.window_material.emission_energy_multiplier = glow * 1.6
		for l in scenery.night_lights:
			l.visible = glow > 0.02
			l.light_energy = glow * 1.4
