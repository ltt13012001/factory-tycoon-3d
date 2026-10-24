## Buy raw material lots; shows stock and incoming deliveries.
extends SidePanel


func _init() -> void:
	title = "Mua hàng"


func signature(sim: Simulation) -> String:
	return str([sim.state.raw, sim.state.dock, sim.inventory.pending_material(), sim.state.cash, int(sim.state.tick / 15)])


func build(b: VBoxContainer, sim: Simulation) -> void:
	var cfg := sim.config
	var mat := sim.content.material()
	var c := card(b)
	c.add_child(UiTheme.label(mat.display_name, 16, UiTheme.TEXT, true))
	row(c, "Giá", "%s / đơn vị" % Fmt.money(mat.unit_price))
	row(c, "Phí chở mỗi lô", Fmt.money(cfg.shipping_per_lot))
	row(c, "Thời gian giao", "%d giờ" % cfg.delivery_hours)
	row(c, "Trong kho", "%d / %d" % [sim.state.raw, cfg.raw_capacity])
	if sim.state.dock > 0:
		row(c, "Đang chờ ở bãi giao nhận", "%d" % sim.state.dock, UiTheme.WARN)
	row(c, "Đang trên đường", "%d" % sim.inventory.pending_material())
	var per_day := 0
	for m in sim.state.machines:
		per_day += int(cfg.ticks_per_day / sim.production.def_of(m).cycle_ticks)
	c.add_child(wrap_label("Mỗi máy dùng 1 hạt nhựa cho 1 chu kỳ. Các máy hiện tại dùng tối đa %d đơn vị mỗi ngày." % per_day))

	b.add_child(UiTheme.label("Đặt mua", 16, UiTheme.WARN, true))
	var space := sim.inventory.raw_free_space()
	for qty in cfg.lot_sizes:
		var cost := sim.inventory.lot_cost(qty)
		var reason := ""
		if qty > space:
			reason = " (kho không đủ chỗ)"
		elif not sim.economy.can_afford(cost):
			reason = " (không đủ tiền)"
		var btn := UiTheme.button("Mua %d đơn vị  ·  %s%s" % [qty, Fmt.money(cost), reason],
			func(): GameManager.buy_material(qty), reason != "")
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_child(btn)

	if not sim.state.purchases.is_empty():
		b.add_child(HSeparator.new())
		b.add_child(UiTheme.label("Đơn mua đang giao", 16, UiTheme.ACCENT, true))
		for p in sim.state.purchases:
			var mins := maxi(0, int(p.arrive_tick) - sim.state.tick) * 1440 / cfg.ticks_per_day
			row(b, "%d %s" % [p.qty, mat.display_name], "đến sau %d giờ %02d phút" % [mins / 60, mins % 60])
