## Daily quests and achievements, both paid in diamonds.
class_name QuestsPanel
extends SidePanel


func _init() -> void:
	title = "Nhiệm vụ"


func signature(sim: Simulation) -> String:
	return str([sim.state.quests, sim.diamonds.balance(), sim.quests.claimable(), sim.day()])


func build(b: VBoxContainer, sim: Simulation) -> void:
	var qm := sim.quests
	var top := HBoxContainer.new()
	var l := UiTheme.label("Kim cương đang có", 15, UiTheme.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(l)
	top.add_child(UiTheme.diamond_amount(sim.diamonds.balance(), 17))
	b.add_child(top)

	b.add_child(UiTheme.label("Nhiệm vụ ngày %d" % sim.day(), 18, UiTheme.WARN, true))
	b.add_child(wrap_label("Mỗi ngày trong game có %d nhiệm vụ mới. Xong cả %d được thưởng thêm %d kim cương." % [QuestManager.DAILY_COUNT, QuestManager.DAILY_COUNT, QuestManager.DAILY_ALL_BONUS]))
	var list := qm.daily()
	for i in list.size():
		var d: Dictionary = list[i]
		var c := card(b)
		var h := HBoxContainer.new()
		var t := UiTheme.label(qm.daily_text(d), 15, UiTheme.TEXT, true)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		h.add_child(UiTheme.diamond_amount(qm.daily_reward(d), 14))
		c.add_child(h)
		var done := qm.daily_done(d)
		var shown := Fmt.money(int(d.progress)) + " / " + Fmt.money(int(d.target)) if d.kind == "revenue" else "%d / %d" % [d.progress, d.target]
		var ph := HBoxContainer.new()
		var bar := UiTheme.bar(int(d.progress), int(d.target), UiTheme.GOOD if done else UiTheme.ACCENT)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ph.add_child(bar)
		ph.add_child(UiTheme.label(shown, 13, UiTheme.MUTED))
		c.add_child(ph)
		if d.claimed:
			c.add_child(UiTheme.label("✓ Đã nhận", 14, UiTheme.GOOD))
		elif done:
			var idx := i
			var btn := UiTheme.diamond_button("Nhận thưởng", func(): GameManager.claim_daily_quest(idx))
			btn.add_theme_color_override("font_color", UiTheme.GOOD)
			c.add_child(btn)

	b.add_child(HSeparator.new())
	b.add_child(UiTheme.label("Thành tựu", 18, UiTheme.WARN, true))
	var shown_open := 0
	for m in qm.milestones():
		if m.claimed:
			continue
		# The ones ready to claim, then the next few to aim for.
		if not m.met and shown_open >= 4:
			continue
		if not m.met:
			shown_open += 1
		var c := card(b)
		var h := HBoxContainer.new()
		var t := UiTheme.label(m.text, 15, UiTheme.TEXT if m.met else UiTheme.MUTED, m.met)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		h.add_child(UiTheme.diamond_amount(int(m.reward), 14))
		c.add_child(h)
		if m.met:
			var id: String = m.id
			var btn := UiTheme.diamond_button("Nhận thưởng", func(): GameManager.claim_milestone(id))
			btn.add_theme_color_override("font_color", UiTheme.GOOD)
			c.add_child(btn)
	var claimed := 0
	for m in qm.milestones():
		if m.claimed:
			claimed += 1
	b.add_child(wrap_label("Đã nhận %d / %d thành tựu." % [claimed, QuestManager.MILESTONES.size()]))
	b.add_child(UiTheme.button("Thêm kim cương: xem quảng cáo, nạp →", func(): EventBus.panel_requested.emit("diamonds")))
