## Details and actions for the machine or worker picked in the 3D world.
class_name SelectionPanel
extends PanelContainer

const STATUS_NAMES := {
	"running": "Đang chạy",
	"no_operator": "Thiếu công nhân",
	"no_material": "Thiếu nguyên liệu",
	"output_full": "Pallet / kho thành phẩm đầy",
	"broken": "Hỏng, cần sửa",
	"repairing": "Đang sửa",
}

var _kind := ""
var _id := 0
var _box: VBoxContainer
var _signature := ""


static func status_color(status: String) -> Color:
	match status:
		"running":
			return UiTheme.GOOD
		"broken", "no_material":
			return UiTheme.BAD
	return UiTheme.WARN


static func employee_activity(sim: Simulation, e: Dictionary) -> String:
	if e.role == EmployeeManager.OPERATOR:
		if e.machine_id == 0:
			return "Rảnh, chờ máy"
		var m := sim.state.find_by_id(sim.state.machines, int(e.machine_id))
		return "Vận hành máy ô %d" % (int(m.slot) + 1) if not m.is_empty() else "Rảnh"
	if e.job.is_empty():
		return "Rảnh"
	if e.job.kind == "repair":
		var m := sim.state.find_by_id(sim.state.machines, int(e.job.machine_id))
		return "Bảo trì máy ô %d" % (int(m.slot) + 1) if not m.is_empty() else "Rảnh"
	if e.job.kind == "unload":
		return "Đi lấy hạt nhựa ở bãi" if e.job.phase == "to_source" else "Mang %d hạt nhựa vào kho" % e.job.qty
	var unit: String = sim.content.products[e.job.product_id].unit_name if e.job.get("product_id", "") != "" else "sản phẩm"
	return "Đi lấy hàng ở máy" if e.job.phase == "to_source" else "Mang %d %s vào kho" % [e.job.qty, unit]


func _ready() -> void:
	custom_minimum_size = Vector2(380, 0)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)
	visible = false
	EventBus.selection_changed.connect(_on_selection)


func _on_selection(kind: String, id: int) -> void:
	_kind = kind
	_id = id
	_signature = ""
	visible = kind != ""


func _process(_delta: float) -> void:
	if not visible:
		return
	var sim := GameManager.sim
	var data := sim.state.find_by_id(sim.state.machines if _kind == "machine" else sim.state.employees, _id)
	if data.is_empty():
		EventBus.selection_changed.emit("", 0)
		return
	var shown := data.duplicate(true)
	shown.erase("ticks_left")
	shown.erase("repair_ticks_left")
	if shown.has("job") and shown.job is Dictionary:
		shown.job.erase("ticks_left")
	var sig := str(shown) + str(sim.state.cash / 1000)
	if sig == _signature or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	_signature = sig
	for c in _box.get_children():
		c.queue_free()
	if _kind == "machine":
		_build_machine(sim, data)
	else:
		_build_worker(sim, data)


func _row(left: String, right: String, color: Color = UiTheme.TEXT) -> void:
	var h := HBoxContainer.new()
	var l := UiTheme.label(left, 14, UiTheme.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UiTheme.label(right, 14, color))
	_box.add_child(h)


func _header(text: String) -> void:
	var h := HBoxContainer.new()
	var l := UiTheme.label(text, 17, UiTheme.TEXT, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UiTheme.button("×", func(): EventBus.selection_changed.emit("", 0)))
	_box.add_child(h)


func _build_machine(sim: Simulation, m: Dictionary) -> void:
	var d: MachineDef = sim.content.machines[m.def_id]
	var p: ProductDef = sim.content.products[d.output_product_id]
	_header("%s · ô %d" % [d.display_name, int(m.slot) + 1])
	_row("Trạng thái", STATUS_NAMES.get(m.status, m.status), status_color(m.status))
	_row("Cấp máy", "%d / %d" % [m.level, d.max_level])
	var cond := int(m.condition)
	_row("Tình trạng", "%d%%" % cond, UiTheme.GOOD if cond > 60 else (UiTheme.WARN if cond > 30 else UiTheme.BAD))
	_box.add_child(UiTheme.bar(cond, 100, UiTheme.GOOD if cond > 60 else (UiTheme.WARN if cond > 30 else UiTheme.BAD)))
	if d.operators_required > 0:
		var op := sim.state.find_by_id(sim.state.employees, int(m.operator_id))
		_row("Người vận hành", op.name if not op.is_empty() else "Chưa có", UiTheme.TEXT if not op.is_empty() else UiTheme.WARN)
	else:
		_row("Người vận hành", "Tự động")
	_row("Trên pallet", "%d / %d %s" % [m.buffer, d.output_buffer_capacity, p.unit_name])
	_row("Đã làm", "%d đạt, %d lỗi" % [m.produced, m.defects])
	_row("Chu kỳ", "%.1f giây" % (sim.production.cycle_ticks(m) * sim.config.tick_seconds))
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 6)
	actions.add_theme_constant_override("v_separation", 6)
	_box.add_child(actions)
	var up := sim.production.upgrade_cost(m)
	if up >= 0:
		actions.add_child(UiTheme.button("Nâng cấp (%s)" % Fmt.money(up), func(): GameManager.upgrade_machine(m.id), not sim.economy.can_afford(up)))
	if int(m.repairer_id) == 0 and (m.broken or cond < 100):
		var rc := sim.production.repair_cost(m)
		var b := UiTheme.button("Sửa máy (%s)" % Fmt.money(rc), func(): GameManager.repair_machine(m.id), not sim.economy.can_afford(rc))
		if m.broken:
			b.add_theme_color_override("font_color", UiTheme.BAD)
		actions.add_child(b)
	actions.add_child(UiTheme.button("Chủ xưởng kiểm tra", func(): EventBus.inspect_requested.emit(m.id)))
	actions.add_child(UiTheme.button("Bán (+%s)" % Fmt.money(d.price * d.resale_percent / 100), func(): GameManager.sell_machine(m.id)))
	if d.operators_required > 0 and m.operator_id == 0:
		_box.add_child(UiTheme.button("Tuyển người vận hành (%s)" % Fmt.money(sim.config.hire_fee), func(): GameManager.hire(EmployeeManager.OPERATOR)))


func _build_worker(sim: Simulation, e: Dictionary) -> void:
	_header(e.name)
	_row("Vai trò", EmployeeManager.ROLE_NAMES[e.role])
	_row("Đang làm", employee_activity(sim, e))
	_row("Lương", "%s / ngày" % Fmt.money(sim.config.wage_per_day))
	_box.add_child(UiTheme.button("Cho nghỉ việc", func(): GameManager.fire(e.id)))
