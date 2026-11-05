## Quests that pay diamonds: three daily quests that change every game day,
## and one-time achievements along the way from workshop to multinational
## group. Progress comes from simulation events; rewards are claimed by the
## player (a tap), so a claim is always visible.
class_name QuestManager
extends RefCounted

## Daily quest kinds: the event that counts and how much each counts.
## target(sim) gives the goal for the day, scaled to the size of the company.
const DAILY_KINDS := {
	"produce": {"text": "Sản xuất %d sản phẩm đạt chuẩn", "reward": 2},
	"ship": {"text": "Giao xong %d đơn hàng", "reward": 2},
	"revenue": {"text": "Thu về %s tiền bán hàng", "reward": 3},
	"accept": {"text": "Nhận %d đơn hàng mới", "reward": 1},
	"buy_material": {"text": "Đặt mua %d lô hạt nhựa", "reward": 1},
	"upgrade": {"text": "Nâng cấp máy %d lần", "reward": 2},
	"hire": {"text": "Tuyển %d nhân viên", "reward": 1},
}
const DAILY_COUNT := 3
## Extra diamonds once all of the day's quests are claimed.
const DAILY_ALL_BONUS := 3

## One-time achievements: {id: [text, reward]}; met() checks each one.
const MILESTONES := [
	["first_order", "Giao đơn hàng đầu tiên", 10],
	["tutorial", "Hoàn thành hướng dẫn", 10],
	["machines_3", "Có 3 máy trong xưởng", 10],
	["orders_25", "Giao tổng cộng 25 đơn hàng", 20],
	["break_room", "Xây phòng nghỉ nhân viên", 10],
	["machines_8", "Có 8 máy", 20],
	["revenue_100k", "Tổng doanh thu đạt $100.000", 25],
	["factory_2", "Xây xong nhà xưởng thứ hai", 30],
	["orders_100", "Giao tổng cộng 100 đơn hàng", 40],
	["tier_1", "Thành lập Công ty TNHH", 30],
	["tier_2", "Thành lập Tổng công ty", 50],
	["tier_3", "Thành lập Tập đoàn", 80],
	["tier_4", "Trở thành Tập đoàn đa quốc gia", 120],
	["revenue_10m", "Tổng doanh thu đạt $10 triệu", 100],
]

var sim: Simulation


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func q() -> Dictionary:
	return sim.state.quests


# --- Daily quests ------------------------------------------------------------

func daily() -> Array:
	return q().get("daily", [])


## Picks the day's quests: the same game and day always give the same set.
func new_day() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.state.world_seed, sim.day()])
	var pool: Array = DAILY_KINDS.keys()
	if sim.state.machines.size() < 2:
		pool.erase("upgrade")  # little to upgrade on the first day
	var list := []
	while list.size() < DAILY_COUNT and not pool.is_empty():
		var kind: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		list.append({"kind": kind, "target": _target(kind), "progress": 0, "claimed": false})
	q().daily = list
	q().day = sim.day()
	q().bonus_claimed = false


func _target(kind: String) -> int:
	var machines := maxi(1, sim.state.machines.size())
	match kind:
		"produce":
			return maxi(50, snappedi(machines * 60, 10))
		"ship":
			return 2 if machines < 4 else 3
		"revenue":
			var last := 0
			if not sim.state.reports.is_empty():
				last = int(sim.state.reports[-1].stats.get("revenue", 0))
			return maxi(50000, snappedi(last * 8 / 10, 10000))
		"accept":
			return 2
		"buy_material":
			return 1 if sim.state.settings.get("auto_buy", false) else 2
		"upgrade":
			return 1
		"hire":
			return 1
	return 1


func daily_text(d: Dictionary) -> String:
	var t: String = DAILY_KINDS[d.kind].text
	return t % (Fmt.money(int(d.target)) if d.kind == "revenue" else int(d.target))


func daily_reward(d: Dictionary) -> int:
	return int(DAILY_KINDS[d.kind].reward)


func daily_done(d: Dictionary) -> bool:
	return int(d.progress) >= int(d.target)


func _count(kind: String, amount: int) -> void:
	for d in daily():
		if d.kind == kind and not daily_done(d):
			d.progress = mini(int(d.target), int(d.progress) + amount)
			if daily_done(d):
				sim.emit_event(&"quest_completed", {"text": daily_text(d)})


func claim_daily(index: int) -> Dictionary:
	var list := daily()
	if index < 0 or index >= list.size():
		return Simulation.fail("Không có nhiệm vụ này.")
	var d: Dictionary = list[index]
	if d.claimed:
		return Simulation.fail("Đã nhận thưởng rồi.")
	if not daily_done(d):
		return Simulation.fail("Chưa hoàn thành nhiệm vụ.")
	d.claimed = true
	var reward := daily_reward(d)
	sim.diamonds.earn(reward, "quest", daily_text(d))
	var msg := "+%d kim cương" % reward
	if all_daily_claimed() and not q().get("bonus_claimed", false):
		q().bonus_claimed = true
		sim.diamonds.earn(DAILY_ALL_BONUS, "quest", "Xong cả %d nhiệm vụ ngày" % DAILY_COUNT)
		msg += ", thưởng thêm %d vì xong cả ngày" % DAILY_ALL_BONUS
	return Simulation.ok(msg + "!")


func all_daily_claimed() -> bool:
	for d in daily():
		if not d.claimed:
			return false
	return not daily().is_empty()


# --- Achievements --------------------------------------------------------------

func milestone_claimed(id: String) -> bool:
	return q().get("claimed", []).has(id)


func milestone_met(id: String) -> bool:
	var s := sim.state
	var shipped := int(q().get("shipped", 0))
	match id:
		"first_order":
			return shipped >= 1
		"tutorial":
			return sim.tutorial.current_text() == ""
		"machines_3":
			return s.machines.size() >= 3
		"machines_8":
			return s.machines.size() >= 8
		"orders_25":
			return shipped >= 25
		"orders_100":
			return shipped >= 100
		"break_room":
			return sim.buildings.level("break_room") > 0
		"revenue_100k":
			return s.total_revenue >= 10000000
		"revenue_10m":
			return s.total_revenue >= 1000000000
		"factory_2":
			return not sim.expansion.factory_ids().is_empty()
		"tier_1", "tier_2", "tier_3", "tier_4":
			return sim.expansion.tier() >= id.trim_prefix("tier_").to_int()
	return false


## Achievements in order: [{id, text, reward, met, claimed}].
func milestones() -> Array:
	var out := []
	for m in MILESTONES:
		out.append({"id": m[0], "text": m[1], "reward": m[2], "met": milestone_met(m[0]), "claimed": milestone_claimed(m[0])})
	return out


func claim_milestone(id: String) -> Dictionary:
	for m in MILESTONES:
		if m[0] != id:
			continue
		if milestone_claimed(id):
			return Simulation.fail("Đã nhận thưởng rồi.")
		if not milestone_met(id):
			return Simulation.fail("Chưa đạt thành tựu này.")
		var claimed: Array = q().get("claimed", [])
		claimed.append(id)
		q().claimed = claimed
		sim.diamonds.earn(int(m[2]), "quest", m[1])
		return Simulation.ok("Thành tựu \"%s\": +%d kim cương!" % [m[1], m[2]])
	return Simulation.fail("Không có thành tựu này.")


## Rewards waiting for a tap (daily and achievements), for the badge.
func claimable() -> int:
	var n := 0
	for d in daily():
		if daily_done(d) and not d.claimed:
			n += 1
	for m in MILESTONES:
		if not milestone_claimed(m[0]) and milestone_met(m[0]):
			n += 1
	return n


func on_event(name: StringName, data: Dictionary) -> void:
	match name:
		&"unit_produced":
			_count("produce", 1)
		&"order_completed":
			q().shipped = int(q().get("shipped", 0)) + 1
			_count("ship", 1)
			_count("revenue", int(data.get("value", 0)) - int(data.get("penalty", 0)))
		&"order_accepted":
			_count("accept", 1)
		&"material_ordered":
			_count("buy_material", 1)
		&"machine_upgraded":
			_count("upgrade", 1)
		&"employee_hired":
			_count("hire", 1)
		&"day_started", &"game_loaded":
			if int(q().get("day", 0)) != sim.day():
				new_day()
