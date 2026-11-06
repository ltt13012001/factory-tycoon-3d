## Stand-in ads for development builds (editor, debug exports, tests):
## a five-second full-screen card instead of a real video, so every ad
## placement can be tried without an ad network. Never used in a release
## build unless started with `-- --demo-monetization`.
class_name DemoAds
extends AdsBackend

const SECONDS := 5.0
## Tests set this to skip the card and reward at once.
var instant := false
var _layer: CanvasLayer


func _init() -> void:
	label = "quảng cáo thử"


func available() -> bool:
	return true


func is_ready() -> bool:
	return _layer == null


func show_rewarded(done: Callable) -> void:
	if instant:
		done.call(true)
		return
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.07, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	bg.add_child(v)
	v.add_child(_centered(UiTheme.label("QUẢNG CÁO THỬ NGHIỆM", 28, UiTheme.WARN, true)))
	v.add_child(_centered(UiTheme.label("Bản phát hành sẽ hiện video quảng cáo thật ở đây.", 16, UiTheme.MUTED)))
	var count := _centered(UiTheme.label("", 20))
	v.add_child(count)
	var skip := UiTheme.button("Đóng (không nhận thưởng)", func(): _close(done, false))
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(skip)
	var left := [SECONDS]
	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.autostart = true
	_layer.add_child(timer)
	count.text = "Còn %d giây" % ceili(left[0])
	timer.timeout.connect(func():
		left[0] -= timer.wait_time
		count.text = "Còn %d giây" % ceili(maxf(left[0], 0.0))
		if left[0] <= 0.0:
			_close(done, true))


func _close(done: Callable, rewarded: bool) -> void:
	if _layer == null:
		return
	_layer.queue_free()
	_layer = null
	done.call(rewarded)


static func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
