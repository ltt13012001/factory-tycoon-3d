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
	"off_shift": "Hết ca, chờ sáng mai",
	"strike": "Đình công",
	"operator_away": "Công nhân đang quay lại",
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


static func mood_text(mood: int) -> String:
	if mood >= 75:
		return TranslationServer.translate("Rất vui")
	if mood >= 55:
		return TranslationServer.translate("Vui vẻ")
	if mood >= EmployeeManager.UNHAPPY_BELOW:
		return TranslationServer.translate("Bình thường")
	if mood >= EmployeeManager.STRIKE_BELOW:
		return TranslationServer.translate("Bất mãn")
	return TranslationServer.translate("Rất bất mãn")


static func mood_color(mood: int) -> Color:
	if mood >= 55:
		return UiTheme.GOOD
	if mood >= EmployeeManager.UNHAPPY_BELOW:
		return UiTheme.WARN
	return UiTheme.BAD


static func employee_activity(sim: Simulation, e: Dictionary) -> String:
	if e.get("off", false):
		return TranslationServer.translate("Đã về nhà, mai đi làm")
	if sim.employees.on_strike() and e.role != EmployeeManager.MANAGER:
		return TranslationServer.translate("Đang đình công")
	if e.get("rest", false):
		return TranslationServer.translate("Nghỉ ngơi ở khu nghỉ")
	if int(e.get("away", 0)) > 0:
		return TranslationServer.translate("Đang đi vào xưởng")
	if e.role == EmployeeManager.MANAGER:
		return TranslationServer.translate("Điều hành xưởng (máy nhanh hơn %d%%)") % ExpansionManager.MANAGER_SPEED_PERCENT
	if e.role == EmployeeManager.OPERATOR:
		if e.machine_id == 0:
			return TranslationServer.translate("Rảnh, chờ máy")
		var m := sim.state.find_by_id(sim.state.machines, int(e.machine_id))
		return TranslationServer.translate("Vận hành máy ô %d") % (int(m.slot) + 1) if not m.is_empty() else TranslationServer.translate("Rảnh")
	if e.job.is_empty():
		return TranslationServer.translate("Rảnh")
	if e.job.kind == "repair":
		var m := sim.state.find_by_id(sim.state.machines, int(e.job.machine_id))
		return TranslationServer.translate("Bảo trì máy ô %d") % (int(m.slot) + 1) if not m.is_empty() else TranslationServer.translate("Rảnh")
	if e.job.kind == "unload":
		return TranslationServer.translate("Đi lấy hạt nhựa ở bãi") if e.job.phase == "to_source" else TranslationServer.translate("Mang %d hạt nhựa vào kho") % e.job.qty
	var unit: String = sim.content.products[e.job.product_id].unit_name if e.job.get("product_id", "") != "" else TranslationServer.translate("sản phẩm")
	return TranslationServer.translate("Đi lấy hàng ở máy") if e.job.phase == "to_source" else TranslationServer.translate("Mang %d %s vào kho") % [e.job.qty, unit]


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
	shown.erase("idle")
	if shown.has("away"):
		shown.away = int(shown.away) > 0
		shown.thought = Thoughts.of(sim, data)
	if shown.has("job") and shown.job is Dictionary:
		shown.job.erase("ticks_left")
		shown.job.erase("wait")
	var sig := str(shown) + str(sim.state.cash / 1000) + str(sim.diamonds.balance())
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
	var close := UiTheme.button("×", func(): EventBus.selection_changed.emit("", 0))
	close.custom_minimum_size = Vector2(44, 40)
	h.add_child(close)
	_box.add_child(h)


func _build_machine(sim: Simulation, m: Dictionary) -> void:
	var d: MachineDef = sim.content.machines[m.def_id]
	var p: ProductDef = sim.content.products[d.output_product_id]
	var site := ProductionManager.site_of(m)
	_header(tr("%s · ô %d") % [d.display_name, int(m.slot) + 1])
	if sim.expansion.factory_ids().size() > 0:
		_row(tr("Nhà xưởng"), sim.expansion.factory_name(site))
	_row(tr("Trạng thái"), tr(STATUS_NAMES.get(m.status, m.status)), status_color(m.status))
	_row(tr("Cấp máy"), "%d / %d" % [m.level, d.max_level])
	var cond := int(m.condition)
	_row(tr("Tình trạng"), "%d%%" % cond, UiTheme.GOOD if cond > 60 else (UiTheme.WARN if cond > 30 else UiTheme.BAD))
	_box.add_child(UiTheme.bar(cond, 100, UiTheme.GOOD if cond > 60 else (UiTheme.WARN if cond > 30 else UiTheme.BAD)))
	if d.operators_required > 0:
		var op := sim.state.find_by_id(sim.state.employees, int(m.operator_id))
		_row(tr("Người vận hành"), op.name if not op.is_empty() else tr("Chưa có"), UiTheme.TEXT if not op.is_empty() else UiTheme.WARN)
	else:
		_row(tr("Người vận hành"), tr("Tự động"))
	_row(tr("Trên pallet"), "%d / %d %s" % [m.buffer, d.output_buffer_capacity, p.unit_name])
	_row(tr("Đã làm"), tr("%d đạt, %d lỗi") % [m.produced, m.defects])
	_row(tr("Chu kỳ"), tr("%.1f giây") % sim.production.cycle_seconds(m))
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 6)
	actions.add_theme_constant_override("v_separation", 6)
	_box.add_child(actions)
	var up := sim.production.upgrade_cost(m)
	if up >= 0:
		actions.add_child(UiTheme.button(tr("Nâng cấp (%s)") % Fmt.money(up), func(): GameManager.upgrade_machine(m.id), not sim.economy.can_afford(up)))
	if int(m.repairer_id) == 0 and (m.broken or cond < 100):
		var rc := sim.production.repair_cost(m)
		var b := UiTheme.button(tr("Sửa máy (%s)") % Fmt.money(rc), func(): GameManager.repair_machine(m.id), not sim.economy.can_afford(rc))
		if m.broken:
			b.add_theme_color_override("font_color", UiTheme.BAD)
		actions.add_child(b)
	if m.broken or (int(m.repairer_id) == 0 and cond < 60) or int(m.repairer_id) != 0:
		actions.add_child(UiTheme.diamond_button(tr("Sửa ngay · %d") % DiamondManager.REPAIR_COST, func(): GameManager.instant_repair(m.id), not sim.diamonds.can_spend(DiamondManager.REPAIR_COST)))
	actions.add_child(UiTheme.button(tr("Chủ xưởng kiểm tra"), func(): EventBus.inspect_requested.emit(m.id)))
	actions.add_child(UiTheme.button(tr("Bán (+%s)") % Fmt.money(d.price * d.resale_percent / 100), func(): GameManager.sell_machine(m.id)))
	if d.operators_required > 0 and m.operator_id == 0:
		_box.add_child(UiTheme.button(tr("Tuyển người vận hành (%s)") % Fmt.money(sim.config.hire_fee), func(): GameManager.hire_at(EmployeeManager.OPERATOR, site)))


func _build_worker(sim: Simulation, e: Dictionary) -> void:
	_header(e.name)
	_row(tr("Vai trò"), tr(EmployeeManager.ROLE_NAMES[e.role]))
	if sim.expansion.factory_ids().size() > 0:
		_row(tr("Nhà xưởng"), sim.expansion.factory_name(ProductionManager.site_of(e)))
	_row(tr("Đang làm"), employee_activity(sim, e))
	var mood := int(e.get("mood", 70))
	_row(tr("Tâm trạng"), "%s (%d)" % [mood_text(mood), mood], mood_color(mood))
	_box.add_child(UiTheme.bar(mood, 100, mood_color(mood)))
	var thought := Thoughts.of(sim, e)
	if thought != "":
		_row(tr("Đang nghĩ"), "“%s”" % thought, UiTheme.ACCENT.lightened(0.3))
	_row(tr("Lương"), tr("%s / ngày") % Fmt.money(sim.employees.wage_of(e)))
	_box.add_child(UiTheme.button(tr("Cho nghỉ việc"), func(): GameManager.fire(e.id)))
