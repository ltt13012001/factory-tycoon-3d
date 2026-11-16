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
		return _t(_one([TranslationServer.translate("Tăng lương đi!"), TranslationServer.translate("Đình công!"), TranslationServer.translate("Không tăng lương, không làm!"), TranslationServer.translate("Lương thấp quá!"), TranslationServer.translate("Bớt tăng ca đi!")], seed), "angry", true)
	if int(e.get("away", 0)) > 0:
		return _t(_one([TranslationServer.translate("Vào ca thôi!"), TranslationServer.translate("Chào buổi sáng!"), TranslationServer.translate("Đi làm nào!")], seed), "happy")
	var job: Dictionary = e.get("job", {})
	if int(job.get("wait", 0)) > 0:
		return _t(TranslationServer.translate("Kho đầy rồi!"), "sad", true)
	var m := {}
	if e.role == EmployeeManager.OPERATOR and int(e.machine_id) != 0:
		m = sim.state.find_by_id(sim.state.machines, int(e.machine_id))
	if not m.is_empty():
		if m.broken and int(m.repairer_id) == 0:
			return _t(_one([TranslationServer.translate("Máy hỏng rồi!"), TranslationServer.translate("Gọi thợ sửa đi!")], seed), "sad", true)
		if m.status == ProductionManager.NO_MATERIAL:
			return _t(_one([TranslationServer.translate("Hết hạt nhựa rồi..."), TranslationServer.translate("Chờ nguyên liệu...")], seed), "sad")
	var long_day := sim.employees.shift_hours() >= 12
	var shift_hour := posmod(sim.state.tick - 1, sim.config.ticks_per_day) / sim.config.ticks_per_hour
	if e.get("rest", false):
		if mood < EmployeeManager.UNHAPPY_BELOW:
			return _t(_one([TranslationServer.translate("Lương thấp quá..."), TranslationServer.translate("Chán quá..."), TranslationServer.translate("Bao giờ tăng lương?")], seed), "sad")
		if long_day and shift_hour >= 8:
			return _t(_one([TranslationServer.translate("Mệt quá, nghỉ chút..."), TranslationServer.translate("Tăng ca mỏi lưng ghê")], seed), "tired")
		return _t(_one([TranslationServer.translate("Nghỉ chút đã"), TranslationServer.translate("Hôm nay vắng đơn ghê"), TranslationServer.translate("Uống ly nước đã"), TranslationServer.translate("Chờ đơn mới thôi"), TranslationServer.translate("Thư giãn tí"), TranslationServer.translate("Không có việc, nghỉ xíu")], seed), "calm")
	if mood < EmployeeManager.UNHAPPY_BELOW:
		return _t(_one([TranslationServer.translate("Lương thấp quá..."), TranslationServer.translate("Chán quá..."), TranslationServer.translate("Bao giờ tăng lương?"), TranslationServer.translate("Làm mãi không đủ sống")], seed), "sad")
	if long_day and shift_hour >= 9:
		return _t(_one([TranslationServer.translate("Tăng ca mệt quá..."), TranslationServer.translate("Sắp hết ca chưa?"), TranslationServer.translate("Được thêm tiền tăng ca")], seed), "tired")
	var lines: Array = [TranslationServer.translate("Cố lên nào!"), TranslationServer.translate("Đơn này phải kịp hạn!")]
	match e.role:
		EmployeeManager.OPERATOR:
			lines += [TranslationServer.translate("Máy chạy êm ghê"), TranslationServer.translate("Thêm một mẻ nữa!"), TranslationServer.translate("Hàng đẹp quá!")]
		EmployeeManager.WAREHOUSE:
			if job.is_empty():
				lines = [TranslationServer.translate("Có hàng thì gọi nhé!")]
			else:
				lines = [TranslationServer.translate("Hàng nặng thật!"), TranslationServer.translate("Chuyển vào kho thôi!"), TranslationServer.translate("Nhẹ tay nào!")]
		EmployeeManager.TECHNICIAN:
			lines = [TranslationServer.translate("Sửa xong ngay đây!"), TranslationServer.translate("Siết lại con ốc này...")] if not job.is_empty() else [TranslationServer.translate("Máy nào cần bảo trì?")]
		EmployeeManager.MANAGER:
			lines = [TranslationServer.translate("Mọi người cố lên!"), TranslationServer.translate("Năng suất tốt đấy!"), TranslationServer.translate("Kiểm tra máy nào...")]
	if mood >= 75:
		lines += [TranslationServer.translate("Làm việc hăng say!"), TranslationServer.translate("Lương ổn, làm hết mình!"), TranslationServer.translate("Hôm nay vui ghê!")]
	return _t(_one(lines, seed), "happy" if mood >= 60 else "calm")


static func _one(list: Array, seed: int) -> String:
	return list[posmod(seed * 7919 + seed / 3, list.size())]


static func _t(text: String, kind: String, urgent := false) -> Dictionary:
	return {"text": text, "kind": kind, "urgent": urgent}
