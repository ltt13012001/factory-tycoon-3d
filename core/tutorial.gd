## The first five guided steps. Each step completes on a simulation event.
class_name Tutorial
extends RefCounted

const STEPS := [
	{"text": "Bước 1/5: Mở bảng Đơn hàng và nhận đơn hàng đầu tiên.", "event": &"order_accepted"},
	{"text": "Bước 2/5: Mở bảng Mua hàng và đặt một lô hạt nhựa. Máy chỉ chạy khi còn nguyên liệu.", "event": &"material_ordered"},
	{"text": "Bước 3/5: Khi kho đủ hộp cho đơn, bấm Giao hàng trong bảng Đơn hàng.", "event": &"order_shipping"},
	{"text": "Bước 4/5: Tiền về khi xe tải rời bãi. Cuối ngày (24:00) bạn sẽ thấy báo cáo lãi lỗ.", "event": &"day_ended"},
	{"text": "Bước 5/5: Dành dụm tiền, mở bảng Xây dựng và mua máy ép thứ hai, rồi thuê thêm người vận hành.", "event": &"machine_added"},
]

var sim: Simulation


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func current_text() -> String:
	var step := sim.state.tutorial_step
	if step >= STEPS.size():
		return ""
	return STEPS[step].text


func on_event(name: StringName) -> void:
	var step := sim.state.tutorial_step
	if step < STEPS.size() and STEPS[step].event == name:
		sim.state.tutorial_step += 1
		sim.emit_event(&"tutorial_advanced", {"step": sim.state.tutorial_step})
