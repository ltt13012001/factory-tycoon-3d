## Staff list with hiring and letting people go.
extends SidePanel


func _init() -> void:
	title = "Nhân sự"


func signature(sim: Simulation) -> String:
	var parts := [sim.state.cash, sim.state.settings, sim.state.strike, sim.employees.on_shift()]
	for e in sim.state.employees:
		parts.append("%d:%d:%s:%d:%s" % [e.id, e.machine_id, "" if e.job.is_empty() else e.job.kind + e.job.phase,
			int(e.get("mood", 0)), SelectionPanel.employee_activity(sim, e)])
	return str(parts)


func build(b: VBoxContainer, sim: Simulation) -> void:
	var cfg := sim.config
	row(b, "Số nhân viên", "%d" % sim.state.employees.size())
	row(b, "Tổng lương mỗi ngày", Fmt.money(sim.employees.total_wages()), UiTheme.WARN)
	_shift_card(b, sim)
	_manager_card(b, sim)
	var c := card(b)
	c.add_child(UiTheme.label("Tuyển dụng", 16, UiTheme.TEXT, true))
	c.add_child(wrap_label("Phí tuyển %s, lương %s mỗi ngày.\n· Vận hành máy: tự nhận máy còn trống.\n· Nhân viên kho: chuyển hàng từ bãi vào kho và từ máy sang kho thành phẩm.\n· Kỹ thuật viên: tự bảo trì máy dưới %d%% và sửa máy hỏng, không mất phí sửa." % [Fmt.money(cfg.hire_fee), Fmt.money(cfg.wage_per_day), EmployeeManager.SERVICE_BELOW]))
	var poor := not sim.economy.can_afford(cfg.hire_fee)
	buttons(c, [
		UiTheme.button("+ Vận hành", func(): GameManager.hire(EmployeeManager.OPERATOR), poor),
		UiTheme.button("+ Kho", func(): GameManager.hire(EmployeeManager.WAREHOUSE), poor),
		UiTheme.button("+ Kỹ thuật", func(): GameManager.hire(EmployeeManager.TECHNICIAN), poor),
	])
	for e in sim.state.employees:
		var ec := card(b)
		var h := HBoxContainer.new()
		var name := UiTheme.label(e.name, 15, UiTheme.TEXT, true)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(name)
		h.add_child(UiTheme.button("Cho nghỉ", func(): GameManager.fire(e.id)))
		ec.add_child(h)
		row(ec, EmployeeManager.ROLE_NAMES[e.role], SelectionPanel.employee_activity(sim, e))
		var mood := int(e.get("mood", 70))
		row(ec, "Tâm trạng", "%s (%d)" % [SelectionPanel.mood_text(mood), mood], SelectionPanel.mood_color(mood))


## The factory manager ("xưởng trưởng") of the first factory.
func _manager_card(b: VBoxContainer, sim: Simulation) -> void:
	var c := card(b)
	c.add_child(UiTheme.label("Xưởng trưởng", 16, UiTheme.TEXT, true))
	var wage := sim.config.wage_per_day * EmployeeManager.MANAGER_WAGE_FACTOR
	var has := sim.employees.count(EmployeeManager.MANAGER) > 0
	c.add_child(wrap_label("Quản lý cả xưởng: mọi máy chạy nhanh hơn %d%%, tự gọi sửa máy hỏng khi không có kỹ thuật viên rảnh. Lương %s mỗi ngày." % [ExpansionManager.MANAGER_SPEED_PERCENT, Fmt.money(wage)]))
	if has:
		for e in sim.state.employees:
			if e.role == EmployeeManager.MANAGER:
				row(c, "Đang giữ chức", e.name, UiTheme.GOOD)
	else:
		var btn := UiTheme.button("+ Tuyển xưởng trưởng (%s)" % Fmt.money(sim.config.hire_fee), func(): GameManager.hire(EmployeeManager.MANAGER), not sim.economy.can_afford(sim.config.hire_fee))
		btn.add_theme_color_override("font_color", UiTheme.GOOD)
		buttons(c, [btn])


## Shift length (overtime), pay level and the staff's mood.
func _shift_card(b: VBoxContainer, sim: Simulation) -> void:
	var em := sim.employees
	var c := card(b)
	c.add_child(UiTheme.label("Ca làm việc và lương", 16, UiTheme.TEXT, true))
	var hours := em.shift_hours()
	var start := sim.config.day_start_hour
	row(c, "Giờ làm", "%02d:00 – %02d:00 (%d tiếng)" % [start, (start + hours) % 24, hours])
	var labels := []
	for h in EmployeeManager.SHIFT_CHOICES:
		labels.append("%d tiếng" % h)
	c.add_child(UiTheme.choice(EmployeeManager.SHIFT_CHOICES, labels, hours, func(h): GameManager.set_shift(h)))
	c.add_child(wrap_label("Ca chuẩn %d tiếng. Tăng ca 10–14 tiếng làm ra nhiều hàng hơn, giờ tăng ca trả %d%% lương nhưng nhân viên mệt và kém vui hơn. Ngoài giờ làm, máy cần người vận hành sẽ dừng; máy tự động vẫn chạy." % [EmployeeManager.STANDARD_SHIFT, EmployeeManager.OVERTIME_PAY_PERCENT]))
	var pay := em.pay_percent()
	var pay_row := row(c, "Mức lương", "")
	var pay_label: Label = pay_row.get_child(1)
	var wage_text := func(p: int) -> String:
		return "%d%% · %s / người / ngày" % [p, Fmt.money(sim.config.wage_per_day * p / 100)]
	pay_label.text = wage_text.call(pay)
	var sl := UiTheme.slider(EmployeeManager.PAY_MIN, EmployeeManager.PAY_MAX, 5, pay, func(p):
		pay_label.text = wage_text.call(p)
		GameManager.sim.set_pay(p))
	c.add_child(sl)
	var avg := em.average_mood()
	var target := em.average_mood_target()
	row(c, "Tâm trạng chung", "%s (%d)" % [SelectionPanel.mood_text(avg), avg], SelectionPanel.mood_color(avg))
	c.add_child(UiTheme.bar(avg, 100, SelectionPanel.mood_color(avg)))
	var trend := "đang tăng" if target > avg + 1 else ("đang giảm" if target < avg - 1 else "ổn định")
	row(c, "Với lương và giờ làm này", "hướng tới %d (%s)" % [target, trend], SelectionPanel.mood_color(target))
	if em.on_strike():
		c.add_child(wrap_label("⚠ Công nhân đang đình công, không ai làm việc! Tăng lương hoặc bớt tăng ca (tâm trạng hướng tới từ %d trở lên) để họ quay lại." % EmployeeManager.STRIKE_ENDS_AT, 14, UiTheme.BAD))
	elif target < EmployeeManager.STRIKE_BELOW:
		c.add_child(wrap_label("⚠ Lương thấp và giờ làm dài: tâm trạng dưới %d thì công nhân có thể đình công." % EmployeeManager.STRIKE_BELOW, 14, UiTheme.BAD))
	elif sim.buildings.level("break_room") == 0:
		c.add_child(wrap_label("Mẹo: xây Phòng nghỉ nhân viên để mọi người vui hơn (+%d)." % EmployeeManager.BREAK_ROOM_MOOD))
