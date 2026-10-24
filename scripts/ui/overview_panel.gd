## Today so far, machine states and yesterday's result.
extends SidePanel


func _init() -> void:
	title = "Tổng quan"


func signature(sim: Simulation) -> String:
	var parts := [sim.state.cash, sim.state.reports.size(), str(sim.state.day_stats), sim.state.power_accrued]
	for m in sim.state.machines:
		parts.append(m.status)
	return str(parts)


func build(b: VBoxContainer, sim: Simulation) -> void:
	var cfg := sim.config
	var st := sim.state.day_stats
	var c := card(b)
	c.add_child(UiTheme.label("Hôm nay (ngày %d)" % sim.day(), 16, UiTheme.TEXT, true))
	row(c, "Hộp đạt chuẩn", "%d" % st.produced)
	row(c, "Hộp lỗi", "%d" % st.defects, UiTheme.BAD if st.defects > 0 else UiTheme.TEXT)
	row(c, "Doanh thu", Fmt.money(st.revenue), UiTheme.GOOD)
	row(c, "Giá vốn nguyên liệu", Fmt.money(st.material_cost))
	row(c, "Tiền điện (trả cuối ngày)", Fmt.money(sim.state.power_accrued))
	var fixed := sim.state.employees.size() * cfg.wage_per_day + cfg.rent_per_day
	row(c, "Lương + thuê đất (cuối ngày)", Fmt.money(fixed))
	var est: int = st.revenue - st.material_cost - sim.state.power_accrued - fixed - st.penalties
	row(c, "Lợi nhuận dự kiến", Fmt.money(est), UiTheme.GOOD if est >= 0 else UiTheme.BAD)

	var mc := card(b)
	mc.add_child(UiTheme.label("Máy móc", 16, UiTheme.TEXT, true))
	for m in sim.state.machines:
		var status: String = SelectionPanel.STATUS_NAMES.get(m.status, m.status)
		row(mc, "Máy ô %d" % (int(m.slot) + 1), status, UiTheme.GOOD if m.status == "running" else UiTheme.WARN)
	row(mc, "Công suất", "%.1f hộp / giờ game" % sim.production.hourly_capacity())

	if sim.state.cash < cfg.overdraft_limit:
		b.add_child(wrap_label("Tiền mặt đã vượt hạn mức thấu chi. Hãy bán bớt máy hoặc cho bớt người nghỉ để phục hồi.", 14, UiTheme.BAD))
	elif sim.state.cash < 0:
		b.add_child(wrap_label("Bạn đang dùng thấu chi khẩn cấp, lãi %d%% mỗi ngày. Hạn mức %s." % [cfg.overdraft_interest_percent, Fmt.money(cfg.overdraft_limit)], 14, UiTheme.WARN))

	if not sim.state.reports.is_empty():
		var r: Dictionary = sim.state.reports[-1]
		var rc := card(b)
		rc.add_child(UiTheme.label("Hôm qua (ngày %d)" % r.day, 16, UiTheme.TEXT, true))
		row(rc, "Sản lượng", "%d hộp" % r.stats.produced)
		row(rc, "Lợi nhuận", Fmt.money(r.profit), UiTheme.GOOD if r.profit >= 0 else UiTheme.BAD)
		row(rc, "Dòng tiền", Fmt.money(r.end_cash - r.start_cash), UiTheme.GOOD if r.end_cash >= r.start_cash else UiTheme.BAD)
		buttons(rc, [UiTheme.button("Xem báo cáo", func(): EventBus.report_requested.emit(r))])
