## Order offers and accepted orders: accept, reject, ship.
extends SidePanel


func _init() -> void:
	title = "Đơn hàng"


func signature(sim: Simulation) -> String:
	var parts := [sim.state.finished, sim.orders.free_stock(), int(sim.state.tick / sim.config.ticks_per_hour), sim.production.hourly_capacity()]
	for o in sim.state.orders:
		parts.append("%d:%s:%d" % [o.id, o.status, o.ship_ticks_left])
	return str(parts)


func build(b: VBoxContainer, sim: Simulation) -> void:
	var tph := sim.config.ticks_per_hour
	var offered := sim.orders.with_status(OrderManager.OFFERED)
	var accepted := sim.orders.with_status(OrderManager.ACCEPTED)
	var shipping := sim.orders.with_status(OrderManager.SHIPPING)
	var alloc := sim.orders.allocation()

	b.add_child(UiTheme.label("Đơn mới (%d)" % offered.size(), 16, UiTheme.WARN, true))
	if offered.is_empty():
		b.add_child(wrap_label("Chưa có đơn mới. Khách hàng gửi khoảng 2 đơn mỗi ngày, uy tín càng cao càng nhiều đơn."))
	for o in offered:
		var c := card(b)
		c.add_child(UiTheme.label(o.customer, 16, UiTheme.TEXT, true))
		row(c, "Số lượng", "%d hộp × %s" % [o.qty, Fmt.money(o.unit_price)])
		row(c, "Thành tiền", Fmt.money(o.qty * o.unit_price), UiTheme.GOOD)
		row(c, "Hạn giao", "%d ngày sau khi nhận" % o.deadline_days)
		var h := sim.orders.hours_needed(o.id)
		var fits := h >= 0 and h <= int(o.deadline_days) * 24
		var est := "Không có máy chạy" if h < 0 else ("Có sẵn hàng" if h == 0 else "Cần khoảng %d giờ" % h)
		row(c, "Với công suất hiện tại", est, UiTheme.GOOD if fits else UiTheme.BAD)
		row(c, "Hết hạn nhận sau", "%d giờ" % ceili(float(o.expire_tick - sim.state.tick) / tph))
		buttons(c, [
			UiTheme.button("Nhận đơn", func(): GameManager.accept_order(o.id)),
			UiTheme.button("Từ chối", func(): GameManager.reject_order(o.id)),
		])

	b.add_child(HSeparator.new())
	b.add_child(UiTheme.label("Đang thực hiện (%d)" % accepted.size(), 16, UiTheme.ACCENT, true))
	if accepted.is_empty():
		b.add_child(wrap_label("Nhận một đơn để bắt đầu. Hàng trong kho được giữ cho đơn có hạn sớm nhất."))
	var sorted := accepted.duplicate()
	sorted.sort_custom(func(x, y): return x.deadline_tick < y.deadline_tick)
	for o in sorted:
		var c := card(b)
		c.add_child(UiTheme.label(o.customer, 16, UiTheme.TEXT, true))
		var have := int(alloc.get(o.id, 0))
		row(c, "Hàng đã có", "%d / %d hộp" % [have, o.qty], UiTheme.GOOD if have >= o.qty else UiTheme.TEXT)
		var pb := ProgressBar.new()
		pb.max_value = o.qty
		pb.value = have
		pb.show_percentage = false
		pb.custom_minimum_size.y = 8
		c.add_child(pb)
		var left := int(o.deadline_tick) - sim.state.tick
		if left >= 0:
			row(c, "Còn lại", "%d giờ" % ceili(float(left) / tph), UiTheme.TEXT if left > 6 * tph else UiTheme.WARN)
		else:
			var late := sim.orders.late_days(o, sim.state.tick)
			row(c, "Trễ hạn", "%d ngày, phạt %d%%" % [late, mini(sim.config.late_penalty_max_percent, late * sim.config.late_penalty_percent_per_day)], UiTheme.BAD)
		row(c, "Thành tiền", Fmt.money(o.qty * o.unit_price), UiTheme.GOOD)
		var ready := sim.orders.is_ready(o.id)
		var ship := UiTheme.button("Giao hàng" if ready else "Chưa đủ hàng", func(): GameManager.ship_order(o.id), not ready)
		if ready:
			ship.add_theme_color_override("font_color", UiTheme.GOOD)
		buttons(c, [ship])

	if not shipping.is_empty():
		b.add_child(HSeparator.new())
		b.add_child(UiTheme.label("Đang giao (%d)" % shipping.size(), 16, UiTheme.GOOD, true))
		for o in shipping:
			var c := card(b)
			row(c, o.customer, "Xe tải đang lấy %d hộp" % o.qty)
