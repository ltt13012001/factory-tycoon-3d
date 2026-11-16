## Diamonds: senior managers, boosts and other uses, rewarded-ad limits,
## in-app purchase crediting, daily quests and achievements, saves.
extends TestCase


func test_start_and_spend() -> void:
	var sim := new_sim()
	check_eq(sim.diamonds.balance(), DiamondManager.START_DIAMONDS, "new game starts with diamonds")
	check(not sim.diamonds.spend(1000, "x"), "cannot overspend")
	check(sim.diamonds.spend(5, "x"), "spend works")
	check_eq(sim.diamonds.balance(), DiamondManager.START_DIAMONDS - 5, "balance down")


func test_senior_managers() -> void:
	var sim := new_sim()
	var lot := sim.inventory.lot_cost(100)
	var raw_cap := sim.buildings.raw_capacity()
	var cycle := sim.production.cycle_ticks(sim.state.machines[0])
	check(not sim.recruit_senior("productivity_expert").ok, "too few diamonds")
	sim.diamonds.earn(5000, "gift")
	check(sim.recruit_senior("purchasing_head").ok, "recruit purchasing head")
	check(sim.diamonds.senior_name("purchasing_head") != "", "has a name")
	check(sim.inventory.lot_cost(100) < lot, "material cheaper")
	check(sim.recruit_senior("logistics_head").ok, "recruit logistics")
	check_eq(sim.buildings.raw_capacity(), raw_cap * 115 / 100, "store 15% bigger")
	check(sim.recruit_senior("productivity_expert").ok, "recruit productivity")
	check(sim.production.cycle_ticks(sim.state.machines[0]) < cycle, "machines faster")
	check_eq(sim.expansion.order_price_percent(), 100, "no negotiator yet")
	check(sim.recruit_senior("negotiator").ok, "recruit negotiator")
	check_eq(sim.expansion.order_price_percent(), 106, "prices +6%")
	var mood := sim.employees.mood_target(sim.state.employees[0])
	check(sim.recruit_senior("people_coach").ok, "recruit coach")
	check_eq(sim.employees.mood_target(sim.state.employees[0]), mini(100, mood + 6), "mood target +6")
	var before := sim.diamonds.balance()
	check(sim.recruit_senior("negotiator").ok, "level 2")
	check(sim.recruit_senior("negotiator").ok, "level 3")
	check(not sim.recruit_senior("negotiator").ok, "max level 3")
	check_eq(sim.expansion.order_price_percent(), 118, "prices +18% at level 3")
	check_eq(before - sim.diamonds.balance(), 300 + 650, "level costs paid")
	check(not sim.recruit_senior("nobody").ok, "unknown id rejected")


func test_engineer_slows_wear() -> void:
	var a := new_sim(7)
	var b := new_sim(7)
	b.diamonds.earn(1000, "gift")
	for i in 3:
		b.recruit_senior("chief_engineer")
	for s in [a, b]:
		s.buy_material(500)
		s.advance_ticks(days(s, 3))
	check(int(b.state.machines[0].condition) > int(a.state.machines[0].condition), "engineer keeps the machine in better shape")


func test_boost() -> void:
	var sim := new_sim()
	var m: Dictionary = sim.state.machines[0]
	var cycle := sim.production.cycle_ticks(m)
	check(sim.buy_boost().ok, "buy boost")
	check_eq(sim.diamonds.balance(), DiamondManager.START_DIAMONDS - DiamondManager.BOOST_DIAMOND_COST, "paid")
	check(sim.production.cycle_ticks(m) < cycle, "faster while boosted")
	sim.advance_ticks(hours(sim, DiamondManager.BOOST_DIAMOND_HOURS) - 1)
	check(sim.diamonds.boost_ticks_left() > 0, "still running")
	sim.advance_ticks(1)
	check_eq(sim.diamonds.boost_ticks_left(), 0, "ended on time")
	check_eq(sim.production.cycle_ticks(m), cycle, "back to normal")


func test_repair_party_rush_exchange() -> void:
	var sim := new_sim()
	sim.diamonds.earn(500, "gift")
	var m: Dictionary = sim.state.machines[0]
	m.broken = true
	m.condition = 0
	check(sim.instant_repair(m.id).ok, "instant repair")
	check(not m.broken and int(m.condition) == 100, "machine fixed at once")
	check(not sim.instant_repair(m.id).ok, "nothing to repair")
	sim.state.strike = {"since_tick": sim.state.tick}
	for e in sim.state.employees:
		e.mood = 10
	check(sim.staff_party().ok, "party")
	check(not sim.employees.on_strike(), "strike over")
	check_eq(int(sim.state.employees[0].mood), 35, "mood up")
	sim.economy.book("sales", 10000000, "test money")
	check(sim.build("break_room").ok, "start a construction")
	var targets := sim.diamonds.rush_targets()
	check_eq(targets.size(), 1, "one job to rush")
	check(sim.rush("construction", "break_room").ok, "rush it")
	check_eq(sim.buildings.level("break_room"), 1, "built at once")
	check(sim.state.construction.is_empty(), "no construction left")
	var cash := sim.state.cash
	check(sim.exchange_diamonds().ok, "exchange")
	check_eq(sim.state.cash - cash, DiamondManager.EXCHANGE_CENTS[0] * DiamondManager.EXCHANGE_LOT, "cash paid")
	check(sim.economy.ledger_balanced(), "ledger balanced")


func test_ad_limits() -> void:
	var sim := new_sim()
	var day1 := "2026-11-05"
	for i in DiamondManager.AD_DIAMOND_LIMIT:
		check(sim.diamonds.ad_reward("diamonds", day1).ok, "ad %d" % i)
	check(not sim.diamonds.ad_reward("diamonds", day1).ok, "diamond ads capped")
	check_eq(sim.diamonds.balance(), DiamondManager.START_DIAMONDS + DiamondManager.AD_DIAMONDS * DiamondManager.AD_DIAMOND_LIMIT, "rewards credited")
	check(sim.diamonds.ad_reward("boost", day1).ok, "other ads still allowed")
	check(sim.diamonds.ad_reward("diamonds", "2026-11-06").ok, "limit resets the next day")
	sim.advance_ticks(days(sim, 1))
	var r: Dictionary = sim.state.reports[-1]
	var cash := sim.state.cash
	var bonus := sim.diamonds.report_bonus(r)
	check(bonus >= DiamondManager.AD_REPORT_MIN, "report bonus offered")
	check(sim.diamonds.ad_reward("report", "2026-11-06", r).ok, "report bonus")
	check_eq(sim.state.cash - cash, bonus, "bonus paid")
	check(not sim.diamonds.ad_reward("report", "2026-11-06", r).ok, "only once per day report")
	check(sim.economy.ledger_balanced(), "ledger balanced")
	var total := 0
	for i in 50:
		if sim.diamonds.ad_reward("boost", "2026-11-07").ok:
			total += 1
	check_eq(total, DiamondManager.AD_DAILY_LIMIT, "daily cap on all ads")


func test_purchase_credited_once() -> void:
	var sim := new_sim()
	var r := sim.diamonds.credit_purchase("diamonds_medium", "T1")
	check(r.ok, "credited")
	check_eq(sim.diamonds.balance(), DiamondManager.START_DIAMONDS + 330, "300 + 30 bonus")
	sim.diamonds.credit_purchase("diamonds_medium", "T1")
	check_eq(sim.diamonds.balance(), DiamondManager.START_DIAMONDS + 330, "same transaction not credited twice")
	check(not sim.diamonds.credit_purchase("free_money", "T2").ok, "unknown product refused")
	check_eq(MonetizationConfig.pack_id(MonetizationConfig.product_id("diamonds_small")), "diamonds_small", "product id round trip")


func test_daily_quests() -> void:
	var sim := new_sim()
	var list := sim.quests.daily()
	check_eq(list.size(), QuestManager.DAILY_COUNT, "three quests on day 1")
	check(not sim.claim_daily_quest(0).ok, "cannot claim unfinished")
	for d in list:
		d.progress = d.target
	var before := sim.diamonds.balance()
	var expected := 0
	for i in list.size():
		expected += sim.quests.daily_reward(list[i])
		check(sim.claim_daily_quest(i).ok, "claim %d" % i)
	check_eq(sim.diamonds.balance() - before, expected + QuestManager.DAILY_ALL_BONUS, "rewards and all-day bonus")
	check(not sim.claim_daily_quest(0).ok, "no double claim")
	sim.advance_ticks(days(sim, 1))
	check_eq(int(sim.state.quests.day), 2, "new quests next day")
	check(not sim.quests.daily()[0].claimed, "fresh quests")
	# Same world, same day -> same quests.
	var other := new_sim()
	other.advance_ticks(days(other, 1))
	check_eq(str(other.quests.daily()), str(sim.quests.daily()), "deterministic")


func test_quest_progress_from_play() -> void:
	var sim := new_sim()
	sim.state.quests.daily = [{"kind": "produce", "target": 5, "progress": 0, "claimed": false},
		{"kind": "buy_material", "target": 1, "progress": 0, "claimed": false}]
	sim.buy_material(100)
	sim.advance_ticks(hours(sim, 3))
	check(sim.quests.daily_done(sim.quests.daily()[0]), "production counted")
	check(sim.quests.daily_done(sim.quests.daily()[1]), "material order counted")
	check(sim.quests.claimable() >= 2, "badge counts them")


func test_milestones() -> void:
	var sim := new_sim()
	check(not sim.claim_milestone("first_order").ok, "not yet")
	sim.state.quests.shipped = 1
	check(sim.claim_milestone("first_order").ok, "first order claimed")
	check(not sim.claim_milestone("first_order").ok, "once only")
	sim.state.company_tier = 2
	check(sim.quests.milestone_met("tier_1") and sim.quests.milestone_met("tier_2"), "tiers met")
	check(not sim.quests.milestone_met("tier_3"), "tier 3 not met")


func test_save_and_migrate() -> void:
	var sim := new_sim()
	sim.diamonds.earn(200, "gift")
	sim.recruit_senior("negotiator")
	sim.buy_boost()
	var b := blank_sim()
	check(b.load_json(sim.to_json()), "loads")
	check_eq(b.diamonds.balance(), sim.diamonds.balance(), "diamonds kept")
	check_eq(b.diamonds.senior_level("negotiator"), 1, "senior kept")
	check_eq(b.diamonds.boost_ticks_left(), sim.diamonds.boost_ticks_left(), "boost kept")
	var d := sim.to_save_dict()
	d.save_version = 6
	for f in ["diamonds", "diamond_stats", "seniors", "quests", "boost", "ads", "iap_log"]:
		d.erase(f)
	var c := blank_sim()
	check(c.load_save_dict(d), "v6 save loads")
	check_eq(c.diamonds.balance(), DiamondManager.START_DIAMONDS, "old players get the starting diamonds")
	check_eq(c.quests.daily().size(), QuestManager.DAILY_COUNT, "quests made on load")
	c.advance_ticks(days(c, 1))
	check(c.state.reports[-1].ledger_ok, "runs a day after migration")
