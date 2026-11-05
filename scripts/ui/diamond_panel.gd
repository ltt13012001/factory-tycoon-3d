## Diamonds: free diamonds from ads, the shop, senior managers and the
## things diamonds buy (production boost, staff party, finishing work now,
## exchange for cash).
class_name DiamondPanel
extends SidePanel


func _init() -> void:
	title = "Kim cương"


func _ready() -> void:
	super._ready()
	Monetization.changed.connect(refresh)


func signature(sim: Simulation) -> String:
	var rush := []
	for t in sim.diamonds.rush_targets():
		rush.append([t.id, sim.diamonds.rush_cost(t.ticks_left)])
	return str([sim.diamonds.balance(), sim.state.seniors, sim.state.ads, sim.diamonds.boost_ticks_left() / sim.config.ticks_per_hour,
		rush, sim.expansion.tier(), sim.employees.on_strike(), Monetization.wait_reason(), Monetization.today()])


func build(b: VBoxContainer, sim: Simulation) -> void:
	var dm := sim.diamonds
	var top := HBoxContainer.new()
	var l := UiTheme.label("Kim cương đang có", 15, UiTheme.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(l)
	top.add_child(UiTheme.diamond_amount(dm.balance(), 20))
	b.add_child(top)
	_free_card(b, sim)
	_shop_card(b, sim)
	b.add_child(HSeparator.new())
	_seniors(b, sim)
	b.add_child(HSeparator.new())
	_uses(b, sim)


## Quests and the opt-in ad for diamonds.
func _free_card(b: VBoxContainer, sim: Simulation) -> void:
	b.add_child(UiTheme.label("Nhận kim cương miễn phí", 18, UiTheme.WARN, true))
	var c := card(b)
	var n := sim.quests.claimable()
	var quests := UiTheme.button("Nhiệm vụ và thành tựu%s" % (" (%d phần thưởng chờ nhận)" % n if n > 0 else ""), func(): EventBus.panel_requested.emit("quests"))
	if n > 0:
		quests.add_theme_color_override("font_color", UiTheme.GOOD)
	c.add_child(quests)
	if not Monetization.ads_available():
		return
	var today := Monetization.today()
	var left := sim.diamonds.ad_diamonds_left(today)
	var wait := Monetization.wait_reason()
	var text := "Xem quảng cáo: +%d kim cương" % DiamondManager.AD_DIAMONDS
	var btn := UiTheme.diamond_button(text if wait == "" else wait, func(): Monetization.watch("diamonds"), left <= 0 or wait != "")
	c.add_child(btn)
	c.add_child(wrap_label("Còn %d lượt hôm nay. Chỉ xem khi bạn muốn, game không tự bật quảng cáo.%s" % [left, (" (Đây là %s.)" % Monetization.ads.label) if Monetization.ads.label != "" else ""]))


func _shop_card(b: VBoxContainer, _sim: Simulation) -> void:
	b.add_child(UiTheme.label("Nạp kim cương", 18, UiTheme.WARN, true))
	if not Monetization.store_available():
		b.add_child(wrap_label("Nạp kim cương có trên bản iPhone, iPad và Android (thanh toán qua App Store / Google Play)."))
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	b.add_child(grid)
	for p in DiamondManager.PACKS:
		var pc := PanelContainer.new()
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pc.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.BG_LIGHT, 8, 10))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		pc.add_child(v)
		var amt := UiTheme.diamond_amount(int(p.diamonds) + int(p.bonus), 18)
		amt.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(amt)
		var bonus := UiTheme.label(("tặng thêm %d" % p.bonus) if int(p.bonus) > 0 else " ", 13, UiTheme.GOOD)
		bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(bonus)
		var id: String = p.id
		v.add_child(UiTheme.button(Monetization.price_text(id), func(): Monetization.buy(id)))
		grid.add_child(pc)
	b.add_child(wrap_label("Thanh toán qua %s. Kim cương đã nạp được giữ lại cả khi chơi lại từ đầu." % ("App Store" if OS.has_feature("ios") else ("Google Play" if OS.has_feature("android") else "cửa hàng ứng dụng"))))


func _seniors(b: VBoxContainer, sim: Simulation) -> void:
	var dm := sim.diamonds
	b.add_child(UiTheme.label("Quản lý cấp cao", 18, UiTheme.WARN, true))
	b.add_child(wrap_label("Chiêu mộ bằng kim cương, làm việc mãi mãi và không nhận lương. Mỗi người lên được %d cấp." % 3))
	for id in DiamondManager.SENIOR_ORDER:
		var s: Dictionary = DiamondManager.SENIORS[id]
		var lvl := dm.senior_level(id)
		var c := card(b)
		var h := HBoxContainer.new()
		var name := UiTheme.label(s.name, 15, UiTheme.TEXT, true)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_child(name)
		h.add_child(UiTheme.label(("%s · cấp %d/3" % [dm.senior_name(id), lvl]) if lvl > 0 else "chưa có", 13, UiTheme.GOOD if lvl > 0 else UiTheme.MUTED))
		c.add_child(h)
		var text := dm.senior_text(id) if lvl > 0 else dm.senior_text(id, 1)
		c.add_child(wrap_label(("Đang: " if lvl > 0 else "") + text, 13, UiTheme.TEXT if lvl > 0 else UiTheme.MUTED))
		var cost := dm.senior_cost(id)
		if cost >= 0:
			var label := ("Chiêu mộ · %d" if lvl == 0 else "Lên cấp %d · %%d" % (lvl + 1)) % cost
			var btn := UiTheme.diamond_button(label, func(): GameManager.recruit_senior(id), not dm.can_spend(cost))
			if lvl > 0:
				btn.tooltip_text = "Cấp %d: %s" % [lvl + 1, dm.senior_text(id, lvl + 1)]
			c.add_child(btn)


func _uses(b: VBoxContainer, sim: Simulation) -> void:
	var dm := sim.diamonds
	b.add_child(UiTheme.label("Dùng kim cương", 18, UiTheme.WARN, true))
	# Production boost
	var c := card(b)
	c.add_child(UiTheme.label("Tăng tốc sản xuất +%d%%" % DiamondManager.BOOST_PERCENT, 15, UiTheme.TEXT, true))
	var left := dm.boost_ticks_left()
	if left > 0:
		c.add_child(UiTheme.label("Đang chạy, còn %s" % _hours(sim, left), 13, UiTheme.GOOD))
	c.add_child(wrap_label("Mọi máy ở mọi nhà xưởng chạy nhanh hơn. Mua thêm thì cộng dồn thời gian."))
	var row_btns: Array = [UiTheme.diamond_button("%d giờ · %d" % [DiamondManager.BOOST_DIAMOND_HOURS, DiamondManager.BOOST_DIAMOND_COST], func(): GameManager.buy_boost(), not dm.can_spend(DiamondManager.BOOST_DIAMOND_COST))]
	if Monetization.can_watch("boost"):
		var wait := Monetization.wait_reason()
		row_btns.append(UiTheme.button("Xem QC: %d giờ" % DiamondManager.BOOST_AD_HOURS if wait == "" else wait, func(): Monetization.watch("boost"), wait != ""))
	buttons(c, row_btns)
	# Finish now
	var targets := dm.rush_targets()
	if not targets.is_empty():
		c = card(b)
		c.add_child(UiTheme.label("Hoàn thành ngay", 15, UiTheme.TEXT, true))
		for t in targets:
			var cost := dm.rush_cost(t.ticks_left)
			var h := HBoxContainer.new()
			var lab := UiTheme.label("%s (còn %s)" % [t.name, _hours(sim, t.ticks_left)], 13, UiTheme.MUTED)
			lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(lab)
			var kind: String = t.kind
			var id: String = t.id
			h.add_child(UiTheme.diamond_button("%d" % cost, func(): GameManager.rush(kind, id), not dm.can_spend(cost)))
			c.add_child(h)
	# Staff party
	c = card(b)
	c.add_child(UiTheme.label("Liên hoan nhân viên", 15, UiTheme.TEXT, true))
	c.add_child(wrap_label("Tâm trạng mọi người +%d%s." % [DiamondManager.PARTY_MOOD, ", chấm dứt đình công ngay" if sim.employees.on_strike() else ", chấm dứt đình công nếu đang có"]))
	buttons(c, [UiTheme.diamond_button("Tổ chức · %d" % DiamondManager.PARTY_COST, func(): GameManager.staff_party(), not dm.can_spend(DiamondManager.PARTY_COST))])
	# Exchange
	c = card(b)
	c.add_child(UiTheme.label("Đổi kim cương lấy tiền", 15, UiTheme.TEXT, true))
	c.add_child(wrap_label("%d kim cương = %s (tỉ giá tăng theo quy mô công ty)." % [DiamondManager.EXCHANGE_LOT, Fmt.money(dm.exchange_rate() * DiamondManager.EXCHANGE_LOT)]))
	buttons(c, [UiTheme.diamond_button("Đổi · %d" % DiamondManager.EXCHANGE_LOT, func(): GameManager.exchange_diamonds(), not dm.can_spend(DiamondManager.EXCHANGE_LOT))])
	b.add_child(wrap_label("Máy hỏng: bấm vào máy để sửa ngay bằng %d kim cương." % DiamondManager.REPAIR_COST))


static func _hours(sim: Simulation, ticks: int) -> String:
	var h := ceili(float(ticks) / sim.config.ticks_per_hour)
	return "%d giờ" % h
