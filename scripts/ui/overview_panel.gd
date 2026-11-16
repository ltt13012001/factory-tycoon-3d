## Today so far, machine states and yesterday's result.
extends SidePanel


func _init() -> void:
	title = tr("Tổng quan")


func signature(sim: Simulation) -> String:
	var parts := [sim.state.cash / 100, sim.state.reports.size(), str(sim.state.day_stats), sim.state.finished]
	for m in sim.state.machines:
		parts.append("%s%d%d" % [m.status, m.level, m.condition])
	return str(parts)


func build(b: VBoxContainer, sim: Simulation) -> void:
	var cfg := sim.config
	var st := sim.state.day_stats
	var c := card(b)
	c.add_child(UiTheme.label(tr("Hôm nay (ngày %d)") % sim.day(), 16, UiTheme.TEXT, true))
	row(c, tr("Sản phẩm đạt chuẩn"), "%d" % st.produced)
	row(c, tr("Sản phẩm lỗi"), "%d" % st.defects, UiTheme.BAD if st.defects > 0 else UiTheme.TEXT)
	row(c, tr("Doanh thu"), Fmt.money(st.revenue), UiTheme.GOOD)
	row(c, tr("Giá vốn nguyên liệu"), Fmt.money(st.material_cost))
	row(c, tr("Tiền điện (trả cuối ngày)"), Fmt.money(sim.state.power_accrued))
	var fixed := sim.employees.total_wages() + cfg.rent_per_day
	row(c, tr("Lương + thuê đất (cuối ngày)"), Fmt.money(fixed))
	var others := sim.expansion.daily_net()
	if not sim.state.sites.is_empty() or not sim.state.executives.is_empty():
		row(c, tr("Chi phí xưởng khác, chi nhánh, lãnh đạo"), Fmt.money(others), UiTheme.GOOD if others >= 0 else UiTheme.BAD)
	var est: int = st.revenue - st.material_cost - sim.state.power_accrued - fixed - st.penalties + others
	row(c, tr("Lợi nhuận dự kiến"), Fmt.money(est), UiTheme.GOOD if est >= 0 else UiTheme.BAD)

	var sc := card(b)
	sc.add_child(UiTheme.label(tr("Kho thành phẩm  %d / %d") % [sim.state.finished_total(), sim.buildings.finished_capacity()], 16, UiTheme.TEXT, true))
	for pid in sim.content.products:
		var p: ProductDef = sim.content.products[pid]
		if sim.production.produces(pid) or sim.state.finished_of(pid) > 0:
			row(sc, p.display_name, tr("%d %s · %.1f / giờ") % [sim.state.finished_of(pid), p.unit_name, sim.production.hourly_capacity(pid)], p.color.lightened(0.3))

	var mc := card(b)
	mc.add_child(UiTheme.label(tr("Máy móc"), 16, UiTheme.TEXT, true))
	var factories: Array = [""] + sim.expansion.factory_ids()
	var ms := sim.state.machines.duplicate()
	ms.sort_custom(func(x, y):
		var fx := factories.find(ProductionManager.site_of(x))
		var fy := factories.find(ProductionManager.site_of(y))
		return fx < fy or (fx == fy and x.slot < y.slot))
	var shown_site = null
	for m in ms:
		if factories.size() > 1 and ProductionManager.site_of(m) != shown_site:
			shown_site = ProductionManager.site_of(m)
			mc.add_child(UiTheme.label(sim.expansion.factory_name(shown_site), 14, UiTheme.WARN, true))
		var status: String = tr(SelectionPanel.STATUS_NAMES.get(m.status, m.status))
		var d: MachineDef = sim.content.machines[m.def_id]
		row(mc, tr("Ô %d · %s (cấp %d, %d%%)") % [int(m.slot) + 1, d.display_name, m.level, m.condition], status, SelectionPanel.status_color(m.status))

	if sim.state.cash < cfg.overdraft_limit:
		b.add_child(wrap_label(tr("Tiền mặt đã vượt hạn mức thấu chi. Hãy bán bớt máy hoặc cho bớt người nghỉ để phục hồi."), 14, UiTheme.BAD))
	elif sim.state.cash < 0:
		b.add_child(wrap_label(tr("Bạn đang dùng thấu chi khẩn cấp, lãi %d%% mỗi ngày. Hạn mức %s.") % [cfg.overdraft_interest_percent, Fmt.money(cfg.overdraft_limit)], 14, UiTheme.WARN))

	if not sim.state.reports.is_empty():
		var r: Dictionary = sim.state.reports[-1]
		var rc := card(b)
		rc.add_child(UiTheme.label(tr("Hôm qua (ngày %d)") % r.day, 16, UiTheme.TEXT, true))
		row(rc, tr("Sản lượng"), tr("%d hộp") % r.stats.produced)
		row(rc, tr("Lợi nhuận"), Fmt.money(r.profit), UiTheme.GOOD if r.profit >= 0 else UiTheme.BAD)
		row(rc, tr("Dòng tiền"), Fmt.money(r.end_cash - r.start_cash), UiTheme.GOOD if r.end_cash >= r.start_cash else UiTheme.BAD)
		buttons(rc, [UiTheme.button(tr("Xem báo cáo"), func(): EventBus.report_requested.emit(r))])
