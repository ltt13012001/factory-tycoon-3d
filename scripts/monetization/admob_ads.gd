## Rewarded ads from Google AdMob through the "Godot AdMob" plugin by Poing
## Studios (addons/admob, Android and iOS). The plugin's classes are looked
## up by name when the game runs, so this file also loads in builds without
## the plugin (desktop, web, tests); see docs/monetization.md to install it.
class_name AdMobAds
extends AdsBackend

const RETRY_SECONDS := 30.0

var _ad = null
var _loading := false
var _retry := 0.0


## True when the plugin's GDScript classes are in the project.
static func plugin_present() -> bool:
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return false
	for name in ["MobileAds", "RewardedAdLoader", "AdRequest", "RewardedAdLoadCallback", "OnUserEarnedRewardListener", "FullScreenContentCallback"]:
		if _path(name) == "":
			return false
	return true


static func _path(cls: String) -> String:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == cls:
			return c["path"]
	return ""


static func _new(cls: String) -> Object:
	return load(_path(cls)).new()


func _ready() -> void:
	load(_path("MobileAds")).initialize()
	_load_ad()


func available() -> bool:
	return true


func is_ready() -> bool:
	return _ad != null


func _process(delta: float) -> void:
	if _ad == null and not _loading:
		_retry -= delta
		if _retry <= 0.0:
			_load_ad()


func _unit_id() -> String:
	return MonetizationConfig.ADMOB_REWARDED_IOS if OS.has_feature("ios") else MonetizationConfig.ADMOB_REWARDED_ANDROID


func _load_ad() -> void:
	_loading = true
	var callback := _new("RewardedAdLoadCallback")
	callback.on_ad_failed_to_load = func(_error):
		_loading = false
		_retry = RETRY_SECONDS
	callback.on_ad_loaded = func(ad):
		_loading = false
		_ad = ad
	var request := _new("AdRequest")
	if MonetizationConfig.NON_PERSONALIZED_ADS and "extras" in request:
		request.extras["npa"] = "1"
	_new("RewardedAdLoader").load(_unit_id(), request, callback)


func show_rewarded(done: Callable) -> void:
	if _ad == null:
		done.call(false)
		return
	var ad = _ad
	_ad = null
	var earned := [false]
	var finished := [false]
	var finish := func(ok: bool):
		if finished[0]:
			return
		finished[0] = true
		ad.destroy()
		_retry = 0.0
		done.call_deferred(ok)
	var listener := _new("OnUserEarnedRewardListener")
	listener.on_user_earned_reward = func(_item): earned[0] = true
	var screen := _new("FullScreenContentCallback")
	screen.on_ad_dismissed_full_screen_content = func(): finish.call(earned[0])
	screen.on_ad_failed_to_show_full_screen_content = func(_error): finish.call(false)
	ad.full_screen_content_callback = screen
	ad.show(listener)
