## Staff list with hiring and letting people go.
extends SidePanel


func _init() -> void:
	title = "Nhân sự"


func signature(sim: Simulation) -> String:
	var parts := [sim.state.cash]
	for e in sim.state.employees:
		parts.append("%d:%d:%s" % [e.id, e.machine_id, "" if e.job.is_empty() else e.job.kind + e.job.phase])
	return str(parts)


func build(b: VBoxContainer, sim: Simulation) -> void:
	var cfg := sim.config
	row(b, "Số nhân viên", "%d" % sim.state.employees.size())
	row(b, "Tổng lương mỗi ngày", Fmt.money(sim.state.employees.size() * cfg.wage_per_day), UiTheme.WARN)
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
