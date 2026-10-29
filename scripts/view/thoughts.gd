## What a worker is thinking right now, shown in a speech bubble over their
## head and in the selection panel. Depends only on the game state, and
## changes every half game hour so the bubbles do not flicker.
class_name Thoughts
extends RefCounted

## kind: happy, calm, tired, sad or angry (bubble colour and face).
## urgent: shown all the time instead of now and then.


static func of(sim: Simulation, e: Dictionary) -> String:
	return pick(sim, e).text


static func pick(sim: Simulation, e: Dictionary) -> Dictionary:
	if e.get("off", false):
		return _t("", "calm")
	var mood := int(e.get("mood", 70))
	var seed := int(e.id) * 31 + sim.state.tick / 30
	if sim.employees.on_strike() and e.role != EmployeeManager.MANAGER:
		return _t(_one(["Tăng lương đi!", "Đình công!", "Không tăng lương, không làm!", "Lương thấp quá!", "Bớt tăng ca đi!"], seed), "angry", true)
	if int(e.get("away", 0)) > 0:
		return _t(_one(["Vào ca thôi!", "Chào buổi sáng!", "Đi làm nào!"], seed), "happy")
	var job: Dictionary = e.get("job", {})
	if int(job.get("wait", 0)) > 0:
		return _t("Kho đầy rồi!", "sad", true)
	var m := {}
	if e.role == EmployeeManager.OPERATOR and int(e.machine_id) != 0:
		m = sim.state.find_by_id(sim.state.machines, int(e.machine_id))
	if not m.is_empty():
		if m.broken and int(m.repairer_id) == 0:
			return _t(_one(["Máy hỏng rồi!", "Gọi thợ sửa đi!"], seed), "sad", true)
		if m.status == ProductionManager.NO_MATERIAL:
			return _t(_one(["Hết hạt nhựa rồi...", "Chờ nguyên liệu..."], seed), "sad")
	var long_day := sim.employees.shift_hours() >= 12
	var shift_hour := posmod(sim.state.tick - 1, sim.config.ticks_per_day) / sim.config.ticks_per_hour
	if e.get("rest", false):
		if mood < EmployeeManager.UNHAPPY_BELOW:
			return _t(_one(["Lương thấp quá...", "Chán quá...", "Bao giờ tăng lương?"], seed), "sad")
		if long_day and shift_hour >= 8:
			return _t(_one(["Mệt quá, nghỉ chút...", "Tăng ca mỏi lưng ghê"], seed), "tired")
		return _t(_one(["Nghỉ chút đã", "Hôm nay vắng đơn ghê", "Uống ly nước đã", "Chờ đơn mới thôi", "Thư giãn tí", "Không có việc, nghỉ xíu"], seed), "calm")
	if mood < EmployeeManager.UNHAPPY_BELOW:
		return _t(_one(["Lương thấp quá...", "Chán quá...", "Bao giờ tăng lương?", "Làm mãi không đủ sống"], seed), "sad")
	if long_day and shift_hour >= 9:
		return _t(_one(["Tăng ca mệt quá...", "Sắp hết ca chưa?", "Được thêm tiền tăng ca"], seed), "tired")
	var lines: Array = ["Cố lên nào!", "Đơn này phải kịp hạn!"]
	match e.role:
		EmployeeManager.OPERATOR:
			lines += ["Máy chạy êm ghê", "Thêm một mẻ nữa!", "Hàng đẹp quá!"]
		EmployeeManager.WAREHOUSE:
			if job.is_empty():
				lines = ["Có hàng thì gọi nhé!"]
			else:
				lines = ["Hàng nặng thật!", "Chuyển vào kho thôi!", "Nhẹ tay nào!"]
		EmployeeManager.TECHNICIAN:
			lines = ["Sửa xong ngay đây!", "Siết lại con ốc này..."] if not job.is_empty() else ["Máy nào cần bảo trì?"]
		EmployeeManager.MANAGER:
			lines = ["Mọi người cố lên!", "Năng suất tốt đấy!", "Kiểm tra máy nào..."]
	if mood >= 75:
		lines += ["Làm việc hăng say!", "Lương ổn, làm hết mình!", "Hôm nay vui ghê!"]
	return _t(_one(lines, seed), "happy" if mood >= 60 else "calm")


static func _one(list: Array, seed: int) -> String:
	return list[posmod(seed * 7919 + seed / 3, list.size())]


static func _t(text: String, kind: String, urgent := false) -> Dictionary:
	return {"text": text, "kind": kind, "urgent": urgent}
