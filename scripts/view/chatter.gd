## Small talk between staff. Now and then two people standing or sitting
## close together (resting side by side, operators at neighbouring
## machines, the manager on the rounds) turn to each other and trade a few
## lines in turn, each in their own speech bubble. A chat ends when either
## of them has to walk off or something urgent comes up. Purely visual:
## the simulation never sees it.
extends Node

## How close two people must be to start a chat (operators at neighbouring
## machines are 6.5 m apart), and to keep it going.
const NEAR := 7.0
const APART := 8.0
## Seconds each line stays up: longer lines stay a little longer.
const LINE_SECONDS := 2.2
const SECONDS_PER_CHAR := 0.045
## Chats at the same time, so bubbles never crowd the hall.
const MAX_TALKS := 3
const MAX_TALKS_LOW := 2
## Seconds between looks for a new pair, and before the same person chats again.
const SCAN_EVERY := 1.5
const REST_AFTER := 14.0

## Conversations by topic: lines alternate between the one who starts
## and the one who answers. {a} and {b} are the starter's and the other
## person's names ("Chị Lan").
const TOPICS := {
	"rest": [
		["{b} ơi, trưa nay ăn gì?", "Cơm tấm đầu ngõ đi!", "Chốt luôn!"],
		["Tối qua xem bóng đá không?", "Có chứ, đá hay ghê!", "Mai đá tiếp đó."],
		["Uống cà phê không {b}?", "Cho mình ly sữa đá nha.", "Ok, để mình mua."],
		["Con bé nhà mình mới vào lớp 1.", "Nhanh thật! Học ngoan không?", "Ngoan lắm, đọc được rồi."],
		["Hôm nay vắng đơn ghê.", "Nghỉ xíu cho khoẻ.", "Ừ, lát lại chạy máy."],
		["Cuối tuần đi Vũng Tàu không?", "Đi! Rủ thêm mấy người nữa.", "Để mình hỏi xe."],
		["Trời nóng quá {b} ha.", "Ừ, uống nước nhiều vào.", "Cảm ơn nha!"],
		["Nghe nói sắp có đơn lớn.", "Vậy là có thưởng rồi!", "Mong vậy lắm!"],
	],
	"work": [
		["Máy bên đó chạy ổn không?", "Êm ru {a} ơi!", "Tốt quá!"],
		["Đơn này kịp hạn không?", "Cố chút là kịp mà.", "Cố lên nào!"],
		["{b} ơi, cho mượn cái cờ lê.", "Đây, cầm lấy.", "Cảm ơn nha!"],
		["Mẻ này đẹp ghê!", "Khuôn mới có khác.", "Khách chắc thích lắm."],
		["Hết hạt nhựa chưa {b}?", "Còn đủ chạy tới chiều.", "Ok, để mình báo kho."],
		["Nhớ đeo găng tay nha!", "Ừ, an toàn là trên hết.", "Chuẩn luôn."],
	],
	"tired": [
		["Mỏi lưng quá {b} ơi...", "Ráng chút nữa là hết ca.", "Về ngủ một giấc thôi."],
		["Tăng ca hoài mệt ghê.", "Được thêm tiền mà.", "Ừ, ráng vậy."],
	],
	"sad": [
		["Lương tháng này đủ tiêu không?", "Chật vật lắm {a} ơi...", "Phải xin tăng lương thôi."],
		["Giá gì cũng lên...", "Lương thì đứng yên.", "Chán thật..."],
	],
	"boss": [
		["Năng suất tốt đấy {b}!", "Dạ, cảm ơn anh!", "Cứ giữ vậy nhé."],
		["Nhớ giữ an toàn nhé!", "Dạ, em nhớ rồi.", "Tốt lắm."],
		["Máy này hôm nay sao rồi?", "Dạ chạy ổn ạ.", "Có gì báo anh ngay."],
		["Có mệt không {b}?", "Dạ cũng ổn ạ!", "Ráng nhé, cuối tháng có thưởng."],
	],
}

## Employee id -> WorkerView, shared with FactoryView.
var workers: Dictionary
## Chats started so far (the smoke test prints it).
var started := 0

var _talks: Array[Dictionary] = []
var _resting := {}  # worker -> seconds before they chat again
var _scan := SCAN_EVERY
var _rng := RandomNumberGenerator.new()


func _process(delta: float) -> void:
	for t in _talks.duplicate():
		_advance(t, delta)
	for w in _resting.keys():
		_resting[w] -= delta
		if _resting[w] <= 0.0 or not is_instance_valid(w):
			_resting.erase(w)
	_scan -= delta
	if _scan > 0.0:
		return
	_scan = SCAN_EVERY
	if _talks.size() < (MAX_TALKS_LOW if Graphics.tier == Graphics.LOW else MAX_TALKS):
		_start_one()


func _advance(t: Dictionary, delta: float) -> void:
	var a: Node3D = t.a
	var b: Node3D = t.b
	if not is_instance_valid(a) or not is_instance_valid(b) or not a.can_keep_chatting() \
			or not b.can_keep_chatting() or a.position.distance_to(b.position) > APART:
		_end(t)
		return
	t.left -= delta
	if t.left > 0.0:
		return
	t.line += 1
	if t.line >= t.lines.size():
		_end(t)
		return
	_say(t)


func _say(t: Dictionary) -> void:
	var a: Node3D = t.a
	var b: Node3D = t.b
	var speaker: Node3D = a if t.line % 2 == 0 else b
	var text: String = t.lines[t.line]
	text = text.replace("{a}", a.display_name()).replace("{b}", b.display_name())
	var seconds := LINE_SECONDS + text.length() * SECONDS_PER_CHAR
	speaker.say(text, seconds - 0.25)  # a short pause before the answer
	t.left = seconds


func _end(t: Dictionary) -> void:
	_talks.erase(t)
	for w in [t.a, t.b]:
		if is_instance_valid(w):
			if w.chat_partner != null:
				w.end_chat()
			_resting[w] = REST_AFTER + _rng.randf() * 8.0


## Looks for two free people close to each other and starts them talking.
func _start_one() -> void:
	var free: Array[Node3D] = []
	for w in workers.values():
		if is_instance_valid(w) and not _resting.has(w) and w.can_chat():
			free.append(w)
	if free.size() < 2:
		return
	# Start from a different person each time so everyone gets a turn.
	# The nearest free neighbour of each, in a different order each time so
	# everyone gets a turn.
	var first := _rng.randi() % free.size()
	for n in free.size():
		var a: Node3D = free[(first + n) % free.size()]
		var best: Node3D = null
		for b in free:
			if b != a and a.position.distance_to(b.position) <= NEAR \
					and (best == null or a.position.distance_to(b.position) < a.position.distance_to(best.position)):
				best = b
		if best != null:
			start(a, best)
			return


## Starts a chat between two people now; the manager always speaks first.
func start(a: Node3D, b: Node3D) -> void:
	if b.chat_mood() == "boss":
		var swap := a
		a = b
		b = swap
	var topic: String = a.chat_mood()
	if topic != "boss":
		# Grumbles and tiredness are catching; otherwise talk about where they are.
		for m in ["sad", "tired"]:
			if b.chat_mood() == m:
				topic = m
	var options: Array = TOPICS[topic]
	var t := {"a": a, "b": b, "lines": options[_rng.randi() % options.size()], "line": 0, "left": 0.0}
	a.chat_partner = b
	b.chat_partner = a
	_talks.append(t)
	started += 1
	_say(t)
