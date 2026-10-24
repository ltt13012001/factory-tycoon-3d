## Buy machines and place them on a free slot in the hall.
extends SidePanel


func _init() -> void:
	title = "Xây dựng"


func signature(sim: Simulation) -> String:
	return str([sim.state.machines.size(), sim.state.cash, sim.employees.count(EmployeeManager.OPERATOR)])


func build(b: VBoxContainer, sim: Simulation) -> void:
	var cfg := sim.config
	var used := sim.state.machines.size()
	row(b, "Ô đặt máy trong xưởng", "%d / %d" % [used, cfg.machine_slots])
	for id in sim.content.machines:
		var d: MachineDef = sim.content.machines[id]
		var c := card(b)
		c.add_child(UiTheme.label(d.display_name, 16, UiTheme.TEXT, true))
		row(c, "Giá", Fmt.money(d.price), UiTheme.WARN)
		var per_hour := float(cfg.ticks_per_hour) / d.cycle_ticks * (100 - d.defect_percent) / 100.0
		row(c, "Chu kỳ", "%.0f giây thật, 1 hạt nhựa ra 1 hộp" % (d.cycle_ticks * cfg.tick_seconds))
		row(c, "Sản lượng", "khoảng %.0f hộp đạt chuẩn / ngày" % (per_hour * 24))
		row(c, "Tỉ lệ lỗi", "%d%%" % d.defect_percent)
		row(c, "Tiền điện", "%s / chu kỳ" % Fmt.money(d.power_cost_per_cycle))
		row(c, "Bán lại", "%d%% giá mua" % d.resale_percent)
		c.add_child(wrap_label("Mỗi máy cần %d người vận hành. Máy không có người sẽ đứng yên." % d.operators_required))
		var reason := ""
		if used >= cfg.machine_slots:
			reason = "Xưởng đã hết chỗ"
		elif not sim.economy.can_afford(d.price):
			reason = "Không đủ tiền"
		buttons(c, [UiTheme.button("Chọn chỗ đặt máy" if reason == "" else reason,
			func(): EventBus.build_mode_changed.emit(true), reason != "")])
	var free_ops := 0
	for e in sim.state.employees:
		if e.role == EmployeeManager.OPERATOR and e.machine_id == 0:
			free_ops += 1
	var idle_machines := 0
	for m in sim.state.machines:
		if m.operator_id == 0:
			idle_machines += 1
	if idle_machines > 0:
		b.add_child(wrap_label("%d máy chưa có người vận hành. Tuyển thêm trong bảng Nhân sự." % idle_machines, 14, UiTheme.WARN))
		buttons(b, [UiTheme.button("Tuyển người vận hành (%s)" % Fmt.money(cfg.hire_fee),
			func(): GameManager.hire(EmployeeManager.OPERATOR), not sim.economy.can_afford(cfg.hire_fee))])
	elif free_ops > 0:
		b.add_child(wrap_label("%d người vận hành đang rảnh chờ máy mới." % free_ops, 14, UiTheme.MUTED))
	b.add_child(HSeparator.new())
	b.add_child(wrap_label("Nhà kho, mở rộng đất, phòng nghỉ và trung tâm nghiên cứu sẽ mở ở các bản sau."))
