## Growing the business: company stage, production line speed, executives,
## new factories next door and branches in other provinces and abroad.
extends SidePanel


func _init() -> void:
	title = "Mở rộng doanh nghiệp"


func signature(sim: Simulation) -> String:
	var parts := [sim.state.cash / 1000, sim.state.company_tier, sim.state.line_speed_level,
		sim.state.executives, sim.employees.count(EmployeeManager.MANAGER), sim.state.machines.size(), sim.buildings.machine_slots()]
	for s in sim.state.sites:
		parts.append("%s%s%d%d%s%d" % [s.id, s.status, s.lines, s.automation, s.head, int(s.ticks_left) / 30])
	return str(parts)


func build(b: VBoxContainer, sim: Simulation) -> void:
	var ex := sim.expansion
	_company_card(b, sim)
	_speed_card(b, sim)

	b.add_child(HSeparator.new())
	b.add_child(UiTheme.label("Ban lãnh đạo", 18, UiTheme.WARN, true))
	for id in ExpansionManager.EXECUTIVE_ORDER:
		_executive_card(b, sim, id)

	for region in [ExpansionManager.LOCAL, ExpansionManager.DOMESTIC, ExpansionManager.ABROAD]:
		b.add_child(HSeparator.new())
		b.add_child(UiTheme.label(ExpansionManager.REGION_NAMES[region], 18, UiTheme.WARN, true))
		match region:
			ExpansionManager.LOCAL:
				b.add_child(wrap_label("Đặt đủ máy trong xưởng thì mua được lô đất bên cạnh để xây thêm nhà xưởng. Mỗi xưởng cần một xưởng trưởng mới chạy được."))
			ExpansionManager.DOMESTIC:
				b.add_child(wrap_label("Mở khi đã là %s. Khảo sát trước để biết sức mua của thị trường, rồi mở chi nhánh." % ExpansionManager.TIER_NAMES[1]))
			ExpansionManager.ABROAD:
				b.add_child(wrap_label("Mở khi đã là %s. Lãi cao hơn nhưng vốn lớn." % ExpansionManager.TIER_NAMES[2]))
		for l in sim.content.location_list(region):
			_site_card(b, sim, l)
	if ex.tier() >= ExpansionManager.TIER_NAMES.size() - 1:
		b.add_child(wrap_label("Bạn đã xây dựng một tập đoàn đa quốc gia. Tiếp tục mở rộng và bổ nhiệm lãnh đạo để tăng lợi nhuận!", 14, UiTheme.GOOD))


func _company_card(b: VBoxContainer, sim: Simulation) -> void:
	var ex := sim.expansion
	var c := card(b)
	c.add_child(UiTheme.label(ex.tier_name(), 20, UiTheme.GOOD, true))
	row(c, "Chức danh của bạn", ex.owner_title())
	row(c, "Nhà xưởng đang chạy", "%d" % ex.factories_operating())
	var net := ex.daily_net()
	if not sim.state.sites.is_empty() or not sim.state.executives.is_empty():
		row(c, "Lãi ròng ngoài xưởng chính", "%s / ngày" % Fmt.money(net), UiTheme.GOOD if net >= 0 else UiTheme.BAD)
	var req := ex.next_tier_requirement()
	if req.text == "":
		return
	var next: String = ExpansionManager.TIER_NAMES[ex.tier() + 1]
	c.add_child(UiTheme.label("Bước tiếp theo: " + next, 15, UiTheme.TEXT, true))
	c.add_child(wrap_label(("✓ " if req.met else "· ") + req.text, 13, UiTheme.GOOD if req.met else UiTheme.MUTED))
	row(c, "Phí đăng ký", Fmt.money(req.fee), UiTheme.WARN)
	var ok: bool = req.met and sim.economy.can_afford(req.fee)
	var btn := UiTheme.button("Thành lập " + next if ok else ("Chưa đủ điều kiện" if not req.met else "Không đủ tiền"), func(): GameManager.advance_tier(), not ok)
	if ok:
		btn.add_theme_color_override("font_color", UiTheme.GOOD)
	buttons(c, [btn])


func _speed_card(b: VBoxContainer, sim: Simulation) -> void:
	var ex := sim.expansion
	var c := card(b)
	c.add_child(UiTheme.label("Tốc độ sản xuất (xưởng chính)", 16, UiTheme.TEXT, true))
	row(c, "Máy chạy nhanh hơn", "+%d%%" % ex.speed_bonus_percent(), UiTheme.GOOD)
	row(c, "Cải tiến dây chuyền", "cấp %d / %d (+%d%% mỗi cấp)" % [ex.line_speed_level(), ExpansionManager.LINE_SPEED_COSTS.size(), ExpansionManager.LINE_SPEED_PERCENT])
	var has_manager := sim.employees.count(EmployeeManager.MANAGER) > 0
	row(c, "Xưởng trưởng", "có (+%d%%)" % ExpansionManager.MANAGER_SPEED_PERCENT if has_manager else "chưa có", UiTheme.GOOD if has_manager else UiTheme.WARN)
	c.add_child(wrap_label("Nâng cấp từng máy (bấm vào máy) cũng làm máy nhanh hơn, tối đa cấp 5."))
	var items := []
	var cost := ex.line_speed_cost()
	if cost >= 0:
		items.append(UiTheme.button("Cải tiến (%s)" % Fmt.money(cost), func(): GameManager.upgrade_line_speed(), not sim.economy.can_afford(cost)))
	if not has_manager:
		items.append(UiTheme.button("Tuyển xưởng trưởng", func(): GameManager.hire(EmployeeManager.MANAGER), not sim.economy.can_afford(sim.config.hire_fee)))
	if not items.is_empty():
		buttons(c, items)


func _executive_card(b: VBoxContainer, sim: Simulation, id: String) -> void:
	var ex := sim.expansion
	var e: Dictionary = ExpansionManager.EXECUTIVES[id]
	var c := card(b)
	var head := HBoxContainer.new()
	var name := UiTheme.label(e.name, 15, UiTheme.TEXT, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(UiTheme.label("%s / ngày" % Fmt.money(e.wage), 13, UiTheme.MUTED))
	c.add_child(head)
	c.add_child(wrap_label(e.text))
	if ex.has_exec(id):
		var h := HBoxContainer.new()
		var who := UiTheme.label("Đang giữ chức: " + str(sim.state.executives[id]), 14, UiTheme.GOOD)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(who)
		h.add_child(UiTheme.button("Cho thôi", func(): GameManager.fire_executive(id)))
		c.add_child(h)
	elif ex.tier() < int(e.tier):
		c.add_child(UiTheme.label("Mở khi thành " + ExpansionManager.TIER_NAMES[e.tier], 13, UiTheme.MUTED))
	else:
		var fee := ex.exec_hire_fee(id)
		buttons(c, [UiTheme.button("Bổ nhiệm (%s)" % Fmt.money(fee), func(): GameManager.hire_executive(id), not sim.economy.can_afford(fee))])


func _site_card(b: VBoxContainer, sim: Simulation, l: LocationDef) -> void:
	var ex := sim.expansion
	var s := ex.site(l.id)
	var c := card(b)
	var head := HBoxContainer.new()
	var name := UiTheme.label(l.display_name, 16, UiTheme.TEXT, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	if l.region == ExpansionManager.ABROAD:
		head.add_child(UiTheme.label(l.country, 13, UiTheme.MUTED))
	if FactoryLayout.PLOTS.has(l.id):
		head.add_child(UiTheme.button("Xem", func(): EventBus.camera_focus_requested.emit(FactoryLayout.PLOTS[l.id], 34.0)))
	c.add_child(head)
	var status: String = "" if s.is_empty() else s.status
	if status != ExpansionManager.READY:
		c.add_child(wrap_label(l.description))
	if status == ExpansionManager.SURVEYING or status == ExpansionManager.BUILDING:
		c.add_child(UiTheme.label("Đang khảo sát" if status == ExpansionManager.SURVEYING else "Đang xây dựng", 14, UiTheme.WARN))
		c.add_child(UiTheme.bar(float(s.total_ticks - s.ticks_left), float(s.total_ticks), UiTheme.WARN, 12))
		row(c, "Còn lại", "%.1f giờ" % (float(s.ticks_left) / sim.config.ticks_per_hour))
		if status == ExpansionManager.BUILDING:
			_head_row(c, sim, l, s)
		return
	if status == ExpansionManager.READY:
		_ready_site(c, sim, l, s)
		return
	# Not started, land bought, or surveyed: show the next step.
	if status == ExpansionManager.SURVEYED:
		row(c, "Sức mua thị trường", "%d%%" % s.market, UiTheme.GOOD if int(s.market) >= 100 else UiTheme.WARN)
	if l.region == ExpansionManager.LOCAL:
		if status == "":
			row(c, "Giá đất", Fmt.money(l.land_cost))
		row(c, "Xây nhà xưởng", "%s · %d giờ" % [Fmt.money(l.build_cost), l.build_hours])
	else:
		if status == "":
			row(c, "Khảo sát", "%s · %d giờ" % [Fmt.money(l.survey_cost), ex.survey_hours(l)])
		row(c, "Vốn mở chi nhánh", "%s · %d giờ" % [Fmt.money(l.land_cost + l.build_cost), l.build_hours])
	var market := 100 if status != ExpansionManager.SURVEYED else int(s.market)
	var known := status == ExpansionManager.SURVEYED or l.region == ExpansionManager.LOCAL
	row(c, "Lãi mỗi dây chuyền", ("~%s / ngày" % Fmt.money(l.line_profit_per_day * market / 100)) if known else "? (cần khảo sát)")
	row(c, "Dây chuyền tối đa · giá", "%d · %s" % [l.max_lines, Fmt.money(l.line_cost)])
	var label := ""
	match status:
		"":
			label = "Mua đất" if l.region == ExpansionManager.LOCAL else "Khảo sát"
		ExpansionManager.LAND:
			label = "Xây nhà xưởng"
		ExpansionManager.SURVEYED:
			label = "Mở chi nhánh"
	var reason := ex.block_reason(l.id)
	var cost := ex.next_step_cost(l.id)
	var btn := UiTheme.button("%s (%s)" % [label, Fmt.money(cost)] if reason == "" else reason, func(): GameManager.expand(l.id), reason != "")
	if reason == "":
		btn.add_theme_color_override("font_color", UiTheme.GOOD)
	buttons(c, [btn])


func _ready_site(c: VBoxContainer, sim: Simulation, l: LocationDef, s: Dictionary) -> void:
	var ex := sim.expansion
	row(c, "Dây chuyền", "%d / %d" % [s.lines, l.max_lines])
	row(c, "Tự động hoá", "cấp %d / %d" % [s.automation, ExpansionManager.MAX_AUTOMATION])
	if l.region != ExpansionManager.LOCAL:
		row(c, "Sức mua thị trường", "%d%%" % s.market)
	_head_row(c, sim, l, s)
	var income := ex.daily_income(s)
	var cost := ex.daily_cost(s)
	row(c, "Thu · chi mỗi ngày", "+%s · -%s" % [Fmt.money(income), Fmt.money(cost)], UiTheme.GOOD if income >= cost else UiTheme.WARN)
	var items := []
	if int(s.lines) < l.max_lines:
		items.append(UiTheme.button("+ Dây chuyền (%s)" % Fmt.money(l.line_cost), func(): GameManager.buy_line(l.id), not sim.economy.can_afford(l.line_cost)))
	var auto := ex.automation_cost(s)
	if auto >= 0:
		items.append(UiTheme.button("Tự động hoá (%s)" % Fmt.money(auto), func(): GameManager.automate_site(l.id), not sim.economy.can_afford(auto)))
	if not items.is_empty():
		var h := buttons(c, items)
		h.add_theme_constant_override("separation", 4)


## The site's factory manager / branch director: hire or let go.
func _head_row(c: VBoxContainer, sim: Simulation, l: LocationDef, s: Dictionary) -> void:
	var ex := sim.expansion
	var title := ex.head_title(l)
	if s.head != "":
		var h := HBoxContainer.new()
		var who := UiTheme.label("%s: %s" % [title, s.head], 14, UiTheme.GOOD)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(who)
		h.add_child(UiTheme.button("Cho nghỉ", func(): GameManager.fire_site_head(l.id)))
		c.add_child(h)
		return
	c.add_child(wrap_label("Chưa có %s: xưởng chưa thể sản xuất. Lương %s / ngày." % [title.to_lower(), Fmt.money(ex.head_wage(l))], 13, UiTheme.BAD))
	var fee := ex.head_hire_fee(l)
	var btn := UiTheme.button("+ Tuyển %s (%s)" % [title.to_lower(), Fmt.money(fee)], func(): GameManager.hire_site_head(l.id), not sim.economy.can_afford(fee))
	btn.add_theme_color_override("font_color", UiTheme.GOOD)
	buttons(c, [btn])
