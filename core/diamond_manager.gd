## Diamonds, the premium currency. Earned from quests (QuestManager),
## opt-in rewarded ads and in-app purchases; spent on senior managers and a
## few time savers. Everything here is plain game state: the ad and store
## SDKs live in the Monetization autoload, which only calls the reward
## functions below once the platform confirms the ad was watched or the
## purchase went through.
class_name DiamondManager
extends RefCounted

## Diamonds a new game starts with, so a new player can try them out.
const START_DIAMONDS := 30

## Senior managers, recruited with diamonds, permanent, no wage. Each has
## three levels; `per_level` is the bonus each level adds to `field`.
## Fields: speed (% faster machines, every factory), wear (% slower wear),
## material (% cheaper material), price (% higher new order prices),
## mood (staff mood target), storage (% bigger stores), profit (% more
## branch profit).
const SENIORS := {
	"chief_engineer": {"name": "Kỹ sư trưởng", "field": "wear", "per_level": 20, "costs": [80, 200, 450],
		"text": "Máy hao mòn chậm hơn %d%%, ít hỏng vặt."},
	"productivity_expert": {"name": "Chuyên gia năng suất", "field": "speed", "per_level": 8, "costs": [120, 300, 650],
		"text": "Máy ở mọi nhà xưởng chạy nhanh hơn %d%%."},
	"purchasing_head": {"name": "Trưởng phòng thu mua", "field": "material", "per_level": 8, "costs": [80, 200, 450],
		"text": "Hạt nhựa mua vào rẻ hơn %d%%."},
	"negotiator": {"name": "Chuyên gia đàm phán", "field": "price", "per_level": 6, "costs": [120, 300, 650],
		"text": "Đơn hàng mới trả giá cao hơn %d%%."},
	"people_coach": {"name": "Chuyên gia gắn kết nhân viên", "field": "mood", "per_level": 6, "costs": [60, 150, 350],
		"text": "Tâm trạng nhân viên cao hơn %d điểm, khó đình công hơn."},
	"logistics_head": {"name": "Giám đốc kho vận", "field": "storage", "per_level": 15, "costs": [60, 150, 350],
		"text": "Kho nguyên liệu và kho thành phẩm rộng thêm %d%%."},
	"strategy_advisor": {"name": "Cố vấn chiến lược", "field": "profit", "per_level": 10, "costs": [150, 350, 750],
		"text": "Chi nhánh trong nước và nước ngoài lãi thêm %d%%."},
}
const SENIOR_ORDER := ["productivity_expert", "chief_engineer", "purchasing_head", "negotiator", "people_coach", "logistics_head", "strategy_advisor"]

## Production boost: machines in every factory run this much faster.
const BOOST_PERCENT := 50
const BOOST_DIAMOND_COST := 10
const BOOST_DIAMOND_HOURS := 4
const BOOST_AD_HOURS := 2
## Staff party: everyone's mood rises; a strike ends.
const PARTY_COST := 20
const PARTY_MOOD := 25
## Instant repair of one machine.
const REPAIR_COST := 3
## Finishing a construction or a factory / branch now: one diamond per this
## many game hours left, at least one.
const RUSH_HOURS_PER_DIAMOND := 3
## Diamonds -> cash, in lots of EXCHANGE_LOT; cash per diamond grows with the
## company stage so the exchange stays useful but never breaks the economy.
const EXCHANGE_LOT := 10
const EXCHANGE_CENTS := [10000, 40000, 150000, 400000, 1000000]

## Rewarded ads (watched only when the player taps the button).
const AD_DIAMONDS := 5
## Ads for diamonds per real day, and ads of every kind per real day.
const AD_DIAMOND_LIMIT := 5
const AD_DAILY_LIMIT := 12
## End-of-day bonus: this share of the day's sales, at least AD_REPORT_MIN.
const AD_REPORT_PERCENT := 20
const AD_REPORT_MIN := 20000

## In-app purchase packs (consumable). Product ids must match App Store
## Connect / Google Play Console; prices are set in the stores.
const PACKS := [
	{"id": "diamonds_small", "diamonds": 60, "bonus": 0, "price": "0,99 USD"},
	{"id": "diamonds_medium", "diamonds": 300, "bonus": 30, "price": "4,99 USD"},
	{"id": "diamonds_large", "diamonds": 650, "bonus": 100, "price": "9,99 USD"},
	{"id": "diamonds_huge", "diamonds": 1400, "bonus": 300, "price": "19,99 USD"},
]

var sim: Simulation


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func balance() -> int:
	return int(sim.state.diamonds)


func can_spend(amount: int) -> bool:
	return balance() >= amount


## source: quest, ad, purchase, gift, refund.
func earn(amount: int, source: String, note := "") -> void:
	if amount <= 0:
		return
	sim.state.diamonds = balance() + amount
	_stat("earned_" + source, amount)
	sim.emit_event(&"diamonds_changed", {"diamonds": balance(), "amount": amount, "source": source, "note": note})


func spend(amount: int, what: String) -> bool:
	if not can_spend(amount):
		return false
	sim.state.diamonds = balance() - amount
	_stat("spent", amount)
	sim.emit_event(&"diamonds_changed", {"diamonds": balance(), "amount": -amount, "source": "spend", "note": what})
	return true


func _stat(key: String, amount: int) -> void:
	sim.state.diamond_stats[key] = int(sim.state.diamond_stats.get(key, 0)) + amount


func _not_enough(cost: int) -> Dictionary:
	return Simulation.fail("Không đủ kim cương (cần %d, đang có %d). Làm nhiệm vụ, xem quảng cáo hoặc nạp thêm." % [cost, balance()])


# --- Senior managers ---------------------------------------------------------

func senior_level(id: String) -> int:
	return int(sim.state.seniors.get(id, {}).get("level", 0))


func senior_name(id: String) -> String:
	return str(sim.state.seniors.get(id, {}).get("name", ""))


## Diamonds for the next level, -1 at the top level.
func senior_cost(id: String) -> int:
	var costs: Array = SENIORS[id].costs
	var lvl := senior_level(id)
	return int(costs[lvl]) if lvl < costs.size() else -1


func senior_text(id: String, level := -1) -> String:
	var s: Dictionary = SENIORS[id]
	var lvl := senior_level(id) if level < 0 else level
	return s.text % (int(s.per_level) * maxi(1, lvl))


## Sum of the senior managers' bonus for one field.
func bonus(field: String) -> int:
	var total := 0
	for id in sim.state.seniors:
		var s: Dictionary = SENIORS.get(id, {})
		if s.get("field", "") == field:
			total += int(s.per_level) * senior_level(id)
	return total


func recruit_senior(id: String) -> Dictionary:
	if not SENIORS.has(id):
		return Simulation.fail("Không có vị trí này.")
	var s: Dictionary = SENIORS[id]
	var cost := senior_cost(id)
	if cost < 0:
		return Simulation.fail("%s đã ở cấp cao nhất." % s.name)
	if not can_spend(cost):
		return _not_enough(cost)
	spend(cost, s.name)
	var lvl := senior_level(id) + 1
	if lvl == 1:
		sim.state.seniors[id] = {"name": sim.employees.next_name(), "level": 1}
		sim.emit_event(&"expansion_changed", {})
		return Simulation.ok("%s gia nhập làm %s: %s" % [senior_name(id), s.name, senior_text(id)])
	sim.state.seniors[id].level = lvl
	sim.emit_event(&"expansion_changed", {})
	return Simulation.ok("%s lên cấp %d: %s" % [s.name, lvl, senior_text(id)])


# --- Production boost ----------------------------------------------------------

func boost_ticks_left() -> int:
	return int(sim.state.boost.get("ticks_left", 0))


func boost_percent() -> int:
	return BOOST_PERCENT if boost_ticks_left() > 0 else 0


func _start_boost(hours: int) -> void:
	var ticks := hours * sim.config.ticks_per_hour
	# A second boost adds its time to the one running.
	sim.state.boost = {"ticks_left": boost_ticks_left() + ticks}
	sim.emit_event(&"expansion_changed", {})


func buy_boost() -> Dictionary:
	if not spend(BOOST_DIAMOND_COST, "Tăng tốc sản xuất"):
		return _not_enough(BOOST_DIAMOND_COST)
	_start_boost(BOOST_DIAMOND_HOURS)
	return Simulation.ok("Mọi máy chạy nhanh hơn %d%% trong %d giờ tới." % [BOOST_PERCENT, BOOST_DIAMOND_HOURS])


func tick() -> void:
	var left := boost_ticks_left()
	if left <= 0:
		return
	left -= 1
	if left <= 0:
		sim.state.boost = {}
		sim.emit_event(&"expansion_changed", {})
		sim.emit_event(&"boost_ended", {})
	else:
		sim.state.boost.ticks_left = left


# --- Other uses --------------------------------------------------------------

func party() -> Dictionary:
	if sim.state.employees.is_empty():
		return Simulation.fail("Chưa có nhân viên nào.")
	if not spend(PARTY_COST, "Liên hoan nhân viên"):
		return _not_enough(PARTY_COST)
	for e in sim.state.employees:
		e.mood = mini(100, int(e.get("mood", 70)) + PARTY_MOOD)
	var striking := sim.employees.on_strike()
	if striking:
		sim.state.strike = {}
		sim.emit_event(&"strike_ended", {})
	return Simulation.ok("Liên hoan vui vẻ! Mọi người phấn khởi hơn%s." % (" và quay lại làm việc" if striking else ""))


func instant_repair(machine_id: int) -> Dictionary:
	var m := sim.state.find_by_id(sim.state.machines, machine_id)
	if m.is_empty():
		return Simulation.fail("Không tìm thấy máy.")
	if int(m.condition) >= 100 and not m.broken:
		return Simulation.fail("Máy đang ở tình trạng tốt.")
	if not spend(REPAIR_COST, "Sửa máy ngay"):
		return _not_enough(REPAIR_COST)
	sim.production.finish_repair(m)
	return Simulation.ok("Máy đã được sửa xong ngay.")


## What can be finished at once: [{kind, id, name, ticks_left}].
func rush_targets() -> Array:
	var out := []
	var c: Dictionary = sim.state.construction
	if not c.is_empty():
		out.append({"kind": "construction", "id": c.id, "name": sim.content.constructions[c.id].display_name, "ticks_left": int(c.ticks_left)})
	for s in sim.state.sites:
		if s.status == ExpansionManager.SURVEYING or s.status == ExpansionManager.BUILDING:
			var verb := "Khảo sát " if s.status == ExpansionManager.SURVEYING else "Xây "
			out.append({"kind": "site", "id": s.id, "name": verb + sim.expansion.loc(s.id).display_name, "ticks_left": int(s.ticks_left)})
	return out


func rush_cost(ticks_left: int) -> int:
	var hours := ceili(float(ticks_left) / sim.config.ticks_per_hour)
	return maxi(1, ceili(float(hours) / RUSH_HOURS_PER_DIAMOND))


func rush(kind: String, id: String) -> Dictionary:
	for t in rush_targets():
		if t.kind != kind or t.id != id:
			continue
		var cost := rush_cost(t.ticks_left)
		if not spend(cost, "Hoàn thành ngay " + t.name):
			return _not_enough(cost)
		if kind == "construction":
			sim.state.construction.ticks_left = 1
			sim.buildings.tick()
		else:
			var s := sim.expansion.site(id)
			s.ticks_left = 1
			sim.expansion.tick()
		return Simulation.ok("%s đã hoàn thành!" % t.name)
	return Simulation.fail("Không có công việc nào đang làm dở ở đây.")


func exchange_rate() -> int:
	return EXCHANGE_CENTS[clampi(sim.expansion.tier(), 0, EXCHANGE_CENTS.size() - 1)]


func exchange() -> Dictionary:
	var cash := exchange_rate() * EXCHANGE_LOT
	if not spend(EXCHANGE_LOT, "Đổi kim cương lấy tiền"):
		return _not_enough(EXCHANGE_LOT)
	sim.economy.book("diamonds", cash, "Đổi %d kim cương" % EXCHANGE_LOT)
	sim.economy.add_stat("bonus", cash)
	return Simulation.ok("Đã đổi %d kim cương lấy %s." % [EXCHANGE_LOT, Fmt.money(cash)])


# --- Rewarded ads --------------------------------------------------------------
# `date` is the player's real calendar day (YYYY-MM-DD), given by the caller
# so the core stays free of clocks; the limits reset each real day.

func _ads(date: String) -> Dictionary:
	if str(sim.state.ads.get("date", "")) != date:
		sim.state.ads = {"date": date, "count": 0, "diamonds": 0, "report_day": int(sim.state.ads.get("report_day", 0))}
	return sim.state.ads


func ads_left(date: String) -> int:
	return maxi(0, AD_DAILY_LIMIT - int(_ads(date).count))


func ad_diamonds_left(date: String) -> int:
	return mini(ads_left(date), maxi(0, AD_DIAMOND_LIMIT - int(_ads(date).diamonds)))


## Cash the end-of-day ad would add for this report, 0 once claimed.
func report_bonus(report: Dictionary) -> int:
	if int(sim.state.ads.get("report_day", 0)) >= int(report.get("day", 0)):
		return 0
	var revenue := int(report.get("stats", {}).get("revenue", 0))
	return maxi(AD_REPORT_MIN, revenue * AD_REPORT_PERCENT / 100)


func can_watch(kind: String, date: String, report: Dictionary = {}) -> bool:
	if ads_left(date) <= 0:
		return false
	match kind:
		"diamonds":
			return ad_diamonds_left(date) > 0
		"report":
			return report_bonus(report) > 0
		"boost":
			return true
	return false


## Called once the ad network confirms the player watched the whole ad.
func ad_reward(kind: String, date: String, report: Dictionary = {}) -> Dictionary:
	if not can_watch(kind, date, report):
		return Simulation.fail("Hôm nay đã hết lượt xem quảng cáo này, mai quay lại nhé.")
	var a := _ads(date)
	a.count = int(a.count) + 1
	_stat("ads_watched", 1)
	match kind:
		"diamonds":
			a.diamonds = int(a.diamonds) + 1
			earn(AD_DIAMONDS, "ad", "Xem quảng cáo")
			return Simulation.ok("Cảm ơn bạn! +%d kim cương." % AD_DIAMONDS)
		"report":
			var cash := report_bonus(report)
			a.report_day = int(report.day)
			sim.economy.book("diamonds", cash, "Thưởng cuối ngày %d" % int(report.day))
			sim.economy.add_stat("bonus", cash)
			return Simulation.ok("Đã nhận thưởng %s." % Fmt.money(cash))
		_:
			_start_boost(BOOST_AD_HOURS)
			return Simulation.ok("Mọi máy chạy nhanh hơn %d%% trong %d giờ tới." % [BOOST_PERCENT, BOOST_AD_HOURS])


# --- In-app purchases ----------------------------------------------------------

static func pack(product_id: String) -> Dictionary:
	for p in PACKS:
		if p.id == product_id:
			return p
	return {}


## Credits a pack once per store transaction (stores may report the same
## purchase again after a crash or on the next launch).
func credit_purchase(product_id: String, transaction_id: String) -> Dictionary:
	var p := pack(product_id)
	if p.is_empty():
		return Simulation.fail("Gói không hợp lệ: %s" % product_id)
	var log: Array = sim.state.iap_log
	if transaction_id != "":
		for entry in log:
			if entry.get("txn", "") == transaction_id:
				return Simulation.ok("")  # already credited
	var amount := int(p.diamonds) + int(p.bonus)
	log.append({"txn": transaction_id, "product": product_id, "diamonds": amount, "tick": sim.state.tick})
	while log.size() > 100:
		log.pop_front()
	earn(amount, "purchase", product_id)
	return Simulation.ok("Nạp thành công +%d kim cương. Cảm ơn bạn đã ủng hộ!" % amount)
