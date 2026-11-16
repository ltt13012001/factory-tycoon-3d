## Rewarded ads and in-app purchases. Picks the real ad network and store
## on phones that have the plugins (AdMob, Apple In-App Purchase, Google Play
## Billing), stand-ins in development builds, and nothing elsewhere (web,
## desktop release), where the ad and shop buttons are simply hidden.
##
## Ads are opt-in only: the player taps "Xem quảng cáo" for a stated reward.
## There are no ads that interrupt play. Rewards and purchases are credited
## through the simulation (DiamondManager) and saved at once.
extends Node

signal changed

var ads: AdsBackend
var store: StoreBackend
var _cooldown := 0.0
var _speed_before := 1


func _ready() -> void:
	var demo := OS.is_debug_build() or "--demo-monetization" in OS.get_cmdline_user_args()
	if "--no-monetization" in OS.get_cmdline_user_args():
		demo = false
	if AdMobAds.plugin_present():
		ads = AdMobAds.new()
	elif demo:
		ads = DemoAds.new()
	else:
		ads = AdsBackend.new()
	if AppleStore.plugin_present():
		store = AppleStore.new()
	elif GooglePlayStore.plugin_present():
		store = GooglePlayStore.new()
	elif demo:
		store = DemoStore.new()
	else:
		store = StoreBackend.new()
	add_child(ads)
	add_child(store)
	store.products_loaded.connect(func(): changed.emit())
	store.purchase_result.connect(_on_purchase)


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


static func today() -> String:
	return Time.get_date_string_from_system()


# --- Ads ---------------------------------------------------------------------

func ads_available() -> bool:
	return ads.available()


## True when an ad for this reward can be offered now.
func can_watch(kind: String, report: Dictionary = {}) -> bool:
	var sim := GameManager.sim
	return ads.available() and sim != null and sim.diamonds.can_watch(kind, today(), report)


## Why the ad button is greyed out, or "" when it works.
func wait_reason() -> String:
	if _cooldown > 0.0:
		return "Chờ %d giây" % ceili(_cooldown)
	if not ads.is_ready():
		return "Đang tải quảng cáo…"
	return ""


## Shows a rewarded ad and gives the reward once it was watched to the end.
func watch(kind: String, report: Dictionary = {}) -> void:
	if not can_watch(kind, report):
		EventBus.toast.emit("Hôm nay đã hết lượt xem quảng cáo này, mai quay lại nhé.", false)
		return
	if wait_reason() != "":
		EventBus.toast.emit(wait_reason(), false)
		return
	_speed_before = TimeManager.speed
	TimeManager.set_speed(0)  # the factory waits while the ad plays
	ads.show_rewarded(func(rewarded: bool):
		_cooldown = MonetizationConfig.AD_COOLDOWN_SECONDS
		TimeManager.set_speed(maxi(1, _speed_before))
		if rewarded:
			GameManager.command(GameManager.sim.diamonds.ad_reward(kind, today(), report))
			SaveManager.save_game()
		else:
			EventBus.toast.emit("Quảng cáo đóng trước khi xong nên chưa có thưởng.", false)
		changed.emit())


# --- Store ---------------------------------------------------------------------

func store_available() -> bool:
	return store.available()


func price_text(pack_id: String) -> String:
	var t := store.price_of(MonetizationConfig.product_id(pack_id))
	return t if t != "" else str(DiamondManager.pack(pack_id).get("price", ""))


func buy(pack_id: String) -> void:
	if not store.available():
		EventBus.toast.emit("Nạp kim cương chỉ có trên bản iPhone, iPad và Android.", false)
		return
	store.buy(MonetizationConfig.product_id(pack_id))


func _on_purchase(product_id: String, transaction_id: String, ok: bool, message: String, token: String) -> void:
	if not ok:
		if message != "":
			EventBus.toast.emit(message, false)
		return
	var sim := GameManager.sim
	if sim == null:
		return
	var r := sim.diamonds.credit_purchase(MonetizationConfig.pack_id(product_id), transaction_id)
	if not r.ok:
		push_warning("Purchase of unknown product %s" % product_id)
		return
	if SaveManager.save_game():
		store.finish(token)  # only once the diamonds are safely saved
	GameManager.command(r)
	changed.emit()
