## Cash, the daily ledger, end-of-day costs and the daily report.
class_name EconomyManager
extends RefCounted

const STAT_KEYS := [
	"produced", "defects", "revenue", "material_cost", "power", "wages",
	"rent", "penalties", "interest", "repairs", "orders_delivered", "orders_late",
]

var sim: Simulation


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func reset_day_stats() -> void:
	var stats := {}
	for k in STAT_KEYS:
		stats[k] = 0
	sim.state.day_stats = stats
	sim.state.ledger = []
	sim.state.day_start_cash = sim.state.cash


func can_afford(amount: int) -> bool:
	return sim.state.cash - amount >= sim.config.overdraft_limit


## Every change of cash goes through here so the ledger always matches.
func book(category: String, amount: int, note: String = "") -> void:
	var s := sim.state
	s.cash += amount
	s.ledger.append({"tick": s.tick, "category": category, "amount": amount, "note": note})
	sim.emit_event(&"cash_changed", {"cash": s.cash, "amount": amount, "category": category})


func add_stat(key: String, amount: int) -> void:
	sim.state.day_stats[key] = int(sim.state.day_stats.get(key, 0)) + amount


func ledger_sum() -> int:
	var total := 0
	for e in sim.state.ledger:
		total += int(e.amount)
	return total


func ledger_balanced() -> bool:
	return sim.state.day_start_cash + ledger_sum() == sim.state.cash


func end_of_day(day_number: int) -> Dictionary:
	var s := sim.state
	var cfg := sim.config
	var wages := s.employees.size() * cfg.wage_per_day
	if wages > 0:
		book("wages", -wages, "%d nhân viên" % s.employees.size())
		add_stat("wages", wages)
	book("rent", -cfg.rent_per_day, "Thuê đất")
	add_stat("rent", cfg.rent_per_day)
	if s.power_accrued > 0:
		book("power", -s.power_accrued, "Tiền điện")
		add_stat("power", s.power_accrued)
		s.power_accrued = 0
	if s.cash < 0:
		var interest := ceili(-s.cash * cfg.overdraft_interest_percent / 100.0)
		book("interest", -interest, "Lãi thấu chi")
		add_stat("interest", interest)

	var income := 0
	var expense := 0
	for e in s.ledger:
		if e.amount > 0:
			income += int(e.amount)
		else:
			expense -= int(e.amount)
	var st := s.day_stats
	var profit: int = st.revenue - st.material_cost - st.power - st.wages - st.rent - st.penalties - st.interest - int(st.get("repairs", 0))
	var report := {
		"day": day_number,
		"start_cash": s.day_start_cash,
		"end_cash": s.cash,
		"income": income,
		"expense": expense,
		"profit": profit,
		"reputation": s.reputation,
		"ledger_ok": ledger_balanced(),
		"stats": st.duplicate(),
		"critical": s.cash < cfg.overdraft_limit,
	}
	s.reports.append(report)
	while s.reports.size() > 30:
		s.reports.pop_front()
	reset_day_stats()
	return report
