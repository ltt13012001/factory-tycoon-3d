## Graphics quality: Low, Medium or High. "Auto" (the default) picks a level
## from the device: in a browser it reads the graphics chip and memory, so
## software rendering, old phone chips and 2 GB devices start on Low. While
## playing on Auto, a frame rate that stays poor steps the level down.
## The player can fix a level in the Menu. Pass `-- --quality=low` (or
## medium / high) to force one; the web page does this in its safe mode.
class_name Graphics
extends Node

enum { LOW, MEDIUM, HIGH }
const NAMES := ["Thấp", "Vừa", "Cao"]
const SETTINGS_PATH := "user://settings.cfg"

## Current level, read by the day/night cycle for the night lights.
static var tier := HIGH
static var auto := true

var sun: DirectionalLight3D
var environment: Environment

var _ssao := false
var _msaa := Viewport.MSAA_DISABLED
var _screen_aa := Viewport.SCREEN_SPACE_AA_DISABLED
# Frame-rate watch on Auto: frames and seconds in the current window, and
# how many windows in a row were too slow.
var _warmup := 10.0
var _frames := 0
var _seconds := 0.0
var _slow := 0

const SLOW_FPS := 22.0
const WINDOW := 4.0

## Frame rate, to save battery and heat without looking any different.
## Phones and browsers stop at 60 frames a second: a 90 or 120 Hz screen
## would otherwise draw up to twice as many frames of the same motion.
## While the game is paused and nobody touches the screen for a few
## seconds, only the breathing and the clouds move, so 30 frames are
## plenty; the first touch or key brings the full rate back at once. A
## desktop window in the background draws 10 frames a second.
const HANDHELD_FPS := 60
const LOW_FPS := 30
const IDLE_FPS := 30
const BACKGROUND_FPS := 10
const IDLE_AFTER := 8.0

var _untouched := 0.0
var _focused := true


func _ready() -> void:
	var vp := get_viewport()
	_msaa = vp.msaa_3d
	_screen_aa = vp.screen_space_aa
	_ssao = environment.ssao_enabled
	var forced := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="):
			forced = ["low", "medium", "high"].find(a.trim_prefix("--quality="))
	var saved := -1
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		saved = int(cfg.get_value("graphics", "tier", -1))
	if forced >= 0:
		auto = false
		tier = forced
	elif saved >= 0:
		auto = false
		tier = clampi(saved, LOW, HIGH)
	else:
		auto = true
		tier = detect()
	apply()


## Best starting level for this device.
static func detect() -> int:
	if not OS.has_feature("web"):
		return MEDIUM if OS.has_feature("mobile") else HIGH
	var info := str(JavaScriptBridge.eval("""(function () {
		var gpu = '';
		try {
			var g = document.createElement('canvas').getContext('webgl2');
			if (g) {
				var d = g.getExtension('WEBGL_debug_renderer_info');
				gpu = d ? g.getParameter(d.UNMASKED_RENDERER_WEBGL) : g.getParameter(g.RENDERER);
				var x = g.getExtension('WEBGL_lose_context');
				if (x) { x.loseContext(); }
			}
		} catch (e) {}
		var touch = /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent)
			|| (navigator.maxTouchPoints > 1 && /Mac/.test(navigator.platform));
		return [gpu, navigator.deviceMemory || 0, touch ? 1 : 0].join('|');
	}())""", true))
	var parts := info.split("|")
	if parts.size() < 3:
		return MEDIUM
	return tier_for(parts[0], float(parts[1]), parts[2] == "1")


## Level for a browser's graphics chip name, memory in GB (0 = unknown) and
## whether it is a phone or tablet.
static func tier_for(gpu: String, memory_gb: float, handheld: bool) -> int:
	var weak := RegEx.create_from_string(
		"(?i)swiftshader|llvmpipe|softpipe|software|basic render|microsoft basic"
		+ "|mali-[24t]|mali-g(31|51|52|57)\\b|adreno[^0-9]*([2-5][0-9]{2}|6[01][0-9])\\b"
		+ "|powervr|sgx|img br|vivante|videocore|intel.*gma"
		+ "|intel.*\\bhd graphics( [2-5][0-9]{3})?($|[^ 0-9]| [^0-9])")
	if weak.search(gpu) or (memory_gb > 0.0 and memory_gb <= 2.0):
		return LOW
	if handheld:
		return MEDIUM
	var strong := RegEx.create_from_string("(?i)nvidia|geforce|quadro|rtx|radeon (rx|pro)|apple m[0-9]")
	return HIGH if strong.search(gpu) else MEDIUM


func set_tier(value: int, by_player := true) -> void:
	if by_player:
		auto = value < 0
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS_PATH)
		cfg.set_value("graphics", "tier", value)
		cfg.save(SETTINGS_PATH)
		if OS.has_feature("web"):
			# The page's light mode (--quality=low) is over once the player chooses.
			JavaScriptBridge.eval("try { localStorage.removeItem('ft3d-boot'); } catch (e) {}")
	tier = detect() if value < 0 else clampi(value, LOW, HIGH)
	_slow = 0
	_warmup = 6.0
	apply()


## Shadows, 3D resolution, bloom and frame cap for the current level. The
## interface is drawn at full resolution on every level.
func apply() -> void:
	var web := OS.has_feature("web")
	var handheld := web or OS.has_feature("mobile")
	var vp := get_viewport()
	sun.shadow_enabled = tier != LOW
	if tier == HIGH or not web:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = 140.0
	else:
		# Browsers: one shadow map instead of a split one.
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 90.0
	match tier:
		LOW:
			vp.scaling_3d_scale = 0.6 if web else 0.75
		MEDIUM:
			vp.scaling_3d_scale = 0.75 if web else 1.0
		_:
			vp.scaling_3d_scale = 1.0
	vp.msaa_3d = _msaa if tier != LOW else Viewport.MSAA_DISABLED
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		vp.screen_space_aa = _screen_aa if tier != LOW else Viewport.SCREEN_SPACE_AA_DISABLED
	environment.glow_enabled = tier != LOW
	environment.adjustment_enabled = tier != LOW
	environment.ssao_enabled = _ssao and tier == HIGH
	Engine.max_fps = fps_cap()


## Frame limit for the level, the pause and the window focus (0 = the
## screen's own rate).
func fps_cap() -> int:
	var web := OS.has_feature("web")
	var handheld := web or OS.has_feature("mobile")
	if not _focused and not web:
		return BACKGROUND_FPS
	var cap := 0
	if handheld:
		cap = LOW_FPS if tier == LOW else HANDHELD_FPS
	if TimeManager.speed == 0 and _untouched >= IDLE_AFTER:
		cap = IDLE_FPS if cap == 0 else mini(cap, IDLE_FPS)
	return cap


func _input(_event: InputEvent) -> void:
	_untouched = 0.0
	if Engine.max_fps != fps_cap():
		Engine.max_fps = fps_cap()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = what == NOTIFICATION_APPLICATION_FOCUS_IN
		_frames = 0
		_seconds = 0.0
		_warmup = maxf(_warmup, 2.0)
		Engine.max_fps = fps_cap()


## Yard lights at night only where extra lights are affordable: every light
## redraws the lit objects again with the browser's renderer.
static func night_lights_on() -> bool:
	return tier == HIGH or (tier == MEDIUM and not OS.has_feature("web"))


func _process(delta: float) -> void:
	_untouched += delta
	var cap := fps_cap()
	if Engine.max_fps != cap:
		Engine.max_fps = cap
	if not auto or tier == LOW or not _focused:
		return
	if delta > 0.5:
		return  # the tab was hidden or the game paused for loading
	if _warmup > 0.0:
		_warmup -= delta
		return
	_frames += 1
	_seconds += delta
	if _seconds < WINDOW:
		return
	var fps := _frames / _seconds
	_frames = 0
	_seconds = 0.0
	_slow = _slow + 1 if fps < SLOW_FPS else 0
	if _slow >= 2:
		set_tier(tier - 1, false)
		EventBus.toast.emit("Đã giảm đồ họa xuống %s cho mượt hơn (đổi ở Menu)." % NAMES[tier], true)
