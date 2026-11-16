## Visiting a branch in another province or abroad: the camera travels to a
## separate place far from the first factory, where the branch stands in
## scenery modelled on its real location (BranchThemes). The first factory
## and its surroundings are hidden meanwhile (the game keeps running), and
## only one branch is built at a time, freed when the player leaves.
## A bar at the top names the branch, steps to the previous / next one and
## goes back to the factory.
class_name BranchView
extends Node3D

## Far enough that nothing of the first factory is in view or in the way of
## clicks.
const ORIGIN := Vector3(2000, 0, 0)
const BOUNDS := Rect2(-80, -80, 160, 130)
const BranchThemes := preload("res://scripts/view/branch_themes.gd")

## Nodes of the main world hidden during a visit.
var main_world: Array[Node3D] = []
var scenery: Node3D
var current := ""

var _world: BranchWorld
var _compound: BranchCompound
var _sig := ""
var _timer := 0.0
var _bar: PanelContainer
var _title: Label
var _sub: Label
var _return_to := Vector3.ZERO


func _ready() -> void:
	EventBus.branch_visit_requested.connect(visit)
	EventBus.camera_focus_requested.connect(func(target: Vector3, _z: float):
		# Anything that sends the camera to the first factory ends the visit.
		if current != "" and target.x < ORIGIN.x - 500.0:
			leave(false))
	EventBus.build_mode_changed.connect(func(active: bool):
		if active and current != "":
			leave(false))
	EventBus.game_loaded.connect(func(_d): if current != "": leave())
	_build_bar()


## All branch locations in the order of the expansion panel.
static func branch_ids(sim: Simulation) -> Array:
	var ids := []
	for region in [ExpansionManager.DOMESTIC, ExpansionManager.ABROAD]:
		for l in sim.content.location_list(region):
			ids.append(l.id)
	return ids


func visit(id: String) -> void:
	var sim := GameManager.sim
	if sim == null or not sim.content.locations.has(id):
		return
	if current == "":
		var rig := _rig()
		_return_to = rig.position if rig else Vector3.ZERO
	_free_world()
	current = id
	for n in main_world:
		n.visible = false
	_world = BranchThemes.new()
	_world.location_id = id
	_world.sim = sim
	_world.lamp_material = scenery.lamp_material
	_world.window_material = scenery.window_material
	_world.position = ORIGIN
	add_child(_world)
	_world.build()
	_compound = BranchCompound.new()
	_compound.lamp_material = scenery.lamp_material
	_compound.window_material = scenery.window_material
	_compound.position = ORIGIN
	add_child(_compound)
	_sig = ""
	_refresh(sim)
	var rig := _rig()
	if rig:
		rig.set_area(Rect2(BOUNDS.position + Vector2(ORIGIN.x, ORIGIN.z), BOUNDS.size), ORIGIN + Vector3(-12, 0, -12), 72.0)
	_bar.visible = true
	_update_bar(sim)


func leave(return_camera := true) -> void:
	if current == "":
		return
	current = ""
	_free_world()
	for n in main_world:
		n.visible = true
	_bar.visible = false
	var rig := _rig()
	if rig:
		rig.set_area(CameraRig.BOUNDS, _return_to if return_camera else Vector3.INF, 0.0)


func _free_world() -> void:
	if _world:
		_world.queue_free()
	if _compound:
		_compound.queue_free()
	_world = null
	_compound = null


func _rig() -> CameraRig:
	var cam := get_viewport().get_camera_3d()
	return cam.get_parent().get_parent() as CameraRig if cam else null


func _process(delta: float) -> void:
	if current == "" or GameManager.sim == null:
		return
	_timer += delta
	if _timer < 0.5:
		return
	_timer = 0.0
	_refresh(GameManager.sim)
	_update_bar(GameManager.sim)


## Rebuilds the compound when what it shows changed (status, lines, workers,
## head, automation, building progress in steps of 10%).
func _refresh(sim: Simulation) -> void:
	var l: LocationDef = sim.content.locations[current]
	var s := sim.expansion.site(current)
	var progress := 0
	if not s.is_empty() and int(s.total_ticks) > 0:
		progress = (100 - int(s.ticks_left) * 100 / int(s.total_ticks)) / 10
	var sig := "none" if s.is_empty() else "%s|%d|%d|%d|%s|%d" % [s.status, s.lines, s.automation, int(s.get("workers", 0)), s.head, progress]
	if sig != _sig:
		_sig = sig
		_compound.build(sim, l, s)
	else:
		_compound.update_label(sim, l, s)


# --- Bar at the top -------------------------------------------------------------

func _build_bar() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var root := Control.new()
	root.theme = UiTheme.build()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_bar = PanelContainer.new()
	_bar.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.09, 0.12, 0.17, 0.92), 12, 10))
	_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.offset_top = 84
	_bar.visible = false
	root.add_child(_bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_bar.add_child(h)
	h.add_child(UiTheme.button("◀", func(): _step(-1)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.custom_minimum_size.x = 260
	_title = UiTheme.label("", 18, UiTheme.TEXT, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub = UiTheme.label("", 13, UiTheme.MUTED)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	v.add_child(_sub)
	h.add_child(v)
	h.add_child(UiTheme.button("▶", func(): _step(1)))
	var back := UiTheme.button("Về nhà máy", func(): leave())
	back.add_theme_color_override("font_color", UiTheme.GOOD)
	h.add_child(back)


func _update_bar(sim: Simulation) -> void:
	var l: LocationDef = sim.content.locations[current]
	_title.text = l.display_name
	var s := sim.expansion.site(current)
	var where := l.country if l.region == ExpansionManager.ABROAD else "Việt Nam"
	if s.is_empty():
		_sub.text = "%s · chưa mở chi nhánh" % where
	elif s.status == ExpansionManager.READY:
		_sub.text = "%s · %d dây chuyền · %d công nhân · %s" % [where, int(s.lines), sim.expansion.workers(s), "đang sản xuất" if s.head != "" else "chưa có giám đốc"]
	else:
		_sub.text = "%s · %s" % [where, {"surveying": "đang khảo sát", "surveyed": "đã khảo sát", "land": "đã có đất", "building": "đang xây dựng"}.get(s.status, "")]


func _step(dir: int) -> void:
	var ids := branch_ids(GameManager.sim)
	var i := ids.find(current)
	visit(ids[(i + dir + ids.size()) % ids.size()])


func _unhandled_input(event: InputEvent) -> void:
	if current != "" and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		leave()
		get_viewport().set_input_as_handled()
