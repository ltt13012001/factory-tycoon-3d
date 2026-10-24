## Buy machines (placed on a free slot) and start construction projects.
extends SidePanel


func _init() -> void:
	title = "Xây dựng"


func signature(sim: Simulation) -> String:
	return str([sim.state.machines.size(), sim.state.cash / 1000, sim.day(), sim.state.reputation,
		sim.state.buildings, sim.state.construction.get("id", ""), int(sim.state.construction.get("ticks_left", 0)) / 15,
		sim.employees.count(EmployeeManager.OPERATOR)])


func build(b: VBoxContainer, sim: Simulation) -> void:
	var cfg := sim.config
	var used := sim.state.machines.size()
	var slots := sim.buildings.machine_slots()
	b.add_child(UiTheme.label("Máy móc", 18, UiTheme.WARN, true))
	row(b, "Ô đặt máy trong xưởng", "%d / %d" % [used, slots])
	_staff_hint(b, sim)
	for d in sim.content.machine_list():
		_machine_card(b, sim, d, used >= slots)
	b.add_child(HSeparator.new())
	b.add_child(UiTheme.label("Công trình", 18, UiTheme.WARN, true))
	var c: Dictionary = sim.state.construction
	if not c.is_empty():
		var cd: ConstructionDef = sim.content.constructions[c.id]
		var cc := card(b)
		cc.add_child(UiTheme.label("Đang xây: " + cd.display_name, 16, UiTheme.TEXT, true))
		cc.add_child(UiTheme.bar(float(c.total_ticks - c.ticks_left), float(c.total_ticks), UiTheme.WARN, 12))
		row(cc, "Còn lại", "%.1f giờ" % (float(c.ticks_left) / cfg.ticks_per_hour))
	for d in sim.content.construction_list():
		_construction_card(b, sim, d)


func _machine_card(b: VBoxContainer, sim: Simulation, d: MachineDef, full: bool) -> void:
	var cfg := sim.config
	var p: ProductDef = sim.content.products[d.output_product_id]
	var c := card(b)
	var head := HBoxContainer.new()
	var name := UiTheme.label(d.display_name, 16, UiTheme.TEXT, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(UiTheme.label(Fmt.money(d.price), 16, UiTheme.WARN, true))
	c.add_child(head)
	c.add_child(wrap_label(d.description, 13, UiTheme.MUTED))
	var per_day := float(cfg.ticks_per_day) / d.cycle_ticks * (100 - d.defect_percent) / 100.0
	row(c, "Sản phẩm", "%s · %d hạt nhựa / %s" % [p.display_name, p.material_per_unit, p.unit_name])
	row(c, "Sản lượng", "khoảng %.0f %s / ngày" % [per_day, p.unit_name])
	row(c, "Lỗi · điện", "%d%% · %s / chu kỳ" % [d.defect_percent, Fmt.money(d.power_cost_per_cycle)])
	row(c, "Người vận hành", "Không cần (tự động)" if d.operators_required == 0 else "%d người" % d.operators_required)
	var reason := sim.production.unlock_reason(d)
	if reason == "" and full:
		reason = "Xưởng hết chỗ"
	if reason == "" and not sim.economy.can_afford(d.price):
		reason = "Không đủ tiền"
	var btn := UiTheme.button("Chọn chỗ đặt máy" if reason == "" else reason, func(): GameManager.start_placing(d.id), reason != "")
	if reason == "":
		btn.add_theme_color_override("font_color", UiTheme.GOOD)
	buttons(c, [btn])


func _construction_card(b: VBoxContainer, sim: Simulation, d: ConstructionDef) -> void:
	var lvl := sim.buildings.level(d.id)
	var c := card(b)
	var head := HBoxContainer.new()
	var name := UiTheme.label(d.display_name, 16, UiTheme.TEXT, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	if d.level_costs.size() > 1:
		head.add_child(UiTheme.label("Cấp %d / %d" % [lvl, d.level_costs.size()], 14, UiTheme.MUTED))
	elif lvl > 0:
		head.add_child(UiTheme.label("Đã xây", 14, UiTheme.GOOD, true))
	c.add_child(head)
	c.add_child(wrap_label(d.description, 13, UiTheme.MUTED))
	var cost := sim.buildings.next_cost(d.id)
	if cost >= 0:
		row(c, "Chi phí · thời gian", "%s · %d giờ" % [Fmt.money(cost), d.build_hours], UiTheme.WARN)
		var reason := sim.buildings.block_reason(d.id)
		buttons(c, [UiTheme.button("Xây ngay" if reason == "" else reason, func(): GameManager.build(d.id), reason != "")])


func _staff_hint(b: VBoxContainer, sim: Simulation) -> void:
	var idle_machines := 0
	for m in sim.state.machines:
		if m.operator_id == 0 and sim.production.needs_operator(m):
			idle_machines += 1
	if idle_machines > 0:
		b.add_child(wrap_label("%d máy chưa có người vận hành." % idle_machines, 14, UiTheme.WARN))
		buttons(b, [UiTheme.button("Tuyển người vận hành (%s)" % Fmt.money(sim.config.hire_fee),
			func(): GameManager.hire(EmployeeManager.OPERATOR), not sim.economy.can_afford(sim.config.hire_fee))])
