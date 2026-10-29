## Buy raw material lots; shows stock and incoming deliveries.
extends SidePanel


func _init() -> void:
	title = "Mua hàng"


func signature(sim: Simulation) -> String:
	return str([sim.state.raw, sim.state.dock, sim.inventory.pending_material(), sim.state.cash / 100, int(sim.state.tick / 15), sim.state.settings, sim.buildings.raw_capacity()])


func build(b: VBoxContainer, sim: Simulation) -> void:
	var cfg := sim.config
	var mat := sim.content.material()
	var c := card(b)
	c.add_child(UiTheme.label(mat.display_name, 16, UiTheme.TEXT, true))
	row(c, "Giá", "%s / đơn vị" % Fmt.money(mat.unit_price))
	row(c, "Phí chở mỗi lô", Fmt.money(cfg.shipping_per_lot))
	row(c, "Thời gian giao", "%d giờ" % cfg.delivery_hours)
	row(c, "Trong kho", "%d / %d" % [sim.state.raw, sim.buildings.raw_capacity()])
	if sim.state.dock > 0:
		row(c, "Đang chờ ở bãi giao nhận", "%d" % sim.state.dock, UiTheme.WARN)
	row(c, "Đang trên đường", "%d" % sim.inventory.pending_material())
	var per_day := 0
	for m in sim.state.machines:
		per_day += int(sim.production.cycles_per_day(sim.production.def_of(m), sim.production.cycle_ticks(m))) * sim.production.product_of(m).material_per_unit
	c.add_child(wrap_label("Các máy hiện tại dùng tối đa khoảng %d hạt nhựa mỗi ngày." % per_day))
	_auto_buy_card(b, sim)

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


## Auto-buy switch with sliders for how much to buy and when.
func _auto_buy_card(b: VBoxContainer, sim: Simulation) -> void:
	var inv := sim.inventory
	var c := card(b)
	c.add_child(UiTheme.toggle("Tự động mua hạt nhựa", sim.state.settings.get("auto_buy", false), func(on): GameManager.set_auto_buy(on)))
	var lot_row := row(c, "Số lượng mỗi lần mua", "")
	var lot_label: Label = lot_row.get_child(1)
	var lot_text := func(q: int) -> String:
		return "%d · %s" % [q, Fmt.money(inv.lot_cost(q))]
	lot_label.text = lot_text.call(inv.auto_buy_lot())
	c.add_child(UiTheme.slider(InventoryManager.AUTO_LOT_MIN, InventoryManager.AUTO_LOT_MAX, InventoryManager.AUTO_STEP, inv.auto_buy_lot(), func(q):
		lot_label.text = lot_text.call(q)
		GameManager.sim.set_auto_buy_amounts(q, GameManager.sim.inventory.auto_buy_threshold())))
	var th_row := row(c, "Mua khi kho còn dưới", "")
	var th_label: Label = th_row.get_child(1)
	th_label.text = "%d" % inv.auto_buy_threshold()
	c.add_child(UiTheme.slider(0, sim.buildings.raw_capacity(), InventoryManager.AUTO_STEP, inv.auto_buy_threshold(), func(q):
		th_label.text = "%d" % q
		GameManager.sim.set_auto_buy_amounts(GameManager.sim.inventory.auto_buy_lot(), q)))
	c.add_child(wrap_label("Kiểm tra mỗi giờ: khi hạt nhựa trong kho, ở bãi và đang chở tới ít hơn mức trên thì đặt thêm một lô (hoặc phần còn vừa kho)."))
