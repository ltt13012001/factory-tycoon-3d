## Details of the machine or worker picked in the 3D world.
class_name SelectionPanel
extends PanelContainer

const STATUS_NAMES := {
	"running": "Đang chạy",
	"no_operator": "Thiếu công nhân",
	"no_material": "Thiếu nguyên liệu",
	"output_full": "Pallet / kho thành phẩm đầy",
}

var _kind := ""
var _id := 0
var _box: VBoxContainer
var _signature := ""


static func employee_activity(sim: Simulation, e: Dictionary) -> String:
	if e.role == EmployeeManager.OPERATOR:
		if e.machine_id == 0:
			return "Rảnh, chờ máy"
		var m := sim.state.find_by_id(sim.state.machines, int(e.machine_id))
		return "Vận hành máy ô %d" % (int(m.slot) + 1) if not m.is_empty() else "Rảnh"
	if e.job.is_empty():
		return "Rảnh"
	if e.job.kind == "unload":
		return "Đi lấy hạt nhựa ở bãi" if e.job.phase == "to_source" else "Mang %d hạt nhựa vào kho" % e.job.qty
	return "Đi lấy hộp ở máy" if e.job.phase == "to_source" else "Mang %d hộp vào kho" % e.job.qty


func _ready() -> void:
	custom_minimum_size = Vector2(320, 0)
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
	var sig := str(data) + str(sim.state.cash > 0)
	if _kind == "machine" and data.in_cycle:
		sig = sig.replace("\"ticks_left\": %d" % data.ticks_left, "")
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
	_header("%s · ô %d" % [d.display_name, int(m.slot) + 1])
	_row("Trạng thái", STATUS_NAMES.get(m.status, m.status), UiTheme.GOOD if m.status == "running" else UiTheme.WARN)
	var op := sim.state.find_by_id(sim.state.employees, int(m.operator_id))
	_row("Người vận hành", op.name if not op.is_empty() else "Chưa có")
	_row("Hộp trên pallet", "%d / %d" % [m.buffer, d.output_buffer_capacity])
	_row("Đã sản xuất", "%d đạt, %d lỗi" % [m.produced, m.defects])
	_row("Chu kỳ", "%.0f giây, lỗi %d%%" % [d.cycle_ticks * sim.config.tick_seconds, d.defect_percent])
	var refund := d.price * d.resale_percent / 100
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(UiTheme.button("Chủ xưởng kiểm tra", func(): EventBus.inspect_requested.emit(m.id)))
	h.add_child(UiTheme.button("Bán máy (+%s)" % Fmt.money(refund), func(): GameManager.sell_machine(m.id)))
	_box.add_child(h)
	if m.operator_id == 0:
		_box.add_child(UiTheme.button("Tuyển người vận hành (%s)" % Fmt.money(sim.config.hire_fee), func(): GameManager.hire(EmployeeManager.OPERATOR)))


func _build_worker(sim: Simulation, e: Dictionary) -> void:
	_header(e.name)
	_row("Vai trò", EmployeeManager.ROLE_NAMES[e.role])
	_row("Đang làm", employee_activity(sim, e))
	_row("Lương", "%s / ngày" % Fmt.money(sim.config.wage_per_day))
	_box.add_child(UiTheme.button("Cho nghỉ việc", func(): GameManager.fire(e.id)))
