## Growing the business beyond the first hall: production line speed-ups,
## more factories on the land next door, branches in other provinces and
## abroad, company stages (workshop -> company -> corporation -> group ->
## multinational group) and the executives each stage can appoint.
##
## Only the first factory is simulated machine by machine. Every other site
## is run by its head (factory manager or branch director) and earns a daily
## profit from its production lines, booked at the end of the day.
class_name ExpansionManager
extends RefCounted

const LOCAL := "local"
const DOMESTIC := "domestic"
const ABROAD := "abroad"

# Site status
const SURVEYING := "surveying"
const SURVEYED := "surveyed"
const LAND := "land"
const BUILDING := "building"
const READY := "ready"

const TIER_NAMES := ["Xưởng sản xuất", "Công ty TNHH", "Tổng công ty", "Tập đoàn", "Tập đoàn đa quốc gia"]
const OWNER_TITLES := ["Chủ xưởng", "Giám đốc công ty", "Tổng giám đốc", "Chủ tịch tập đoàn", "Chủ tịch tập đoàn đa quốc gia"]
## Registration fee for reaching each stage (index = stage).
const TIER_FEES := [0, 1000000, 5000000, 20000000, 50000000]
const HEAD_TITLES := {LOCAL: "Xưởng trưởng", DOMESTIC: "Giám đốc chi nhánh", ABROAD: "Giám đốc chi nhánh"}
const REGION_NAMES := {LOCAL: "Nhà xưởng mới", DOMESTIC: "Chi nhánh trong nước", ABROAD: "Chi nhánh nước ngoài"}

## "Production line improvements" for the first factory: each level makes
## every machine there this many percent faster.
const LINE_SPEED_COSTS := [150000, 300000, 600000, 1200000, 2400000]
const LINE_SPEED_PERCENT := 10
## A factory manager in the first factory speeds every machine up.
const MANAGER_SPEED_PERCENT := 15
## Each automation level of a site adds this much to its profit.
const AUTOMATION_PERCENT := 20
const MAX_AUTOMATION := 3

## Company-wide positions. speed: % faster machines in the first factory;
## profit: % more profit at every other site; domestic / abroad: extra % for
## branches in that region; upkeep: % less site upkeep; price: % higher
## order prices; interest: % less overdraft interest; survey: % shorter surveys.
const EXECUTIVES := {
	"production_director": {"name": "Giám đốc sản xuất", "tier": 1, "wage": 30000,
		"speed": 10, "profit": 10, "text": "Máy ở xưởng chính chạy nhanh hơn 10%, mọi xưởng và chi nhánh lãi thêm 10%."},
	"chief_accountant": {"name": "Kế toán trưởng", "tier": 1, "wage": 20000,
		"upkeep": 20, "interest": 50, "text": "Chi phí duy trì các xưởng, chi nhánh giảm 20%, lãi thấu chi giảm một nửa."},
	"sales_director": {"name": "Giám đốc kinh doanh", "tier": 2, "wage": 50000,
		"price": 10, "domestic": 10, "text": "Đơn hàng mới trả giá cao hơn 10%, chi nhánh trong nước lãi thêm 10%."},
	"hr_director": {"name": "Giám đốc nhân sự", "tier": 2, "wage": 40000,
		"head_wage": 20, "text": "Lương xưởng trưởng và giám đốc chi nhánh giảm 20%."},
	"cfo": {"name": "Giám đốc tài chính (CFO)", "tier": 3, "wage": 80000,
		"profit": 10, "interest": 50, "text": "Mọi xưởng và chi nhánh lãi thêm 10%, lãi thấu chi giảm thêm một nửa."},
	"intl_director": {"name": "Giám đốc khu vực quốc tế", "tier": 3, "wage": 100000,
		"abroad": 20, "survey": 50, "text": "Chi nhánh nước ngoài lãi thêm 20%, khảo sát nhanh gấp đôi."},
	"ceo": {"name": "Tổng giám đốc điều hành (CEO)", "tier": 4, "wage": 200000,
		"speed": 15, "profit": 15, "text": "Toàn tập đoàn: máy nhanh hơn 15%, mọi xưởng và chi nhánh lãi thêm 15%."},
}
const EXECUTIVE_ORDER := ["production_director", "chief_accountant", "sales_director", "hr_director", "cfo", "intl_director", "ceo"]
## Hiring fee = this many days of wages.
const HIRE_FEE_DAYS := 3

var sim: Simulation


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func loc(id: String) -> LocationDef:
	return sim.content.locations.get(id)


func site(id: String) -> Dictionary:
	for s in sim.state.sites:
		if s.id == id:
			return s
	return {}


func is_ready(id: String) -> bool:
	return site(id).get("status", "") == READY


# --- Company stage -------------------------------------------------------------

func tier() -> int:
	return int(sim.state.company_tier)


func tier_name() -> String:
	return TIER_NAMES[tier()]


func owner_title() -> String:
	return OWNER_TITLES[tier()]


## Factories that are producing: the first one plus every finished site with a head.
func factories_operating() -> int:
	var n := 1
	for s in sim.state.sites:
		if s.status == READY and s.head != "":
			n += 1
	return n


func ready_count(region: String) -> int:
	var n := 0
	for s in sim.state.sites:
		if s.status == READY and loc(s.id).region == region:
			n += 1
	return n


func countries_abroad() -> Array:
	var list := []
	for s in sim.state.sites:
		if s.status == READY and loc(s.id).region == ABROAD and not list.has(loc(s.id).country):
			list.append(loc(s.id).country)
	return list


## What the next stage needs: {text, met, fee}; text is "" at the last stage.
func next_tier_requirement() -> Dictionary:
	var t := tier() + 1
	match t:
		1:
			return {"text": "Có ít nhất 2 nhà xưởng đang chạy (xây Xưởng 2 và thuê xưởng trưởng)", "met": factories_operating() >= 2, "fee": TIER_FEES[t]}
		2:
			return {"text": "Có ít nhất 2 chi nhánh trong nước đã hoạt động (đang có %d)" % ready_count(DOMESTIC), "met": ready_count(DOMESTIC) >= 2, "fee": TIER_FEES[t]}
		3:
			return {"text": "Có ít nhất 1 chi nhánh ở nước ngoài đã hoạt động", "met": ready_count(ABROAD) >= 1, "fee": TIER_FEES[t]}
		4:
			return {"text": "Có chi nhánh hoạt động ở ít nhất 3 nước ngoài (đang có %d)" % countries_abroad().size(), "met": countries_abroad().size() >= 3, "fee": TIER_FEES[t]}
	return {"text": "", "met": false, "fee": 0}


func advance_tier() -> Dictionary:
	var req := next_tier_requirement()
	if req.text == "":
		return Simulation.fail("Đã là tập đoàn đa quốc gia.")
	if not req.met:
		return Simulation.fail("Chưa đủ điều kiện: %s." % req.text)
	if not sim.economy.can_afford(req.fee):
		return Simulation.fail("Không đủ tiền đăng ký (%s)." % Fmt.money(req.fee))
	sim.economy.book("expansion", -req.fee, "Đăng ký " + TIER_NAMES[tier() + 1])
	sim.state.company_tier = tier() + 1
	sim.emit_event(&"tier_changed", {"tier": tier()})
	return Simulation.ok("Chúc mừng! Bạn đã thành lập %s. Chức danh mới: %s." % [tier_name(), owner_title()])


# --- Line speed (first factory) ------------------------------------------------

func line_speed_level() -> int:
	return int(sim.state.line_speed_level)


func line_speed_cost() -> int:
	var lvl := line_speed_level()
	return LINE_SPEED_COSTS[lvl] if lvl < LINE_SPEED_COSTS.size() else -1


func upgrade_line_speed() -> Dictionary:
	var cost := line_speed_cost()
	if cost < 0:
		return Simulation.fail("Dây chuyền đã cải tiến tối đa.")
	if not sim.economy.can_afford(cost):
		return Simulation.fail("Không đủ tiền (%s)." % Fmt.money(cost))
	sim.economy.book("upgrade", -cost, "Cải tiến dây chuyền")
	sim.state.line_speed_level = line_speed_level() + 1
	sim.emit_event(&"expansion_changed", {})
	return Simulation.ok("Dây chuyền cấp %d: máy nhanh hơn %d%%." % [line_speed_level(), line_speed_level() * LINE_SPEED_PERCENT])


## Total speed bonus (percent) for every machine in the first factory.
func speed_bonus_percent() -> int:
	var total := line_speed_level() * LINE_SPEED_PERCENT
	if sim.employees.count(EmployeeManager.MANAGER) > 0:
		total += MANAGER_SPEED_PERCENT
	return total + _exec_sum("speed")


# --- Executives ----------------------------------------------------------------

func has_exec(id: String) -> bool:
	return sim.state.executives.has(id)


func _exec_sum(field: String) -> int:
	var total := 0
	for id in sim.state.executives:
		total += int(EXECUTIVES[id].get(field, 0))
	return total


func exec_hire_fee(id: String) -> int:
	return int(EXECUTIVES[id].wage) * HIRE_FEE_DAYS


func hire_exec(id: String) -> Dictionary:
	if not EXECUTIVES.has(id):
		return Simulation.fail("Không có chức vụ này.")
	var e: Dictionary = EXECUTIVES[id]
	if has_exec(id):
		return Simulation.fail("Đã có %s." % e.name)
	if tier() < int(e.tier):
		return Simulation.fail("Cần trở thành %s trước." % TIER_NAMES[e.tier])
	var fee := exec_hire_fee(id)
	if not sim.economy.can_afford(fee):
		return Simulation.fail("Không đủ tiền tuyển (%s)." % Fmt.money(fee))
	var person := sim.employees.next_name()
	sim.economy.book("hire", -fee, "Bổ nhiệm %s" % e.name)
	sim.state.executives[id] = person
	sim.emit_event(&"expansion_changed", {})
	return Simulation.ok("%s được bổ nhiệm làm %s." % [person, e.name])


func fire_exec(id: String) -> Dictionary:
	if not has_exec(id):
		return Simulation.fail("Chức vụ này đang trống.")
	var person: String = sim.state.executives[id]
	sim.state.executives.erase(id)
	sim.emit_event(&"expansion_changed", {})
	return Simulation.ok("%s đã thôi giữ chức %s." % [person, EXECUTIVES[id].name])


func exec_wages() -> int:
	var total := 0
	for id in sim.state.executives:
		total += int(EXECUTIVES[id].wage)
	return total


## Percent multiplier for new order prices.
func order_price_percent() -> int:
	return 100 + _exec_sum("price")


## Percent of overdraft interest still charged.
func interest_percent() -> int:
	var pct := 100
	for id in sim.state.executives:
		pct = pct * (100 - int(EXECUTIVES[id].get("interest", 0))) / 100
	return pct


# --- Sites ---------------------------------------------------------------------

func head_title(l: LocationDef) -> String:
	return HEAD_TITLES[l.region]


func head_wage(l: LocationDef) -> int:
	return l.head_wage_per_day * (100 - _exec_sum("head_wage")) / 100


func head_hire_fee(l: LocationDef) -> int:
	return l.head_wage_per_day * 2


func survey_hours(l: LocationDef) -> int:
	return maxi(1, l.survey_hours * (100 - _exec_sum("survey")) / 100)


func automation_cost(s: Dictionary) -> int:
	var lvl := int(s.automation)
	return -1 if lvl >= MAX_AUTOMATION else loc(s.id).line_cost * 3 * (lvl + 1)


## True when the factory before this plot has every machine place filled
## (plots open one after the other).
func previous_full(l: LocationDef) -> bool:
	if l.region != LOCAL:
		return true
	var prev := "lot_%d" % (l.order - 1)
	if l.order <= 2 or not sim.content.locations.has(prev):
		return sim.state.machines.size() >= sim.buildings.machine_slots()
	var p := site(prev)
	return not p.is_empty() and p.status == READY and int(p.lines) >= loc(prev).max_lines


## Why the next step at this location cannot be taken, or "" when it can.
func block_reason(id: String) -> String:
	var l := loc(id)
	if l == null:
		return "Không có địa điểm này"
	if tier() < l.min_tier:
		return "Cần trở thành %s" % TIER_NAMES[l.min_tier]
	var s := site(id)
	var cost := next_step_cost(id)
	if s.is_empty():
		if l.region == LOCAL and not previous_full(l):
			return "Cần đặt đủ máy ở xưởng trước" if l.order <= 2 else "Cần đủ %d dây chuyền ở %s" % [loc("lot_%d" % (l.order - 1)).max_lines, loc("lot_%d" % (l.order - 1)).display_name]
	elif s.status == SURVEYING or s.status == BUILDING or s.status == READY:
		return "Đang thực hiện" if s.status != READY else "Đã hoạt động"
	if not sim.economy.can_afford(cost):
		return "Không đủ tiền"
	return ""


## Cost of the next step (survey, land, construction), -1 if none.
func next_step_cost(id: String) -> int:
	var l := loc(id)
	var s := site(id)
	if s.is_empty():
		if l.region == LOCAL:
			return l.land_cost
		return l.survey_cost
	match s.status:
		LAND:
			return l.build_cost
		SURVEYED:
			return l.land_cost + l.build_cost
	return -1


## Takes the next step at a location: survey -> open branch for provinces and
## abroad, buy land -> build the hall for the plots next door.
func next_step(id: String) -> Dictionary:
	var reason := block_reason(id)
	if reason != "":
		return Simulation.fail(reason + ".")
	var l := loc(id)
	var s := site(id)
	var cost := next_step_cost(id)
	if s.is_empty():
		s = {"id": id, "status": LAND, "ticks_left": 0, "total_ticks": 0, "lines": 0, "automation": 0, "head": "", "market": 100}
		sim.state.sites.append(s)
		if l.region == LOCAL:
			sim.economy.book("expansion", -cost, "Mua đất " + l.display_name)
			sim.emit_event(&"expansion_changed", {"id": id})
			return Simulation.ok("Đã mua đất cho %s. Giờ có thể xây nhà xưởng." % l.display_name)
		sim.economy.book("expansion", -cost, "Khảo sát " + l.display_name)
		_start(s, SURVEYING, survey_hours(l))
		return Simulation.ok("Đang khảo sát %s, có kết quả sau %d giờ." % [l.display_name, survey_hours(l)])
	sim.economy.book("expansion", -cost, ("Xây " if l.region == LOCAL else "Mở ") + l.display_name)
	_start(s, BUILDING, l.build_hours)
	return Simulation.ok("Bắt đầu xây %s, xong sau %d giờ." % [l.display_name, l.build_hours])


func _start(s: Dictionary, status: String, hours: int) -> void:
	s.status = status
	s.total_ticks = hours * sim.config.ticks_per_hour
	s.ticks_left = s.total_ticks
	sim.emit_event(&"expansion_changed", {"id": s.id})


func buy_line(id: String) -> Dictionary:
	var s := site(id)
	if s.is_empty() or s.status != READY:
		return Simulation.fail("Nhà xưởng chưa xây xong.")
	var l := loc(id)
	if int(s.lines) >= l.max_lines:
		return Simulation.fail("Đã đủ %d dây chuyền." % l.max_lines)
	if not sim.economy.can_afford(l.line_cost):
		return Simulation.fail("Không đủ tiền (%s)." % Fmt.money(l.line_cost))
	sim.economy.book("machine", -l.line_cost, "Dây chuyền cho " + l.display_name)
	s.lines = int(s.lines) + 1
	sim.emit_event(&"expansion_changed", {"id": id})
	return Simulation.ok("%s có %d dây chuyền." % [l.display_name, s.lines])


func upgrade_automation(id: String) -> Dictionary:
	var s := site(id)
	if s.is_empty() or s.status != READY:
		return Simulation.fail("Nhà xưởng chưa xây xong.")
	var cost := automation_cost(s)
	if cost < 0:
		return Simulation.fail("Đã tự động hoá tối đa.")
	if not sim.economy.can_afford(cost):
		return Simulation.fail("Không đủ tiền (%s)." % Fmt.money(cost))
	sim.economy.book("upgrade", -cost, "Tự động hoá " + loc(id).display_name)
	s.automation = int(s.automation) + 1
	sim.emit_event(&"expansion_changed", {"id": id})
	return Simulation.ok("%s tự động hoá cấp %d: lãi thêm %d%%." % [loc(id).display_name, s.automation, int(s.automation) * AUTOMATION_PERCENT])


func hire_head(id: String) -> Dictionary:
	var s := site(id)
	var l := loc(id)
	if s.is_empty() or not (s.status == READY or s.status == BUILDING):
		return Simulation.fail("Hãy xây nhà xưởng trước.")
	if s.head != "":
		return Simulation.fail("%s đã có %s." % [l.display_name, head_title(l).to_lower()])
	var fee := head_hire_fee(l)
	if not sim.economy.can_afford(fee):
		return Simulation.fail("Không đủ tiền tuyển (%s)." % Fmt.money(fee))
	var person := sim.employees.next_name()
	sim.economy.book("hire", -fee, "Tuyển %s %s" % [head_title(l).to_lower(), l.display_name])
	s.head = person
	sim.emit_event(&"expansion_changed", {"id": id})
	return Simulation.ok("%s làm %s %s." % [person, head_title(l).to_lower(), l.display_name])


func fire_head(id: String) -> Dictionary:
	var s := site(id)
	if s.is_empty() or s.head == "":
		return Simulation.fail("Chưa có người quản lý.")
	var person: String = s.head
	s.head = ""
	sim.emit_event(&"expansion_changed", {"id": id})
	return Simulation.ok("%s đã nghỉ. Xưởng sẽ dừng cho tới khi có người mới." % person)


## Profit bonus (percent) for a site, before its market factor.
func profit_bonus_percent(s: Dictionary) -> int:
	var l := loc(s.id)
	var bonus := int(s.automation) * AUTOMATION_PERCENT + _exec_sum("profit")
	if l.region == DOMESTIC:
		bonus += _exec_sum("domestic")
	elif l.region == ABROAD:
		bonus += _exec_sum("abroad")
	return bonus


## Daily earnings of a site's lines; nothing without a head.
func daily_income(s: Dictionary) -> int:
	if s.status != READY or s.head == "":
		return 0
	var l := loc(s.id)
	return int(s.lines) * l.line_profit_per_day * (100 + profit_bonus_percent(s)) / 100 * int(s.market) / 100


## Daily costs of a site once built: upkeep and the head's wage.
func daily_cost(s: Dictionary) -> int:
	if s.status != READY and s.status != BUILDING:
		return 0
	var l := loc(s.id)
	var cost := l.upkeep_per_day * (100 - _exec_sum("upkeep")) / 100 if s.status == READY else 0
	if s.head != "":
		cost += head_wage(l)
	return cost


## Net result per day of everything outside the first factory (executives included).
func daily_net() -> int:
	var total := -exec_wages()
	for s in sim.state.sites:
		total += daily_income(s) - daily_cost(s)
	return total


func tick() -> void:
	for s in sim.state.sites:
		if s.status != SURVEYING and s.status != BUILDING:
			continue
		s.ticks_left = int(s.ticks_left) - 1
		if s.ticks_left > 0:
			continue
		var l := loc(s.id)
		if s.status == SURVEYING:
			s.status = SURVEYED
			s.market = sim.rng.randi_range(85, 125)
			sim.emit_event(&"expansion_changed", {"id": s.id})
			sim.emit_event(&"site_surveyed", {"id": s.id, "market": s.market})
		else:
			s.status = READY
			sim.emit_event(&"expansion_changed", {"id": s.id})
			sim.emit_event(&"site_opened", {"id": s.id, "name": l.display_name})


## Books the day's income and costs of every site and the executives' wages.
func end_of_day() -> void:
	for s in sim.state.sites:
		var l := loc(s.id)
		var income := daily_income(s)
		if income > 0:
			sim.economy.book("branch_income", income, l.display_name)
			sim.economy.add_stat("branch_income", income)
		var cost := daily_cost(s)
		if cost > 0:
			sim.economy.book("branch_cost", -cost, l.display_name)
			sim.economy.add_stat("branch_costs", cost)
	var wages := exec_wages()
	if wages > 0:
		sim.economy.book("executives", -wages, "Ban lãnh đạo")
		sim.economy.add_stat("exec_wages", wages)
