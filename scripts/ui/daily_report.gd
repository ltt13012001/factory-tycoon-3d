## End-of-day report: production, income statement and cash flow.
extends PanelContainer

const CATEGORY_NAMES := {
	"sales": "Bán hàng", "penalty": "Phạt giao trễ", "material": "Mua nguyên liệu",
	"machine": "Mua máy", "machine_sale": "Bán máy", "hire": "Tuyển dụng",
	"wages": "Lương", "rent": "Thuê đất", "power": "Tiền điện", "interest": "Lãi thấu chi",
	"construction": "Xây dựng", "upgrade": "Nâng cấp máy", "repair": "Sửa máy",
	"expansion": "Mở rộng", "branch_income": "Lãi xưởng, chi nhánh", "branch_cost": "Chi phí xưởng, chi nhánh",
	"executives": "Lương ban lãnh đạo",
}

## Taller reports scroll instead of running off small screens.
var max_height := 10000.0
var _box: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	custom_minimum_size = Vector2(520, 0)
	add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.08, 0.1, 0.14, 0.97), 14, 20))
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	TouchScroll.attach(_scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 6)
	_scroll.add_child(_box)
	visible = false
	EventBus.day_ended.connect(show_report)
	EventBus.report_requested.connect(show_report)


func show_report(r: Dictionary) -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var st: Dictionary = r.stats
	_box.add_child(UiTheme.label("Báo cáo cuối ngày %d" % r.day, 22, UiTheme.TEXT, true))
	_box.add_child(HSeparator.new())
	_section("Sản xuất")
	_row("Sản phẩm đạt chuẩn", "%d" % st.produced)
	_row("Sản phẩm lỗi", "%d" % st.defects)
	_row("Đơn đã giao", "%d (trễ %d)" % [st.orders_delivered, st.orders_late])
	_section("Lãi lỗ (ghi nhận khi giao hàng)")
	_row("Doanh thu", Fmt.money(st.revenue), UiTheme.GOOD)
	_row("Giá vốn nguyên liệu đã dùng", "-" + Fmt.money(st.material_cost))
	_row("Tiền điện", "-" + Fmt.money(st.power))
	_row("Lương", "-" + Fmt.money(st.wages))
	_row("Thuê đất", "-" + Fmt.money(st.rent))
	if st.penalties > 0:
		_row("Phạt giao trễ", "-" + Fmt.money(st.penalties), UiTheme.BAD)
	if int(st.get("repairs", 0)) > 0:
		_row("Sửa máy", "-" + Fmt.money(st.repairs))
	if st.interest > 0:
		_row("Lãi thấu chi", "-" + Fmt.money(st.interest), UiTheme.BAD)
	if int(st.get("branch_income", 0)) > 0:
		_row("Lãi các xưởng, chi nhánh khác", "+" + Fmt.money(st.branch_income), UiTheme.GOOD)
	if int(st.get("branch_costs", 0)) > 0:
		_row("Chi phí xưởng, chi nhánh khác", "-" + Fmt.money(st.branch_costs))
	if int(st.get("exec_wages", 0)) > 0:
		_row("Lương ban lãnh đạo", "-" + Fmt.money(st.exec_wages))
	_row("Lợi nhuận", Fmt.money(r.profit), UiTheme.GOOD if r.profit >= 0 else UiTheme.BAD, true)
	_section("Dòng tiền (tiền mặt thực thu, thực chi)")
	_row("Tiền đầu ngày", Fmt.money(r.start_cash))
	_row("Tổng thu", "+" + Fmt.money(r.income), UiTheme.GOOD)
	_row("Tổng chi", "-" + Fmt.money(r.expense), UiTheme.BAD)
	_row("Tiền cuối ngày", Fmt.money(r.end_cash), UiTheme.TEXT, true)
	_row("Uy tín", "%d / 100" % r.reputation)
	var note := UiTheme.label("Lợi nhuận khác dòng tiền: mua nguyên liệu hay máy làm giảm tiền mặt ngay, nhưng chỉ phần nguyên liệu đã dùng mới tính vào chi phí.", 12, UiTheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 400
	_box.add_child(note)
	if r.critical:
		var warn := UiTheme.label("Tiền mặt vượt hạn mức thấu chi. Bạn không mua thêm được gì cho tới khi phục hồi. Hãy bán bớt máy hoặc cho bớt người nghỉ.", 14, UiTheme.BAD)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.custom_minimum_size.x = 400
		_box.add_child(warn)
	_box.add_child(UiTheme.button("Tiếp tục", func(): visible = false))
	visible = true
	_fit.call_deferred()


func _fit() -> void:
	var content := _box.get_combined_minimum_size()
	_scroll.custom_minimum_size = Vector2(content.x, minf(content.y, max_height - 40))
	_scroll.scroll_vertical = 0
	# Re-centre on the new size (the old offsets may hold a taller report).
	var s := get_combined_minimum_size()
	offset_left = -s.x / 2
	offset_right = s.x / 2
	offset_top = -s.y / 2
	offset_bottom = s.y / 2


func _section(text: String) -> void:
	_box.add_child(UiTheme.label(text, 15, UiTheme.ACCENT, true))


func _row(left: String, right: String, color: Color = UiTheme.TEXT, bold: bool = false) -> void:
	var h := HBoxContainer.new()
	var l := UiTheme.label(left, 14, UiTheme.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UiTheme.label(right, 15 if bold else 14, color, bold))
	_box.add_child(h)
