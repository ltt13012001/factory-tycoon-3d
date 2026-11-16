## Order offers and accepted orders: accept, reject, ship.
extends SidePanel


func _init() -> void:
	title = tr("Đơn hàng")


func signature(sim: Simulation) -> String:
	var parts := [sim.state.finished, int(sim.state.tick / sim.config.ticks_per_hour), sim.production.hourly_capacity(), sim.state.settings, sim.expansion.has_director()]
	for o in sim.state.orders:
		parts.append("%d:%s:%d" % [o.id, o.status, o.ship_ticks_left])
	return str(parts)


func build(b: VBoxContainer, sim: Simulation) -> void:
	var tph := sim.config.ticks_per_hour
	var offered := sim.orders.with_status(OrderManager.OFFERED)
	var accepted := sim.orders.with_status(OrderManager.ACCEPTED)
	var shipping := sim.orders.with_status(OrderManager.SHIPPING)
	var alloc := sim.orders.allocation()

	b.add_child(UiTheme.toggle(tr("Tự động giao khi đủ hàng"), sim.state.settings.get("auto_ship", false), func(on): GameManager.set_auto_ship(on)))
	if sim.expansion.has_director():
		b.add_child(UiTheme.toggle(tr("Giám đốc tự nhận đơn kịp hạn"), sim.state.settings.get("auto_accept", false), func(on): GameManager.set_auto_accept(on)))
	else:
		b.add_child(wrap_label(tr("Tuyển một giám đốc (bảng Mở rộng, từ Công ty TNHH) để giám đốc tự nhận các đơn làm kịp hạn.")))
	b.add_child(UiTheme.label(tr("Đơn mới (%d)") % offered.size(), 16, UiTheme.WARN, true))
	if offered.is_empty():
		b.add_child(wrap_label(tr("Chưa có đơn mới. Uy tín càng cao càng nhiều đơn. Mua máy làm sản phẩm mới để có thêm khách.")))
	for o in offered:
		var p: ProductDef = sim.content.products[o.product_id]
		var c := card(b)
		c.add_child(UiTheme.label(o.customer, 16, UiTheme.TEXT, true))
		row(c, tr("Sản phẩm"), p.display_name, p.color.lightened(0.3))
		row(c, tr("Số lượng"), "%d %s × %s" % [o.qty, p.unit_name, Fmt.money(o.unit_price)])
		row(c, tr("Thành tiền"), Fmt.money(o.qty * o.unit_price), UiTheme.GOOD)
		row(c, tr("Hạn giao"), tr("%d ngày sau khi nhận") % o.deadline_days)
		var h := sim.orders.hours_needed(o.id)
		var fits := h >= 0 and h <= int(o.deadline_days) * 24
		var est := tr("Không có máy chạy") if h < 0 else (tr("Có sẵn hàng") if h == 0 else tr("Cần khoảng %d giờ") % h)
		row(c, tr("Với công suất hiện tại"), est, UiTheme.GOOD if fits else UiTheme.BAD)
		row(c, tr("Hết hạn nhận sau"), tr("%d giờ") % ceili(float(o.expire_tick - sim.state.tick) / tph))
		buttons(c, [
			UiTheme.button(tr("Nhận đơn"), func(): GameManager.accept_order(o.id)),
			UiTheme.button(tr("Từ chối"), func(): GameManager.reject_order(o.id)),
		])

	b.add_child(HSeparator.new())
	b.add_child(UiTheme.label(tr("Đang thực hiện (%d)") % accepted.size(), 16, UiTheme.ACCENT, true))
	if accepted.is_empty():
		b.add_child(wrap_label(tr("Nhận một đơn để bắt đầu. Hàng trong kho được giữ cho đơn có hạn sớm nhất.")))
	var sorted := accepted.duplicate()
	sorted.sort_custom(func(x, y): return x.deadline_tick < y.deadline_tick)
	for o in sorted:
		var p: ProductDef = sim.content.products[o.product_id]
		var c := card(b)
		c.add_child(UiTheme.label(o.customer, 16, UiTheme.TEXT, true))
		var have := int(alloc.get(o.id, 0))
		row(c, p.display_name, "%d / %d %s" % [have, o.qty, p.unit_name], UiTheme.GOOD if have >= o.qty else UiTheme.TEXT)
		c.add_child(UiTheme.bar(have, o.qty))
		var left := int(o.deadline_tick) - sim.state.tick
		if left >= 0:
			row(c, tr("Còn lại"), tr("%d giờ") % ceili(float(left) / tph), UiTheme.TEXT if left > 6 * tph else UiTheme.WARN)
		else:
			var late := sim.orders.late_days(o, sim.state.tick)
			row(c, tr("Trễ hạn"), tr("%d ngày, phạt %d%%") % [late, mini(sim.config.late_penalty_max_percent, late * sim.config.late_penalty_percent_per_day)], UiTheme.BAD)
		row(c, tr("Thành tiền"), Fmt.money(o.qty * o.unit_price), UiTheme.GOOD)
		var ready := sim.orders.is_ready(o.id)
		var ship := UiTheme.button(tr("Giao hàng") if ready else tr("Chưa đủ hàng"), func(): GameManager.ship_order(o.id), not ready)
		if ready:
			ship.add_theme_color_override("font_color", UiTheme.GOOD)
		buttons(c, [ship])

	if not shipping.is_empty():
		b.add_child(HSeparator.new())
		b.add_child(UiTheme.label(tr("Đang giao (%d)") % shipping.size(), 16, UiTheme.GOOD, true))
		for o in shipping:
			var c := card(b)
			row(c, o.customer, tr("Xe tải đang lấy %d %s") % [o.qty, sim.content.products[o.product_id].unit_name])
