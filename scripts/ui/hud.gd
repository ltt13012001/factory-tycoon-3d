## Root of the interface: top info bar, panel navigation, tutorial, toasts,
## selection details and the daily report. Built in code on one Theme.
extends Control

const PANELS := [
	["overview", "Tổng quan", preload("res://scripts/ui/overview_panel.gd")],
	["orders", "Đơn hàng", preload("res://scripts/ui/orders_panel.gd")],
	["purchase", "Mua hàng", preload("res://scripts/ui/purchase_panel.gd")],
	["build", "Xây dựng", preload("res://scripts/ui/build_panel.gd")],
	["staff", "Nhân sự", preload("res://scripts/ui/staff_panel.gd")],
]

var _cash: Label
var _rep: Label
var _clock: Label
var _raw: Label
var _finished: Label
var _alert: Button
var _build_status: Label
var _menu: MenuButton
var _ui_scale := 1.0
var _speed_buttons: Array[Button] = []
var _nav_buttons := {}
var _panels := {}
var _tutorial: PanelContainer
var _tutorial_label: Label
var _build_banner: PanelContainer
var _banner_label: Label
var _toasts: VBoxContainer
var _confirm: ConfirmationDialog
var _current := ""

const SETTINGS_PATH := "user://settings.cfg"


func _ready() -> void:
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_bar()
	_build_nav()
	_build_tutorial()
	_build_toasts()
	_build_corner_panels()
	_build_help()
	_load_ui_scale()
	EventBus.toast.connect(show_toast)
	EventBus.speed_changed.connect(func(_s): _update_speed_buttons())
	EventBus.build_mode_changed.connect(func(active):
		_build_banner.visible = active
		if active:
			if _current != "":
				toggle_panel(_current)  # get the panel out of the way of the hall
			var d: MachineDef = GameManager.sim.content.machines[GameManager.pending_machine_id]
			_banner_label.text = "Bấm vào ô xanh trong xưởng để đặt %s (%s)." % [d.display_name, Fmt.money(d.price)])
	EventBus.order_offered.connect(func(_d): show_toast("Có đơn hàng mới!", true))
	EventBus.order_expired.connect(func(d): show_toast("Đơn của %s đã hết hạn." % d.customer, false))
	EventBus.material_arrived.connect(func(d): show_toast("Xe chở %d hạt nhựa đã đến bãi." % d.qty, true))
	EventBus.order_completed.connect(_on_order_completed)
	EventBus.cash_critical.connect(func(_d): show_toast("Tiền mặt vượt hạn mức thấu chi!", false))
	EventBus.machine_broken.connect(func(_d): show_toast("Một máy vừa hỏng! Bấm vào máy để sửa hoặc tuyển kỹ thuật viên.", false))
	EventBus.machine_repaired.connect(func(_d): show_toast("Máy đã sửa xong.", true))
	EventBus.machine_upgraded.connect(func(_d): show_toast("Đã nâng cấp máy.", true))
	EventBus.construction_finished.connect(func(d): show_toast("Đã xây xong %s!" % GameManager.sim.content.constructions[d.id].display_name, true))
	_update_speed_buttons()


func _process(_delta: float) -> void:
	var sim := GameManager.sim
	if sim == null:
		return
	var s := sim.state
	_cash.text = Fmt.money(s.cash)
	_cash.add_theme_color_override("font_color", UiTheme.GOOD if s.cash >= 0 else UiTheme.BAD)
	_rep.text = "Uy tín %d" % s.reputation
	_clock.text = TimeManager.clock_text()
	var incoming := sim.inventory.pending_material() + s.dock
	_raw.text = "Hạt nhựa %d/%d%s" % [s.raw, sim.buildings.raw_capacity(), (" (+%d)" % incoming) if incoming > 0 else ""]
	_raw.add_theme_color_override("font_color", UiTheme.BAD if s.raw < 20 else UiTheme.TEXT)
	_finished.text = "Kho %d/%d" % [s.finished_total(), sim.buildings.finished_capacity()]
	var broken := 0
	for m in s.machines:
		if m.broken:
			broken += 1
	_alert.visible = broken > 0
	_alert.text = "⚠ %d máy hỏng!" % broken
	var c: Dictionary = s.construction
	_build_status.visible = not c.is_empty()
	if not c.is_empty():
		_build_status.text = "Đang xây %s: %d%%" % [sim.content.constructions[c.id].display_name, 100 - int(c.ticks_left) * 100 / maxi(1, int(c.total_ticks))]
	var offers := sim.orders.with_status(OrderManager.OFFERED).size()
	var ready := 0
	for o in sim.orders.with_status(OrderManager.ACCEPTED):
		if sim.orders.is_ready(o.id):
			ready += 1
	var badge := ""
	if offers > 0:
		badge += "  %d mới" % offers
	if ready > 0:
		badge += "  %d giao được" % ready
	_nav_buttons["orders"].text = "Đơn hàng" + badge
	var text := sim.tutorial.current_text()
	_tutorial.visible = text != ""
	_tutorial_label.text = text


# --- Layout ------------------------------------------------------------------

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.BG, 0, 10))
	add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	bar.add_child(h)
	_cash = UiTheme.label("", 18, UiTheme.GOOD, true)
	_rep = UiTheme.label("", 16)
	_clock = UiTheme.label("", 16)
	_raw = UiTheme.label("", 16)
	_finished = UiTheme.label("", 16)
	for l in [_cash, _rep, _clock, _raw, _finished]:
		h.add_child(l)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(spacer)
	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 4)
	h.add_child(speeds)
	for sp in [0, 1, 2, 4]:
		var b := UiTheme.button("||" if sp == 0 else "x%d" % sp, func(): TimeManager.set_speed(sp))
		b.toggle_mode = true
		b.custom_minimum_size.x = 46
		b.tooltip_text = "Tạm dừng (Space)" if sp == 0 else "Tốc độ x%d" % sp
		speeds.add_child(b)
		_speed_buttons.append(b)
	_menu = MenuButton.new()
	_menu.text = "Menu"
	_menu.flat = false
	_menu.focus_mode = Control.FOCUS_NONE
	var pm := _menu.get_popup()
	pm.add_theme_font_size_override("font_size", 18)
	pm.add_item("Chữ to hơn (A+)", 0)
	pm.add_item("Chữ nhỏ hơn (A−)", 1)
	pm.add_separator()
	pm.add_item("Lưu game", 2)
	pm.add_item("Chơi lại từ đầu", 3)
	pm.id_pressed.connect(_on_menu)
	h.add_child(_menu)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Chơi lại từ đầu?"
	_confirm.dialog_text = "Tiến trình hiện tại sẽ bị xóa."
	_confirm.ok_button_text = "Chơi lại"
	_confirm.cancel_button_text = "Hủy"
	_confirm.confirmed.connect(func():
		GameManager.new_game()
		EventBus.selection_changed.emit("", 0)
		show_toast("Bắt đầu game mới.", true))
	add_child(_confirm)


func _on_menu(id: int) -> void:
	match id:
		0:
			set_ui_scale(_ui_scale + 0.1)
		1:
			set_ui_scale(_ui_scale - 0.1)
		2:
			show_toast("Đã lưu game." if SaveManager.save_game() else "Không lưu được!", true)
		3:
			_confirm.popup_centered()


## Scales the whole interface (and the 3D labels stay as they are).
func set_ui_scale(value: float) -> void:
	_ui_scale = clampf(snappedf(value, 0.1), 0.8, 1.8)
	get_tree().root.content_scale_factor = _ui_scale
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("ui", "scale", _ui_scale)
	cfg.save(SETTINGS_PATH)
	show_toast("Cỡ giao diện %d%%" % roundi(_ui_scale * 100), true)


func _load_ui_scale() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_ui_scale = float(cfg.get_value("ui", "scale", 1.0))
		get_tree().root.content_scale_factor = _ui_scale


func _update_speed_buttons() -> void:
	var speeds := [0, 1, 2, 4]
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(speeds[i] == TimeManager.speed)


func _build_nav() -> void:
	var nav := VBoxContainer.new()
	nav.position = Vector2(12, 72)
	nav.add_theme_constant_override("separation", 6)
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nav)
	for p in PANELS:
		var id: String = p[0]
		var b := UiTheme.button(p[1], func(): toggle_panel(id))
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(170, 46)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nav.add_child(b)
		_nav_buttons[id] = b
		var panel: SidePanel = p[2].new()
		panel.anchor_top = 0
		panel.anchor_bottom = 1
		panel.offset_left = 192
		panel.offset_top = 72
		panel.offset_right = 192 + 480
		panel.offset_bottom = -16
		panel.visible = false
		add_child(panel)
		_panels[id] = panel
	# Alerts under the navigation: a broken-machine button that jumps to the
	# machine, and the construction progress.
	_alert = UiTheme.button("", _select_broken_machine)
	_alert.custom_minimum_size = Vector2(170, 46)
	_alert.add_theme_color_override("font_color", Color.WHITE)
	for st in ["normal", "hover", "pressed"]:
		_alert.add_theme_stylebox_override(st, UiTheme.panel_style(UiTheme.BAD.darkened(0.25 if st == "normal" else 0.1), 8, 8))
	_alert.tooltip_text = "Bấm để chọn máy hỏng"
	_alert.visible = false
	nav.add_child(_alert)
	_build_status = UiTheme.label("", 15, UiTheme.WARN)
	_build_status.custom_minimum_size.x = 170
	_build_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_status.add_theme_stylebox_override("normal", UiTheme.panel_style(UiTheme.BG, 8, 8))
	_build_status.visible = false
	nav.add_child(_build_status)


func _select_broken_machine() -> void:
	for m in GameManager.sim.state.machines:
		if m.broken:
			EventBus.selection_changed.emit("machine", m.id)
			return


func toggle_panel(id: String) -> void:
	_current = "" if _current == id else id
	for k in _panels:
		_panels[k].visible = k == _current
		_nav_buttons[k].set_pressed_no_signal(k == _current)


func _build_tutorial() -> void:
	_tutorial = PanelContainer.new()
	_tutorial.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.15, 0.3, 0.55, 0.93), 10, 12))
	_tutorial.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_tutorial.offset_top = 74
	_tutorial.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tutorial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tutorial)
	_tutorial_label = UiTheme.label("", 16, Color.WHITE, true)
	_tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_label.custom_minimum_size.x = 480
	_tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial.add_child(_tutorial_label)

	_build_banner = PanelContainer.new()
	_build_banner.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.15, 0.45, 0.25, 0.95), 10, 12))
	_build_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_build_banner.offset_top = -120
	_build_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_build_banner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 12)
	_banner_label = UiTheme.label("Bấm vào ô xanh trong xưởng để đặt máy.", 16, Color.WHITE, true)
	bh.add_child(_banner_label)
	bh.add_child(UiTheme.button("Hủy (Esc)", func(): EventBus.build_mode_changed.emit(false)))
	_build_banner.add_child(bh)
	_build_banner.visible = false
	add_child(_build_banner)


func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_toasts.offset_top = 74
	_toasts.offset_right = -16
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 6)
	add_child(_toasts)


func show_toast(text: String, good: bool = true) -> void:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color := Color(0.12, 0.35, 0.22, 0.95) if good else Color(0.5, 0.15, 0.15, 0.95)
	pc.add_theme_stylebox_override("panel", UiTheme.panel_style(color, 8, 10))
	var l := UiTheme.label(text, 15, Color.WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 330
	pc.add_child(l)
	_toasts.add_child(pc)
	while _toasts.get_child_count() > 5:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := pc.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(pc, "modulate:a", 0.0, 0.6)
	tw.tween_callback(pc.queue_free)


func _build_corner_panels() -> void:
	var sel := SelectionPanel.new()
	sel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	sel.offset_right = -16
	sel.offset_bottom = -16
	sel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	sel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(sel)
	var report: PanelContainer = preload("res://scripts/ui/daily_report.gd").new()
	report.name = "DailyReport"
	report.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	report.grow_horizontal = Control.GROW_DIRECTION_BOTH
	report.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(report)


func _build_help() -> void:
	var l := UiTheme.label("Q / E xoay · Lăn chuột phóng to · Chuột phải kéo hoặc WASD di chuyển · Bấm vào máy để xem và sửa · Space tạm dừng", 13, Color(1, 1, 1, 0.85))
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	l.offset_left = 14
	l.offset_top = -30
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)


func _on_order_completed(d: Dictionary) -> void:
	var msg := "%s đã thanh toán %s" % [d.customer, Fmt.money(int(d.value) - int(d.penalty))]
	if int(d.penalty) > 0:
		msg += " (phạt trễ %s)" % Fmt.money(int(d.penalty))
	show_toast(msg, int(d.penalty) == 0)
