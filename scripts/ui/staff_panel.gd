## Staff, grouped by factory and, inside each factory, by position: hiring
## for each factory, the factory manager, and who does what right now.
## Groups fold open and shut so a big company stays easy to read.
class_name StaffPanel
extends SidePanel

const ROLES := [EmployeeManager.OPERATOR, EmployeeManager.WAREHOUSE, EmployeeManager.TECHNICIAN]
## Groups with at most this many people start open.
const OPEN_UP_TO := 4

## Factory shown: "all", "" (the first factory) or a location id. Other
## panels set it to jump to one factory.
static var filter := "all"
## Group key (site|role) -> true when unfolded, false when folded by the player.
var _open := {}


func _init() -> void:
	title = "Nhân sự"


func signature(sim: Simulation) -> String:
	var parts := [sim.state.cash, sim.state.settings, sim.state.strike, sim.employees.on_shift(), filter, _open,
		sim.expansion.factory_ids(), sim.state.machines.size()]
	for s in sim.state.sites:
		parts.append(s.head)
	for e in sim.state.employees:
		parts.append("%d:%d:%s:%d:%s" % [e.id, e.machine_id, "" if e.job.is_empty() else e.job.kind + e.job.phase,
			int(e.get("mood", 0)), SelectionPanel.employee_activity(sim, e)])
	return str(parts)


func build(b: VBoxContainer, sim: Simulation) -> void:
	var cfg := sim.config
	var factories: Array = [""] + sim.expansion.factory_ids()
	if filter != "all" and not factories.has(filter):
		filter = "all"
	row(b, "Số nhân viên", "%d" % sim.state.employees.size())
	row(b, "Tổng lương mỗi ngày", Fmt.money(sim.employees.total_wages()), UiTheme.WARN)
	var avg := sim.employees.average_mood()
	row(b, "Tâm trạng chung", "%s (%d)" % [SelectionPanel.mood_text(avg), avg], SelectionPanel.mood_color(avg))
	if sim.employees.on_strike():
		b.add_child(wrap_label("⚠ Công nhân đang đình công! Xem phần Ca làm việc và lương ở cuối bảng.", 14, UiTheme.BAD))
	if factories.size() > 1:
		var values := ["all"] + factories
		var labels := ["Tất cả"]
		for f in factories:
			labels.append(_short_name(sim, f, factories.size()))
		b.add_child(UiTheme.label("Xem xưởng", 14, UiTheme.MUTED))
		b.add_child(UiTheme.choice(values, labels, filter, func(v):
			filter = v
			refresh()))
	for f in factories:
		if filter == "all" or filter == f:
			_factory_section(b, sim, f)
	if filter == "all":
		_leaders_card(b, sim)
	b.add_child(HSeparator.new())
	_shift_card(b, sim)
	b.add_child(wrap_label("Phí tuyển %s, lương %s mỗi ngày.\n· Vận hành máy: tự nhận máy còn trống trong xưởng của mình.\n· Nhân viên kho: chuyển hàng từ máy sang kho thành phẩm (ở xưởng chính còn dỡ hạt nhựa từ bãi vào kho).\n· Kỹ thuật viên: tự bảo trì máy dưới %d%% và sửa máy hỏng trong xưởng, không mất phí sửa." % [Fmt.money(cfg.hire_fee), Fmt.money(cfg.wage_per_day), EmployeeManager.SERVICE_BELOW]))


## One factory: its people per position, its manager and hiring.
func _factory_section(b: VBoxContainer, sim: Simulation, site: String) -> void:
	var staff := sim.employees.staff_at(site)
	var wages := 0
	for e in staff:
		wages += sim.employees.wage_of(e)
	b.add_child(HSeparator.new())
	var head := HBoxContainer.new()
	var name := UiTheme.label(sim.expansion.factory_name(site), 18, UiTheme.WARN, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(UiTheme.label("%d người · %s/ngày" % [staff.size(), Fmt.money(wages)], 13, UiTheme.MUTED))
	var look := UiTheme.button("Xem", func(): EventBus.camera_focus_requested.emit(_factory_centre(site), 32.0))
	look.tooltip_text = "Đưa camera tới xưởng này"
	head.add_child(look)
	b.add_child(head)
	var c := card(b)
	var machines := sim.production.machines_at(site)
	var no_op := 0
	for m in machines:
		if m.operator_id == 0 and sim.production.needs_operator(m):
			no_op += 1
	row(c, "Máy", "%d / %d" % [machines.size(), sim.production.slot_count(site)])
	if no_op > 0:
		row(c, "Máy chưa có người vận hành", "%d" % no_op, UiTheme.WARN)
	if not machines.is_empty() and sim.employees.count(EmployeeManager.WAREHOUSE, site) == 0:
		c.add_child(wrap_label("Chưa có nhân viên kho: hàng không được mang đi, máy sẽ dừng khi pallet đầy.", 13, UiTheme.WARN))
	_manager_row(c, sim, site)
	var poor := not sim.economy.can_afford(sim.config.hire_fee)
	buttons(c, [
		UiTheme.button("+ Vận hành", func(): GameManager.hire_at(EmployeeManager.OPERATOR, site), poor),
		UiTheme.button("+ Kho", func(): GameManager.hire_at(EmployeeManager.WAREHOUSE, site), poor),
		UiTheme.button("+ Kỹ thuật", func(): GameManager.hire_at(EmployeeManager.TECHNICIAN, site), poor),
	])
	for role in ROLES:
		_role_group(b, sim, site, role, staff.filter(func(e): return e.role == role))


## The factory manager: an employee in the first factory, the site's head
## in a factory next door.
func _manager_row(c: VBoxContainer, sim: Simulation, site: String) -> void:
	var who := ""
	var fire := Callable()
	if site == "":
		for e in sim.state.employees:
			if e.role == EmployeeManager.MANAGER:
				who = e.name
				fire = func(): GameManager.fire(e.id)
	else:
		who = sim.expansion.site(site).head
		fire = func(): GameManager.fire_site_head(site)
	var h := HBoxContainer.new()
	var l := UiTheme.label("Xưởng trưởng: " + (who if who != "" else "chưa có"), 14, UiTheme.GOOD if who != "" else UiTheme.WARN)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	if who != "":
		h.add_child(UiTheme.button("Cho nghỉ", fire))
	c.add_child(h)
	if who != "":
		return
	var fee := sim.config.hire_fee
	var wage := sim.config.wage_per_day * EmployeeManager.MANAGER_WAGE_FACTOR
	if site != "":
		var l2: LocationDef = sim.content.locations[site]
		fee = sim.expansion.head_hire_fee(l2)
		wage = sim.expansion.head_wage(l2)
	c.add_child(wrap_label("Máy cả xưởng nhanh hơn %d%%, tự gọi sửa máy hỏng khi không có kỹ thuật viên rảnh. Lương %s / ngày." % [ExpansionManager.MANAGER_SPEED_PERCENT, Fmt.money(wage)]))
	var btn := UiTheme.button("+ Tuyển xưởng trưởng (%s)" % Fmt.money(fee), func(): GameManager.hire_at(EmployeeManager.MANAGER, site), not sim.economy.can_afford(fee))
	btn.add_theme_color_override("font_color", UiTheme.GOOD)
	buttons(c, [btn])


## A fold-out list of the people in one position of one factory, with a
## one-line count of who is working, resting and gone home.
func _role_group(b: VBoxContainer, sim: Simulation, site: String, role: String, people: Array) -> void:
	if people.is_empty():
		return
	var key := site + "|" + role
	var open: bool = _open.get(key, people.size() <= OPEN_UP_TO)
	var working := 0
	var resting := 0
	var home := 0
	for e in people:
		if e.get("off", false):
			home += 1
		elif e.get("rest", false) or sim.employees.on_strike():
			resting += 1
		else:
			working += 1
	var parts := ["%d làm" % working]
	if resting > 0:
		parts.append(("%d đình công" if sim.employees.on_strike() else "%d nghỉ") % resting)
	if home > 0:
		parts.append("%d về nhà" % home)
	var text := "%s %s (%d) · %s" % ["▾" if open else "▸", EmployeeManager.ROLE_NAMES[role], people.size(), ", ".join(parts)]
	var toggle := UiTheme.button(text, func():
		_open[key] = not open
		refresh())
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_child(toggle)
	if not open:
		return
	var c := card(b)
	for i in people.size():
		var e: Dictionary = people[i]
		if i > 0:
			c.add_child(HSeparator.new())
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		var mood := int(e.get("mood", 70))
		var top := HBoxContainer.new()
		var n := UiTheme.label(e.name, 15, UiTheme.TEXT, true)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(n)
		top.add_child(UiTheme.label("%s (%d)" % [SelectionPanel.mood_text(mood), mood], 13, SelectionPanel.mood_color(mood)))
		v.add_child(top)
		var act := UiTheme.label(SelectionPanel.employee_activity(sim, e), 13, UiTheme.MUTED)
		act.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(act)
		h.add_child(v)
		var id: int = e.id
		h.add_child(UiTheme.button("Xem", func():
			EventBus.selection_changed.emit("worker", id)
			EventBus.camera_focus_requested.emit(_factory_centre(site), 0.0)))
		h.add_child(UiTheme.button("Cho nghỉ", func(): GameManager.fire(id)))
		c.add_child(h)


## Executives and branch directors, who are not in any hall.
func _leaders_card(b: VBoxContainer, sim: Simulation) -> void:
	var lines := []
	for id in ExpansionManager.EXECUTIVE_ORDER:
		if sim.expansion.has_exec(id):
			lines.append([ExpansionManager.EXECUTIVES[id].name, str(sim.state.executives[id])])
	for s in sim.state.sites:
		if not sim.expansion.is_factory(s.id) and s.head != "":
			var l: LocationDef = sim.content.locations[s.id]
			lines.append(["%s %s" % [sim.expansion.head_title(l), l.display_name], s.head])
	if lines.is_empty():
		return
	b.add_child(HSeparator.new())
	b.add_child(UiTheme.label("Ban lãnh đạo và chi nhánh", 18, UiTheme.WARN, true))
	var c := card(b)
	for x in lines:
		row(c, x[0], x[1])
	c.add_child(wrap_label("Bổ nhiệm và cho thôi ở bảng Mở rộng."))


## Short factory names for the rows of choice buttons on narrow phones.
static func _short_name(sim: Simulation, site: String, count: int) -> String:
	if site == "":
		return "Chính"
	return sim.expansion.factory_name(site) if count <= 2 else sim.expansion.factory_name(site).replace("Xưởng ", "X")


static func _factory_centre(site: String) -> Vector3:
	return Vector3(-6, 0, -3) if site == "" else FactoryLayout.plot(site) + Vector3(0, 0, -1.5)


## Shift length (overtime), pay level and the staff's mood (every factory).
func _shift_card(b: VBoxContainer, sim: Simulation) -> void:
	var em := sim.employees
	var c := card(b)
	c.add_child(UiTheme.label("Ca làm việc và lương (mọi xưởng)", 16, UiTheme.TEXT, true))
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
