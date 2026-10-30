## Root of the interface: top info bar, panel navigation, tutorial, toasts,
## selection details and the daily report. Built in code on one Theme.
extends Control

const PANELS := [
	["overview", "Tổng quan", preload("res://scripts/ui/overview_panel.gd")],
	["orders", "Đơn hàng", preload("res://scripts/ui/orders_panel.gd")],
	["purchase", "Mua hàng", preload("res://scripts/ui/purchase_panel.gd")],
	["build", "Xây dựng", preload("res://scripts/ui/build_panel.gd")],
	["staff", "Nhân sự", preload("res://scripts/ui/staff_panel.gd")],
	["expansion", "Mở rộng", preload("res://scripts/ui/expansion_panel.gd")],
]

var _cash: Label
var _tier: Label
var _rep: Label
var _clock: Label
var _raw: Label
var _finished: Label
var _alert: Button
var _strike_alert: Button
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
var _top_bar: HBoxContainer
var _nav: VBoxContainer
var _report: PanelContainer
var _selection: SelectionPanel
var _help: Label
var _compact := false
var _refresh_wait := 0.0

const REFRESH_INTERVAL := 0.1
const TOP_BAR_PADDING := 10
var _pad: Control

const SETTINGS_PATH := "user://settings.cfg"
## Menu ids: Auto, then one per graphics level.
const GRAPHICS_ITEM := 10


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
	if UiTheme.is_mobile():
		_build_touch_buttons()
	_load_ui_scale()
	get_viewport().size_changed.connect(_relayout)
	_relayout.call_deferred()
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
	EventBus.site_opened.connect(func(d): show_toast("%s đã xây xong! Nhớ tuyển người quản lý và mua dây chuyền." % d.name, true))
	EventBus.site_surveyed.connect(func(d): show_toast("Khảo sát %s xong: sức mua %d%%." % [GameManager.sim.content.locations[d.id].display_name, d.market], true))
	EventBus.strike_started.connect(func(_d): show_toast("Công nhân đình công vì lương thấp! Vào Nhân sự để tăng lương hoặc bớt tăng ca.", false))
	EventBus.strike_ended.connect(func(_d): show_toast("Công nhân đã quay lại làm việc.", true))
	EventBus.staff_unhappy.connect(func(_d): show_toast("Công nhân đang bất mãn với lương và giờ làm. Coi chừng đình công!", false))
	EventBus.site_selected.connect(func(_id):
		if _current != "expansion":
			toggle_panel("expansion"))
	_update_speed_buttons()


func _process(delta: float) -> void:
	var sim := GameManager.sim
	if sim == null:
		return
	# The simulation moves in 0.25 s ticks, so refreshing the texts ten times
	# a second looks the same as every frame and lays out far less often.
	_refresh_wait -= delta
	if _refresh_wait > 0.0:
		return
	_refresh_wait = REFRESH_INTERVAL
	var s := sim.state
	_cash.text = Fmt.money_short(s.cash)
	_cash.tooltip_text = Fmt.money(s.cash)
	_cash.add_theme_color_override("font_color", UiTheme.GOOD if s.cash >= 0 else UiTheme.BAD)
	_rep.text = "Uy tín %d" % s.reputation
	_tier.text = sim.expansion.tier_name()
	_clock.text = TimeManager.clock_text()
	var incoming := sim.inventory.pending_material() + s.dock
	if _compact:
		_raw.text = "Nhựa %d/%d" % [s.raw, sim.buildings.raw_capacity()]
	else:
		_raw.text = "Hạt nhựa %d/%d%s" % [s.raw, sim.buildings.raw_capacity(), (" (+%d)" % incoming) if incoming > 0 else ""]
	_raw.add_theme_color_override("font_color", UiTheme.BAD if s.raw < 20 else UiTheme.TEXT)
	_finished.text = "Kho %d/%d" % [s.finished_total(), sim.buildings.finished_capacity()]
	var broken := 0
	for m in s.machines:
		if m.broken:
			broken += 1
	_alert.visible = broken > 0
	_alert.text = "⚠ %d máy hỏng!" % broken
	_strike_alert.visible = sim.employees.on_strike()
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
	_fit_top_bar()


## Hides the least important figures, one at a time, when the top bar would
## run off the screen (a narrow phone, big text, a long company name), so
## the speed buttons and the Menu always stay on screen.
func _fit_top_bar() -> void:
	var optional: Array[Label] = [_raw, _finished, _rep, _tier]  # most important first
	for l in optional:
		l.visible = true
	var room := size.x - 2 * TOP_BAR_PADDING
	var sep := _top_bar.get_theme_constant("separation")
	var used := 0.0
	for c in _top_bar.get_children():
		var ctl := c as Control
		if ctl.visible:
			used += ctl.get_combined_minimum_size().x + sep
	var i := optional.size() - 1
	while used > room and i >= 0:
		used -= optional[i].get_combined_minimum_size().x + sep
		optional[i].visible = false
		i -= 1
	if used > room:
		_clock.text = TimeManager.clock_text(true)


# --- Layout ------------------------------------------------------------------

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.BG, 0, TOP_BAR_PADDING))
	add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	bar.add_child(h)
	_top_bar = h
	_cash = UiTheme.label("", 18, UiTheme.GOOD, true)
	_tier = UiTheme.label("", 16, UiTheme.WARN, true)
	_rep = UiTheme.label("", 16)
	_clock = UiTheme.label("", 16)
	_raw = UiTheme.label("", 16)
	_finished = UiTheme.label("", 16)
	for l in [_cash, _tier, _rep, _clock, _raw, _finished]:
		h.add_child(l)
	_cash.mouse_filter = Control.MOUSE_FILTER_PASS  # exact amount in the tooltip
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
	pm.add_separator("Đồ họa (máy yếu chọn Thấp)")
	pm.add_radio_check_item("Tự động", GRAPHICS_ITEM)
	for i in Graphics.NAMES.size():
		pm.add_radio_check_item(Graphics.NAMES[i], GRAPHICS_ITEM + 1 + i)
	pm.about_to_popup.connect(_update_graphics_items)
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
		_:
			if id >= GRAPHICS_ITEM:
				var g: Graphics = get_tree().current_scene.get_node("Graphics")
				g.set_tier(id - GRAPHICS_ITEM - 1)
				show_toast("Đồ họa: %s%s" % ["Tự động – " if Graphics.auto else "", Graphics.NAMES[Graphics.tier]], true)


## Ticks the graphics level in the menu; on Auto it also names the level in use.
func _update_graphics_items() -> void:
	var pm := _menu.get_popup()
	for i in 4:
		var idx := pm.get_item_index(GRAPHICS_ITEM + i)
		pm.set_item_checked(idx, (i == 0) == Graphics.auto and (i == 0 or i - 1 == Graphics.tier))
	pm.set_item_text(pm.get_item_index(GRAPHICS_ITEM), "Tự động (%s)" % Graphics.NAMES[Graphics.tier] if Graphics.auto else "Tự động")


## Scales the whole interface (and the 3D labels stay as they are).
func set_ui_scale(value: float) -> void:
	_ui_scale = clampf(snappedf(value, 0.1), 0.8, 2.2)
	get_tree().root.content_scale_factor = _ui_scale
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("ui", "scale", _ui_scale)
	cfg.save(SETTINGS_PATH)
	show_toast("Cỡ giao diện %d%%" % roundi(_ui_scale * 100), true)


func _load_ui_scale() -> void:
	_ui_scale = UiTheme.auto_ui_scale()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_ui_scale = float(cfg.get_value("ui", "scale", _ui_scale))
	get_tree().root.content_scale_factor = _ui_scale


## Fits the layout to the current logical screen size: keeps clear of notches
## and rounded corners on phones, narrows the side panels and shortens the
## top bar when space runs out.
func _relayout() -> void:
	var vp := get_viewport_rect().size
	if OS.has_feature("mobile"):
		var win := Vector2(DisplayServer.window_get_size())
		var safe := Rect2(DisplayServer.get_display_safe_area())
		if win.x > 0 and win.y > 0 and safe.size.x > 0:
			var k := vp / win
			offset_left = safe.position.x * k.x
			offset_top = safe.position.y * k.y
			offset_right = -(win.x - safe.end.x) * k.x
			offset_bottom = -(win.y - safe.end.y) * k.y
	var w := size.x
	var panel_w := clampf(w - 192 - 16, 300, 480)
	for k in _panels:
		_panels[k].offset_right = 192 + panel_w
	# Narrow screens (most phones): smaller top bar text and shorter labels.
	_compact = w < 1000
	_top_bar.add_theme_constant_override("separation", 10 if _compact else 18)
	_cash.add_theme_font_size_override("font_size", roundi((15 if _compact else 18) * UiTheme.TEXT_SCALE))
	for l in [_tier, _rep, _clock, _raw, _finished]:
		l.add_theme_font_size_override("font_size", roundi((13 if _compact else 16) * UiTheme.TEXT_SCALE))
	for b in _speed_buttons:
		b.custom_minimum_size.x = 38 if _compact else 46
	_report.max_height = size.y - 24
	_refresh_wait = 0.0
	if _pad:
		# Short screens: the pad would cover the navigation buttons.
		_pad.visible = size.y - 230 > 72 + _nav.get_combined_minimum_size().y


func _update_speed_buttons() -> void:
	var speeds := [0, 1, 2, 4]
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(speeds[i] == TimeManager.speed)


func _build_nav() -> void:
	var nav := VBoxContainer.new()
	_nav = nav
	nav.position = Vector2(12, 72)
	nav.add_theme_constant_override("separation", 4 if UiTheme.is_mobile() else 6)
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nav)
	for p in PANELS:
		var id: String = p[0]
		var b := UiTheme.button(p[1], func(): toggle_panel(id))
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(170, 42 if UiTheme.is_mobile() else 46)
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
	_strike_alert = UiTheme.button("⚠ Đình công!", func():
		if _current != "staff":
			toggle_panel("staff"))
	_strike_alert.custom_minimum_size = Vector2(170, 46)
	_strike_alert.add_theme_color_override("font_color", Color.WHITE)
	for st in ["normal", "hover", "pressed"]:
		_strike_alert.add_theme_stylebox_override(st, UiTheme.panel_style(UiTheme.BAD.darkened(0.25 if st == "normal" else 0.1), 8, 8))
	_strike_alert.visible = false
	nav.add_child(_strike_alert)
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
	_update_help()


func _update_help() -> void:
	if _help:
		_help.visible = _current == "" and not _selection.visible


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
	if UiTheme.is_mobile():
		_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_banner_label.custom_minimum_size.x = 420
	bh.add_child(_banner_label)
	bh.add_child(UiTheme.button("Hủy" if UiTheme.is_mobile() else "Hủy (Esc)", func(): EventBus.build_mode_changed.emit(false)))
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
	l.custom_minimum_size.x = 280 if UiTheme.is_mobile() else 330
	pc.add_child(l)
	_toasts.add_child(pc)
	while _toasts.get_child_count() > (3 if UiTheme.is_mobile() else 5):
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := pc.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(pc, "modulate:a", 0.0, 0.6)
	tw.tween_callback(pc.queue_free)


func _build_corner_panels() -> void:
	var sel := SelectionPanel.new()
	_selection = sel
	sel.visibility_changed.connect(_update_help)
	sel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	sel.offset_right = -16
	sel.offset_bottom = -16
	sel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	sel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(sel)
	var report: PanelContainer = preload("res://scripts/ui/daily_report.gd").new()
	report.name = "DailyReport"
	_report = report
	report.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	report.grow_horizontal = Control.GROW_DIRECTION_BOTH
	report.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(report)


func _build_help() -> void:
	var text := "Q / E xoay · Lăn chuột phóng to · Kéo chuột hoặc WASD di chuyển · Bấm vào máy để xem và sửa · Space tạm dừng"
	var l := UiTheme.label(text, 13, Color(1, 1, 1, 0.85))
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	l.offset_left = 14
	l.offset_top = -30
	if UiTheme.is_mobile():
		# Next to the rotate buttons, wrapping onto two lines if needed.
		l.text = "Kéo để di chuyển (vuốt nhanh để lướt) · Chụm hai ngón để phóng to · Xoay hai ngón để xoay tự do · Chạm vào máy để xem"
		l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		l.offset_left = 224
		l.offset_right = -16
		l.offset_top = -62
		l.offset_bottom = -10
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	_help = l


## Phones and tablets have no keyboard: rotate buttons in the bottom-left
## corner and, above them, a pad that pans (hold), zooms and jumps home.
func _build_touch_buttons() -> void:
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	h.offset_left = 12
	h.offset_top = -62
	h.offset_bottom = -10
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for step in [-1, 1]:
		var b := UiTheme.button("< Xoay" if step < 0 else "Xoay >", func(): EventBus.camera_rotate_requested.emit(step))
		b.custom_minimum_size = Vector2(96, 52)
		h.add_child(b)
	add_child(h)
	_pad = camera_pad()
	add_child(_pad)


## 3 x 3 pad: arrows pan while held, + / − zoom, the middle returns to the factory.
static func camera_pad() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 3
	g.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	g.offset_left = 12
	g.offset_top = -72 - 3 * 50
	g.offset_bottom = -72
	g.grow_vertical = Control.GROW_DIRECTION_BEGIN
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cells := [["+", Vector2.ZERO], ["^", Vector2(0, -1)], ["−", Vector2.ZERO],
		["<", Vector2(-1, 0)], ["Về", Vector2.ZERO], [">", Vector2(1, 0)],
		["", Vector2.ZERO], ["v", Vector2(0, 1)], ["", Vector2.ZERO]]
	for c in cells:
		var text: String = c[0]
		var dir: Vector2 = c[1]
		if text == "":
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(56, 46)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			g.add_child(gap)
			continue
		var b := UiTheme.button(text, func(): pass)
		b.custom_minimum_size = Vector2(56, 46)
		b.modulate.a = 0.85
		if dir != Vector2.ZERO:
			b.button_down.connect(func(): EventBus.camera_pad_changed.emit(dir))
			b.button_up.connect(func(): EventBus.camera_pad_changed.emit(Vector2.ZERO))
		elif text == "+":
			b.pressed.connect(func(): EventBus.camera_zoom_requested.emit(0.8))
		elif text == "−":
			b.pressed.connect(func(): EventBus.camera_zoom_requested.emit(1.25))
		else:
			b.tooltip_text = "Về nhà máy chính"
			b.pressed.connect(func(): EventBus.camera_focus_requested.emit(Vector3(-2, 0, 0), 30.0))
		g.add_child(b)
	return g


## Android back button / gesture: closes whatever is open, one thing at a time.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if _report.visible:
		_report.visible = false
	elif _build_banner.visible:
		EventBus.build_mode_changed.emit(false)
	elif _current != "":
		toggle_panel(_current)
	elif _selection.visible:
		EventBus.selection_changed.emit("", 0)


func _on_order_completed(d: Dictionary) -> void:
	var msg := "%s đã thanh toán %s" % [d.customer, Fmt.money(int(d.value) - int(d.penalty))]
	if int(d.penalty) > 0:
		msg += " (phạt trễ %s)" % Fmt.money(int(d.penalty))
	show_toast(msg, int(d.penalty) == 0)
